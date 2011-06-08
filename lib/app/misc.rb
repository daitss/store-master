SEARCH_RESULTS_LIMIT = 50

get '/search' do
  Package.server_location = service_name  # TODO: we need to do better setting this up.

  @pattern  = (params[:pattern].nil? or params[:pattern] == '') ?  nil : params[:pattern]
  @packages = @pattern.nil? ? [] : Package.search(@pattern, SEARCH_RESULTS_LIMIT)
  @revision = StoreMaster.version.name

  if not @pattern
    @note = 'Enter your search text: '
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
  Package.server_location = service_name  # TODO: we need to do better setting this up.

  @name     = service_name
  @pools    = Pool.list_active
  @required = settings.minimum_required_pools
  
  haml :pools
end


post '/pool/:id' do |id|

  pool   = Pool.get(id)

  raise BadPoolParameter, "No pool is associated with pool id #{id}" if pool.nil?

#  @params = params

#  to_change = pool_params(pool, params)  # hash of what we really need to change, checked and correctly type cast; will raise BadPoolParameter on inconsistency

#  to_change.each { |method, value|  pool.assign(method, value) }

#  Logger.warn "Request from #{@env['REMOTE_ADDR']} modified the pool #{pool.name}: #{to_change.keys.sort { |k| } k => to_change[k].to_s + ';  ' }"  

  Logger.warn "Request from #{@env['REMOTE_ADDR']} modified the pool #{pool.name}: "  

  haml :'pool-ctl'
end
