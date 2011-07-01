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
