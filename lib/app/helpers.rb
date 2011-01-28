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
    'http://' +
      (@env['HTTP_HOST'] || @env['SERVER_NAME']).gsub(/:\d+$/, '') +
      (@env['SERVER_PORT'] == '80' ? '' : ":#{@env['SERVER_PORT']}")
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

end # of helpers do

