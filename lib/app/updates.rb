# Deal with the /updates route.
#
# PUT     /updates/:ieid    - if a user wants to update an existing package, start an update transaction here
# GET     /updates/:ieid    - download it (really only for qa)
# POST    /updates/:ieid    - if a user really wants to update, finish the transaction by POSTing commit=true
# DELETE  /updates/ieiid    - they can cancel the transaction here.
# GET     /updates/         - list the IEIDs, mostly 

put  '/updates/:ieid' do |ieid|
  # TODO: locking issues?

  ds  = DiskStore.new(settings.updates_root)

  raise Http409, "There is no stored package by the name of #{ieid} to update; use PUT instead." unless Package.exists?(ieid)
  raise Http403, "The resource #{this_resource} already exists; you must delete it first" if ds.exists?(ieid)
  raise Http409, "This site only accepts content types of application/x-tar" unless (request.content_type and request.content_type == 'application/x-tar')
  raise Http409, "The identifier #{ieid} does not meet the resource naming convention for #{this_resource}" unless good_name(ieid)
  
  supplied_md5 = request_md5()
  
  raise Http409, "Missing the Content-MD5 header, required for PUTs to #{this_resource}" unless supplied_md5

  data = request.body                                          # singleton method to provide content length. (diskstore.put needs
  eval "def data.size; #{request.content_length.to_i}; end"    # to garner size; but that's not provided by 'rewindable' body object)    
  ds.put(ieid, data, request.content_type)
  computed_md5 = ds.md5(ieid)

  unless computed_md5 == supplied_md5
    ds.delete(ieid)
    raise Http412, "The request indicated the MD5 was #{supplied_md5}, but the server computed #{computed_md5}"
  end

  xml = Builder::XmlMarkup.new(:indent => 2)
  xml.instruct!(:xml, :encoding => 'UTF-8')
  xml.created(:name     => ieid,
              :etag     => ds.etag(ieid),
              :md5      => ds.md5(ieid),
              :sha1     => ds.sha1(ieid),
              :size     => ds.size(ieid),
              :type     => ds.type(ieid),
              :time     => ds.datetime(ieid).to_s,
              :location => this_resource)
  status 201
  content_type 'application/xml'
  xml.target!
end


get '/updates/:ieid' do |ieid|
  ds = DiskStore.new(settings.updates_root)
  raise Http404, "The resource #{this_resource} doesn't exist" unless ds.exists?(ieid)
  etag ds.etag(ieid)
  headers 'Content-MD5' => StoreUtils.md5hex_to_base64(ds.md5 ieid), 'Content-Type' => ds.type(ieid)
  send_file ds.data_path(ieid), :filename => "#{ieid}.tar"
end

# list all of the updates

get '/updates/?' do
  ds = DiskStore.new(settings.updates_root)

  xml = Builder::XmlMarkup.new(:indent => 2)
  xml.instruct!(:xml, :encoding => 'UTF-8')
  
  xml.updates(:location => web_location('/updates/'), :time =>  Time.now.iso8601) {
    ds.each do |ieid|
      xml.package(:ieid     => ieid,
                  :etag     => ds.etag(ieid),
                  :md5      => ds.md5(ieid),
                  :sha1     => ds.sha1(ieid),
                  :size     => ds.size(ieid),
                  :type     => ds.type(ieid),
                  :time     => ds.datetime(ieid).to_s,
                  :location => web_location("/updates/#{ieid}"))
    end
  }
  content_type 'application/xml'
  xml.target!
end

delete '/updates/:ieid' do |ieid|
  ds = DiskStore.new(settings.updates_root)
  raise Http404, "The resource #{this_resource} does not exist" unless ds.exists?(ieid)
  ds.delete(ieid)
  status 204
end

# An updated package is ready to be commited....

post '/updates/:ieid'  do |ieid|

  ## TODO: check that locking logic will work as expected here.

  source = DiskStore.new(settings.updates_root)

  raise Http404, "The resource #{this_resource} doesn't exist."  unless source.exists? ieid
  raise Http412, "Missing expected paramter 'commit."                               unless commit = params[:commit]
  raise Http412, "Are your afraid to commit? Wanted true, but got #{commit}."       unless commit.downcase == 'true'

  ### TODO: we're currently just saving to our staging silo for testing
  ### TODO: send to individual silos, update package events

  destination = DiskStore.new(settings.staging_root)

  source.dopen(ieid) { |io|  destination.put(ieid, io, source.type(ieid)) }

  unless source.md5(ieid) == destination.md5(ieid)
    destination.delete(ieid)
    raise DiskStoreError, "Error committing resource #{this_resource}, MD5 checkum mismatch." 
  end

  xml = Builder::XmlMarkup.new(:indent => 2)
  xml.instruct!(:xml, :encoding => 'UTF-8')
  xml.created(:ieid     => ieid,
              :etag     => destination.etag(ieid),
              :md5      => destination.md5(ieid),
              :sha1     => destination.sha1(ieid),
              :size     => destination.size(ieid),
              :type     => destination.type(ieid),
              :time     => destination.datetime(ieid).to_s,
              :location => web_location("/packages/#{ieid}"))

  status 201
  content_type 'application/xml'
  headers 'Location' => web_location("/packages/#{ieid}"), 'Content-Type' => destination.type(ieid)
  xml.target!
end

