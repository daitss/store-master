
helpers do
  include Rack::Utils     # to get escape_html for HAML

  # Determine our virtual server name as a minimal URL based on the request environment.
  #
  # @return [String] 
  #
  # Safety note: HTTP_HOST, according to the rack docs, is preferred
  # over SERVER_NAME if available. SERVER_NAME is always defined, but
  # can sometime come with port attached.

  def service_name
    'http://' + (@env['HTTP_HOST'] || @env['SERVER_NAME']).gsub(/:\d+$/, '') + (@env['SERVER_PORT'] == '80' ? '' : ":#{@env['SERVER_PORT']}")
  end

  # Determine whether a string is a valid IEID
  #
  # @param [String] name, a candidate name
  # @return [Boolean]

  def good_ieid name
    StoreUtils.valid_ieid_name? name
  end

  # Return the MD5 from the request headers, if present
  #
  # @return [String]

  def request_md5
    StoreUtils.base64_to_md5hex(@env["HTTP_CONTENT_MD5"])
  end

  # Given a path return as a valid URL
  #
  # @param [String] path, a partial path to file
  # @return [String] the URL to this file as a resource

  def web_location path
    service_name + (path =~ %r{^/} ?  path : '/' + path)
  end


  # provide a full URL for the current resource
  #
  # @return [String]

  def this_resource
    web_location @env['SCRIPT_NAME'].gsub(%r{/+$}, '') + '/' + @env['PATH_INFO'].gsub(%r{^/+}, '')
  end

  
  # Raise specific Http400Errors if a particular package name has been, or is, in use.
  #
  # @param [String] name, a package name (IEID)

  def raise_exception_if_in_use name
    raise Http403, "The resource #{this_resource} already exists; it can't be reused, even if deleted" if Package.exists?(name)
    raise Http400, "Can't use resource #{this_resource}; it has been previously created and deleted"   if Package.was_deleted?(name)
  end

  # Raise specific Http400Errors if a particular package name has never been created
  # or has been created and deleted.
  #
  # @param [String] name, a package name (IEID)


  def raise_exception_if_missing name
    raise Http410, "Resource #{this_resource} has been previously created and deleted"     if Package.was_deleted?(name)
    raise Http404, "The resource #{this_resource} doesn't exist"                       unless Package.exists?(name)
  end

  # Given a number, return some grammar. Red fish, blue fish.
  #
  # @param [Number] num, an integer

  def poolses num
    case num.to_i
    when 0    ; "no pools"
    when 1    ; "one pool"
    when 2    ; "two pools"
    when 3    ; "three pools"
    else      ; "#{num} pools"
    end
  end

  # inspection_url will give us the prefered  URL to package's inspection page on a silo pool
  #
  # @param [Package] package, the package of interest
  # @return [String] he URL of the preferred copy of package, with '/' appended

  def inspection_url package
    return nil unless package
    return nil if package.locations.empty?
    return package.locations[0].to_s + '/'
  end


  # pool_parameters_to_change 
  #
  # When handling the /pools form, we want to check the user-submitted
  # form data and return a hash of only those attributes that have been
  # changed; values are cast to the correct types.  Given the Pool and
  # the hash from a form submission, return a hash of the changed parameters.
  #
  # @param [Pool] pool, a Pool object
  # @param [Hash] params, the /pools param object
  # @return [Hash] A copy of params with the unchanged data removed

  def pool_parameters_to_change pool, params

    changes = {}

    # handle username/passwords

    # An empty string in the form is considered nil, but both username and password should be blank if we really want to do without any credentials

    params['basic_auth_username'] = nil if params['basic_auth_username'] == ''
    params['basic_auth_password'] = nil if params['basic_auth_password'] ==  ''

    if (params['basic_auth_username'] != pool.basic_auth_username) or (params['basic_auth_password'] != pool.basic_auth_password)
      changes['basic_auth_username'] = params['basic_auth_username']
      changes['basic_auth_password'] = params['basic_auth_password']
    end

    if changes['basic_auth_password'].class != changes['basic_auth_username'].class
      raise BadPoolParameter, "When changing credentials you must either enter text for both the username and password, or set both blank"
    end

    # the element 'required' will be the string 'true' or 'false'

    params['required']  = (params['required'].downcase == 'true')
    changes['required'] = params['required'] if params['required'] != pool.required

    # set read preference to a number; garbage input results in a zero, which is fine

    params['read_preference']  = params['read_preference'].to_i
    changes['read_preference'] = params['read_preference'] if params['read_preference'] != pool.read_preference

    # services location: we'll let URI parse check it for us

    URI.parse(params['services_location']) rescue raise(BadPoolParameter, "#{params['services_location']} is not a valid URL")
    changes['services_location'] = params['services_location'] if params['services_location'] != pool.services_location

    changes
  end

  # We want to log changes made in POSTs but we don't want to display password information; this
  # obscures the value for keys named 'passw'.  
  #
  # @param[Hash] params, a hash of parameters 
  # @return[String] a representation of the key/values in the hash

  def display_params_safely params

    list = []
    params.keys.sort.each do |k|
      val = params[k]
      case val.class
      when String;         val = "'" + val + "'"
      when NilClass;       val = 'null'
      else;                val = val.inspect
      end

      if k =~ /passw/i and not params[k].nil? and not params[k].length == 0
        val = '******'
      end
      list.push "#{k} = #{val}"
    end

    list * ';  '
  end

  # log_start_of_request logs a client's request before servicing the request.
  #
  # Rack::CommonLogger works well enough, I guess, but we really need to
  # log on the beggining of long-running requests to get the sense of
  # what's happening on our system, which means we provide logging on
  # the start of a request; this could be done in a before do ... end
  # block, or in selected routes.

  def log_start_of_request
    Datyl::Logger.info 'Request Received: ' + (request.content_length ? "#{request.content_length}" :  '-'), env
  end

  # needs_authentication? returns true when the resource is password-protected and the
  # client request has authenticated correctly.
  #
  # Currently it's all or nothing, but here's where you'd change that with a stop list
  #
  # @return [Boolean] true if the resource doesn't need authentication, or, when it does, the client has properly authenticated

  def needs_authentication?

    admin_credentials = StorageMasterModel::Authentication.lookup('admin')

    return false if admin_credentials.nil?                    # we don't require authentication

    auth =  Rack::Auth::Basic::Request.new(request.env)

    if auth.provided? && auth.basic? && auth.credentials 
      user, password = auth.credentials
      return (user != 'admin' or not admin_credentials.authenticate(password))
    else
      return true
    end
  end

  # silo_host is used to construct an example URL in the guide.haml document
  #
  # @return [String] a URL for an example silo pool
  
  def silo_host
    @service_name.sub(%r{(http|https)://[^\.]*},'silo-pool')
  end

end # of helpers do
