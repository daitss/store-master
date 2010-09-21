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

  def good_name name
    name =~ /^E\d{8}_[A-Z]{6}$/
  end

  def request_md5
    StoreUtils.base64_to_md5hex(@env["HTTP_CONTENT_MD5"])
  end

  def web_location path
    service_name + (path =~ %r{^/} ?  path : '/' + path)
  end
end

