# Handling packages

# Reserve a new name to PUT to.  Requires an IEID.

post '/reserve/?' do
  raise Http412, "Missing expected paramter 'ieid'." unless ieid = params[:ieid]
  raise Http400, "The identifier #{ieid} does not meet the resource naming convention for #{this_resource}" unless good_ieid ieid

  res = Reservation.new ieid
  
  xml = Builder::XmlMarkup.new(:indent => 2)
  xml.instruct!(:xml, :encoding => 'UTF-8')
  xml.reserved(:ieid => ieid, :location => web_location("/packages/#{res.name}"))

  status 201
  content_type 'application/xml'
  headers 'Location' => web_location("/packages/#{res.name}"), 'Content-Type' => 'application/xml'
  xml.target!
end


# Put a tarfile package to previously reserved name.

put '/packages/:name' do |name|
  ieid = Reservation.lookup_ieid(name)

  raise Http404, "The resource for #{name} must first be reserved before the data can be PUT"   unless ieid
  raise Http403, "The resource #{this_resource} already exists"                                     if Package.exists?(name)
  raise Http400, "Can't use resource #{this_resource}: it has been previously created and deleted"  if Package.was_deleted?(name)
  raise Http400, "Missing the Content-MD5 header, required for PUTs to #{this_resource}"  unless request_md5
  raise Http400, "#{this_resource} only accepts content types of application/x-tar"       unless request.content_type == 'application/x-tar' 

  pools = Pool.list_active

  raise ConfigurationError, "No active pools are configured." if not pools or pools.empty?

  ### TODO: *number* of pools to store needs to be checked against a configuration variable... <=

  metadata = { :name => name, :ieid => ieid, :md5 => request_md5, :type => request.content_type, :size => request.content_length }

  pkg = Package.create(request.body, metadata, pools)

  status 201
  headers 'Location' => this_resource, 'Content-Type' => 'application/xml'

  xml = Builder::XmlMarkup.new(:indent => 2)
  xml.instruct!(:xml, :encoding => 'UTF-8')
  xml.created(:ieid     => pkg.ieid,
              :location => this_resource,
              :md5      => pkg.md5,
              :name     => pkg.name,
              :sha1     => pkg.sha1,
              :size     => pkg.size,
              :time     => pkg.datetime,
              :type     => pkg.type)
  xml.target!  
end

# Deletes a package.

delete '/packages/:name' do |name|
  raise Http410, "Resource #{this_resource} has already been deleted"  if Package.was_deleted?(name)
  raise Http404, "No such resource #{this_resource}."              unless Package.exists?(name)

  begin
    Package.lookup(name).delete
  rescue DriveByError => e
    Logger.err "DELETE of resource #{this_resource} partially failed:  #{e.message}"
  end

  status 204
end


# Gets a package via redirect.

get '/packages/:name' do |name|
  raise Http410, "Resource #{this_resource} has been deleted"  if Package.was_deleted?(name)
  raise Http404, "No such resource #{this_resource}."      unless Package.exists?(name)

  locations = Package.lookup(name).locations

  # TODO: check that a location has been returned;  ping them (via head) in order,  using first that responds (need to streamline heads for this to work)
  # TODO: get locations returned in read_preference order

  raise "No remote storage locations are associated with #{this_resource}" unless locations.length > 0
  redirect locations[0], 303
end

# Get an XML file of all the packages we know about.  This is so slow as to be impractical, right now.

get '/packages/?' do 
  xml = Builder::XmlMarkup.new(:indent => 2)
  xml.instruct!(:xml, :encoding => 'UTF-8')
  
  xml.updates(:location => web_location('/packages/'), :time =>  Time.now.iso8601) {
    Package.names.each do |name|
      pkg = Package.lookup name
      xml.package(:name     => name,
                  :ieid     => pkg.ieid,
                  :location => web_location("/packages/#{name}"))
    end
  }
  content_type 'application/xml'
  xml.target!
end
