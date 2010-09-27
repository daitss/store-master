#
# This is where we keep track of submitted packages.  Right now, I'm
# merely staging them to allow Franco to code to the API; in the near
# future we'll actually find external silos to store them to.
#

get '/packages/:ieid' do |ieid|
  ds = DiskStore.new(settings.staged_root)

  raise Http410, "Resource #{this_resource} has been deleted"  if Package.was_deleted?(ieid)
  raise Http404, "There is no such resource #{this_resource}." unless Package.exists?(ieid)
  raise DiskStoreError, "Our database indicates we have the resource #{this_resource}, but it isn't present on any silo." unless ds.exists?(ieid)
  
  etag ds.etag(ieid)
  headers 'Content-MD5' => StoreUtils.md5hex_to_base64(ds.md5 ieid), 'Content-Type' => ds.type(ieid)
  send_file ds.data_path(ieid), :filename => "#{ieid}.tar"
end


put '/packages/:ieid' do |ieid|
  ds = DiskStore.new(settings.staged_root)

  raise Http403, "The resource #{this_resource} already exists" if Package.exists?(ieid)
  raise Http400, "Can't use resource #{this_resource}: it has been previously created and deleted"  if Package.was_deleted?(ieid)

  supplied_md5 = request_md5()
  
  raise Http400, "The identifier #{ieid} does not meet the resource naming convention for #{this_resource}" unless good_name ieid
  raise Http400, "Missing the Content-MD5 header, required for PUTs to #{web_location('/pacakges/')}" unless supplied_md5
  raise Http400, "This site only accepts content types of application/x-tar"   unless (request.content_type and request.content_type == 'application/x-tar')


  data = request.body                                          # singleton method to provide content length. (ds.put needs
  eval "def data.size; #{request.content_length.to_i}; end"    # to garner size; but that's not provided by 'rewindable' body object)
  ds.put(ieid, data, request.content_type)
  computed_md5 = ds.md5(ieid)

  if computed_md5 != supplied_md5
    ds.delete(ieid)
    raise Http409, "The request indicated the MD5 was #{supplied_md5}, but the server computed #{computed_md5}"
  end

  p = Package.new_from_diskstore(ieid, ds)    #### TODO:  tons more here

  status 201
  headers 'Location' => this_resource, 'Content-Type' => 'application/xml'

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
  xml.target!
end


delete '/packages/:ieid' do |ieid|
  ds = DiskStore.new(settings.staged_root)

  ds.delete(ieid) if ds.exists?(ieid)

  raise Http410, "Resource #{this_resource} has already been deleted"  if Package.was_deleted?(ieid)
  raise Http404, "There is no such resource #{this_resource}." unless Package.exists?(ieid)

  Package.delete(ieid) 
  status 204
end


get '/packages/?' do 
  ds = DiskStore.new(settings.staged_root)

  xml = Builder::XmlMarkup.new(:indent => 2)
  xml.instruct!(:xml, :encoding => 'UTF-8')
  
  xml.updates(:location => web_location('/packages/'), :time =>  Time.now.iso8601) {
    Package.names.each do |ieid|
      pkg = Package.lookup ieid
      xml.package(:ieid     => ieid,
                  :md5      => pkg.md5,
                  :sha1     => pkg.sha1,
                  :size     => pkg.size,
                  :type     => pkg.type,
                  :time     => pkg.datetime.to_s,
                  :location => web_location("/packages/#{ieid}"))
    end
  }
  content_type 'application/xml'
  xml.target!

end
