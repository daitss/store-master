
helpers do
  include Rack::Utils     # to get escape_html

  # service_name
  #
  # Return our virtual server name as a minimal URL.
  #
  # Safety note: HTTP_HOST, according to the rack docs, is preferred
  # over SERVER_NAME if available. SERVER_NAME is always defined, but
  # can sometime come with port attached.

  def service_name
    'http://' + (@env['HTTP_HOST'] || @env['SERVER_NAME']).gsub(/:\d+$/, '') + (@env['SERVER_PORT'] == '80' ? '' : ":#{@env['SERVER_PORT']}")
  end

  def good_ieid name
    StoreUtils.valid_ieid_name? name
  end

  def request_md5
    StoreUtils.base64_to_md5hex(@env["HTTP_CONTENT_MD5"])
  end


  def web_location path
    service_name + (path =~ %r{^/} ?  path : '/' + path)
  end

  # provide the uri-request for the current resource

  def this_resource
    web_location @env['SCRIPT_NAME'].gsub(%r{/+$}, '') + '/' + @env['PATH_INFO'].gsub(%r{^/+}, '')
  end

  # Raise specific Http400Errors if a particular package name has been, or is, in use.

  def raise_exception_if_in_use name
    raise Http403, "The resource #{this_resource} already exists; it can't be reused, even if deleted" if Package.exists?(name)
    raise Http400, "Can't use resource #{this_resource}; it has been previously created and deleted"   if Package.was_deleted?(name)
  end

  # Raise specific Http400Errors if a particular package name has never been created
  # or has been created and deleted.

  def raise_exception_if_missing name
    raise Http410, "Resource #{this_resource} has been previously created and deleted"     if Package.was_deleted?(name)
    raise Http404, "The resource #{this_resource} doesn't exist"                       unless Package.exists?(name)
  end

  def poolses num
    case num.to_i
    when 0    ; "no pools"
    when 1    ; "one pool"
    when 2    ; "two pools"
    when 3    ; "three pools"
    else      ; "#{num} pools"
    end
  end

  # TODO: learn how to best use this

  def partial(page, options={})
    haml page, options.merge!(:layout => false)
  end

  # return the URL, as a string, of the preferred copy of package, with '/' appended so we get the inspection page for the package.

  def inspection_url package
    return nil unless package
    return nil if package.locations.empty?
    return package.locations[0].to_s + '/'
  end


  # when hendling the /pools form, we want to check the user-submitted
  # form data and return a hash of only those changes necessary;
  # values are cast to the correct types.

  def pool_parameters_to_change pool, params

    changes = {}

    # handle username/passwords

    # An empty string in the form is considered nil, but both username and password should be blank if we really want to do without any credentials

    params['basic_auth_username'] = nil if params['basic_auth_username'] == ''
    params['basic_auth_password'] = nil if params['basic_auth_password'] == ''

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

end # of helpers do
