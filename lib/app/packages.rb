# This is where we keep track of submitted packages.  Right now, I'm
# merely staging them locallly to allow Franco to code to the API; in the near
# future we'll actually find external silos to store them to.

post '/reserve/?' do
  raise Http412, "Missing expected paramter 'ieid'." unless ieid = params[:ieid]
  res = Store::Reservation.new ieid
  
  xml = Builder::XmlMarkup.new(:indent => 2)
  xml.instruct!(:xml, :encoding => 'UTF-8')
  xml.reserved(:ieid => ieid, :location => web_location("/packages/#{res.name}"))
  xml.target!

  status 201
  content_type 'application/xml'
  headers 'Location' => web_location("/packages/#{res.name}"), 'Content-Type' => 'application/xml'
  xml.target!
end


put '/packages/:name' do |name|

  ds   = DiskStore.new(settings.staged_root)
  ieid = Store::Reservation.lookup_ieid(name)

  raise Http404, "The resource for #{name} must first be reserved before the data can be PUT"       unless ieid
  raise Http403, "The resource #{this_resource} already exists"                                     if Package.exists?(name)
  raise Http400, "Can't use resource #{this_resource}: it has been previously created and deleted"  if Package.was_deleted?(name)

  supplied_md5 = request_md5()
  
  raise Http400, "The identifier #{ieid} does not meet the resource naming convention for #{this_resource}" unless good_name ieid
  raise Http400, "Missing the Content-MD5 header, required for PUTs to #{web_location('/pacakges/')}"       unless supplied_md5
  raise Http400, "This site only accepts content types of application/x-tar"                                unless (request.content_type and request.content_type == 'application/x-tar')

  # Save a temporary local copy here....

  data = request.body                                          # singleton method to provide content length. (ds.put needs
  eval "def data.size; #{request.content_length.to_i}; end"    # to garner size; but that's not provided by 'rewindable' body object)
  ds.put(name, data, request.content_type)
  computed_md5 = ds.md5(name)

  # WET:

  if ds.md5(name) != supplied_md5
    begin
      ds.delete(name)
    rescue => e
      Logger.err "Failure in cleanup of disk store after failed PUT to #{this_resource}: #{e.message}", @env
      e.backtrace.each { |line| Logger.err line }
    end
    raise Http409, "The request indicated the MD5 was #{supplied_md5}, but the server computed #{computed_md5}"
  end

  if ds.size(name) != request.content_length.to_i
    begin
      ds.delete(name)
    rescue => e
      Logger.err "Failure in cleanup of disk store after failed PUT to #{this_resource}: #{e.message}", @env
      e.backtrace.each { |line| Logger.err line }
    end
    raise Http409, "The request indicated the file size was #{request.content_length.to_i}, but the server computed #{ds.size(name)}"
  end

  # TODO: forward to pools here.

  pkg = Package.new_from_diskstore(ieid, name, ds)    

# pools = Pool.list_active
# pools.each { |pool| pkg.copy_to pool }

  status 201
  headers 'Location' => this_resource, 'Content-Type' => 'application/xml'

  xml = Builder::XmlMarkup.new(:indent => 2)
  xml.instruct!(:xml, :encoding => 'UTF-8')
  xml.created(:name     => name,
              :ieid     => ieid,
              :etag     => ds.etag(name),
              :md5      => ds.md5(name),
              :sha1     => ds.sha1(name),
              :size     => ds.size(name),
              :type     => ds.type(name),
              :time     => ds.datetime(name).to_s,
              :location => this_resource)
  xml.target!
end


delete '/packages/:name' do |name|
  ds = DiskStore.new(settings.staged_root)

  ds.delete(name) if ds.exists?(name)

  raise Http410, "Resource #{this_resource} has already been deleted"  if Package.was_deleted?(name)
  raise Http404, "There is no such resource #{this_resource}." unless Package.exists?(name)

  Package.delete(name) 
  status 204
end


get '/packages/:name' do |name|
  ds = DiskStore.new(settings.staged_root)

  raise Http410, "Resource #{this_resource} has been deleted"  if Package.was_deleted?(name)
  raise Http404, "There is no such resource #{this_resource}." unless Package.exists?(name)
  raise DiskStoreError, "Our database indicates we have the resource #{this_resource}, but it isn't present on any silo." unless ds.exists?(name)
  
  etag ds.etag(name)
  headers 'Content-MD5' => StoreUtils.md5hex_to_base64(ds.md5 name), 'Content-Type' => ds.type(name)
  send_file ds.data_path(name), :filename => "#{name}.tar"
end


get '/packages/?' do 
  ds = DiskStore.new(settings.staged_root)

  xml = Builder::XmlMarkup.new(:indent => 2)
  xml.instruct!(:xml, :encoding => 'UTF-8')
  
  xml.updates(:location => web_location('/packages/'), :time =>  Time.now.iso8601) {
    Package.names.each do |name|
      pkg = Package.lookup name
      xml.package(:name     => name,
                  :ieid     => pkg.ieid,
                  :md5      => pkg.md5,
                  :sha1     => pkg.sha1,
                  :size     => pkg.size,
                  :type     => pkg.type,
                  :time     => pkg.datetime.to_s,
                  :location => web_location("/packages/#{name}"))
    end
  }
  content_type 'application/xml'
  xml.target!

end
