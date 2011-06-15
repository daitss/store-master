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

  @pools        = Pool.list_all.sort { |a,b| a.name <=> b.name }
  @required     = settings.minimum_required_pools

  haml :pools
end


get '/pool/:id' do |id|
  @pool   = Pool.get(id)
  raise BadPoolParameter, "No pool is associated with pool id #{id}" if @pool.nil?

  haml :'pool'
end


post '/pool-handler/:id' do |id|

  pool   = Pool.get(id)

  raise BadPoolParameter, "No pool is associated with pool id #{id}" if pool.nil?

  changes = pool_parameters_to_change(pool, params)
  Logger.warn "Request from #{@env['REMOTE_ADDR']} modified the silo pool '#{pool.name}': #{changes.inspect}"

  changes.each { |method, new_value| pool.assign(method, new_value) }

  redirect '/pools'
end
