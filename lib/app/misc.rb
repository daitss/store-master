SEARCH_RESULTS_LIMIT = 50

get '/search' do
  @pattern  = (params[:pattern].nil? or params[:pattern] == '') ?  nil : params[:pattern]
  @packages = @pattern.nil? ? [] : Package.search(@pattern.upcase, SEARCH_RESULTS_LIMIT)

  if not @pattern
    @note = 'Enter your search text and hit enter: '
    haml :'no-search-results'

  elsif @packages.empty?
    @note = 'No packages matched your search: '
    haml :'no-search-results'

  else
    @note  = (@packages.length == SEARCH_RESULTS_LIMIT ? "This search exceeded the #{SEARCH_RESULTS_LIMIT} package results limit; please consider a more restricted search: " : "Returned #{@packages.length} result#{'s' if @packages.length != 1} for: ")
    haml :'search-results'
  end
end


get '/pools' do
  @pools    = Pool.list_all.sort { |a,b| a.name <=> b.name }
  @required = settings.required_pools
  haml :pools
end

PASSWORD_SENTINEL    = '*' * 16  # we don't have access to the original password; we use this to indicate a password is set in the forms

get '/security' do
  credentials = StoreMasterModel::Authentication.lookup('admin')
  @password   = (credentials.nil? ? '' : PASSWORD_SENTINEL)
  haml :security
end

get '/password-set' do
  @outcome = :set
  haml :'password-status'
end

get '/password-unchanged' do
  @outcome = :unchanged
  haml :'password-status'
end

get '/password-cleared' do
  @outcome = :cleared
  haml :'password-status'
end

post '/credentials-handler' do
  credentials = StoreMasterModel::Authentication.lookup('admin')

  case params[:password]

  when nil
    raise BadPassword, 'no password supplied'

  when PASSWORD_SENTINEL                                # no change was requested
    redirect '/password-unchanged'

  when /^$/                                             # no password; clear it if unset
    if not credentials.nil?
      Logger.warn "Request from #{@env['REMOTE_ADDR']} to clear the password protection for this storage master."
      StoreMasterModel::Authentication.clear
      redirect '/password-cleared'
    else
      redirect '/password-unchanged'
    end

  else
    Logger.warn "Request from #{@env['REMOTE_ADDR']} to set a password for this storage master."
    StoreMasterModel::Authentication.create('admin', params[:password]) 
    redirect '/password-set'
  end

  redirect '/'
end

get '/pool/:id' do |id|
  @pool   = Pool.get(id)
  raise BadPoolParameter, "No pool is associated with pool id #{id}" if @pool.nil?

  haml :pool
end

post '/pool-handler/:id' do |id|

  pool   = Pool.get(id)

  raise BadPoolParameter, "No pool is associated with pool id #{id}" if pool.nil?

  changes = pool_parameters_to_change(pool, params)

  Logger.warn "Request from #{@env['REMOTE_ADDR']} modified the silo pool '#{pool.name}': #{display_params_safely changes}"

  changes.each { |method, new_value| pool.assign(method, new_value) }

  redirect '/pools'
end

# testing stuff:

get '/settings' do
  opts = {}

  [ :absolute_redirects, :add_charsets, :app_file, :bind, :default_encoding, :dump_errors, :environment, :lock,
    :logging, :method_override, :port, :prefixed_redirects, :public, :raise_errors, :reload_templates, :root,
    :run, :running, :server, :sessions, :show_exceptions, :static, :views ].each  do |key|

    if settings.respond_to? key
      value = settings.send key
      opts[key] = value.inspect
    else
      opts[key] = '<no setting defined>'
    end
  end

  erb :settings, :locals => { :opts => opts }
end
