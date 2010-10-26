helpers do
  include Rack::Utils     # to get escape_html

  # service_name
  #
  # Return our virtual server name as a minimal URL.
  #
  # Safety note: HTTP_HOST, according to the rack docs, is preffered
  # over SERVER_NAME if it the former exists, but it can be borken -
  # sometimes comes with port attached! SERVER_NAME is always defined.

  def service_name
    'http://' +
      (@env['HTTP_HOST'] || @env['SERVER_NAME']).gsub(/:\d+$/, '') +
      (@env['SERVER_PORT'] == '80' ? '' : ":#{@env['SERVER_PORT']}")
  end

  def good_ieid name
    name =~ /^E[A-Z0-9]{8}_[A-Z0-9]{6}$/    # ieid or ieid.vers  accepted
  end

  def request_md5
    StoreUtils.base64_to_md5hex(@env["HTTP_CONTENT_MD5"])
  end

  def web_location path
    service_name + (path =~ %r{^/} ?  path : '/' + path)
  end

  def this_resource 
    web_location @env['SCRIPT_NAME'].gsub(%r{/+$}, '') + '/' + @env['PATH_INFO'].gsub(%r{^/+}, '')
  end

end # of helpers do

