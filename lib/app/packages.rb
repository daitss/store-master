# Package handling


# POST /reserve { :ieid => <name> }
#
# Reserve a new <name> we can use to PUT to /packages/<name>.  Requires
# a well-formed parameter IEID, and returns an XML document providing
# the named resource; If the IEID E20000000_AAAAAA is provided, it
# might return the following document:
#
#   <?xml version="1.0" encoding="UTF-8"?>
#   <reserved
#        ieid="E20000000_AAAAAA"
#    location="http://storage-master.example.com/packages/E20000000_AAAAAA.001"
#   />


post '/reserve/?' do

  name = Reservation.make(params[:ieid])
  xml  = Builder::XmlMarkup.new(:indent => 2)

  xml.instruct!(:xml, :encoding => 'UTF-8')
  xml.reserved(:ieid => params[:ieid], :location => web_location("/packages/#{name}"))

  status 201
  content_type 'application/xml'
  headers 'Location' => web_location("/packages/#{name}"), 'Content-Type' => 'application/xml'
  xml.target!

end

#  PUT /packages/<name>
#
# Put a package tarfile to previously reserved name; on success returns information
# about the created resource with an XML document. For example:
#
#  <?xml version="1.0" encoding="UTF-8"?>
#  <created
#        ieid="E20000000_AAAAAA"
#    location="http://storage-master.example.com/packages/E20000000_AAAAAA.001"
#         md5="4732518c5fe6dbeb8429cdda11d65c3d"
#        name="E20000000_AAAAAA.001"
#        sha1="ccd53fa068173b4f5e52e55e3f1e863fc0e0c201"
#        size="3667"
#        type="application/x-tar"
#  />

put '/packages/:name' do |name|
  log_start_of_request

  raise_exception_if_in_use(name)

  raise Http400, "Missing the Content-MD5 header, required for PUTs to #{this_resource}"  unless request_md5
  raise Http400, "#{this_resource} only accepts content types of application/x-tar"       unless request.content_type == 'application/x-tar'

  ieid = Reservation.find_ieid(name)

  pools = Pool.list_active   # greatest preference first

  if pools.length < settings.required_pools
    raise ConfigurationError, "This service is configured to require #{poolses(settings.required_pools)}, but the database entires lists #{poolses(pools.length)}"
  end

  metadata = { :name => name, :ieid => ieid, :md5 => request_md5, :type => request.content_type, :size => request.content_length }

  if settings.required_pools == 0                   # then we're a stub server
    pkg = Package.stub(request.body, metadata)
  else
    pkg = Package.store(request.body, metadata, pools[0 .. settings.required_pools - 1])
  end

  xml = Builder::XmlMarkup.new(:indent => 2)
  xml.instruct!(:xml, :encoding => 'UTF-8')
  xml.created(:ieid     => pkg.ieid,
              :location => this_resource,
              :name     => pkg.name,
              :md5      => pkg.md5,
              :sha1     => pkg.sha1,
              :size     => pkg.size,
              :type     => pkg.type
              )

  status 201
  headers 'Location' => this_resource, 'Content-Type' => 'application/xml'
  xml.target!

end

# DELETE /packages/<name>
#
# Delete a package by name, typically an IEID.  Note that a common
# exception (heh) is for one or more of the downstream delete on a
# silo-pool to fail, and will result in returning a "207 Multi-status"
# with a text document explaining the failures.  Never the less, the
# storage master will mark it deleted.  Our fixity checking scripts
# will let us know when this case has occured and needs to be cleaned
# up out of band.

delete '/packages/:name' do |name|
  raise_exception_if_missing(name)   # return 404 or 410
  Package.lookup(name).delete
  status 204
end

# GET /packages/<name>
#
# Return the location of package <name> via redirect.  We could be
# smarter about which of the locations we use, but it's not necessary
# at the moment (for instance, we could ping using a HEAD for all the
# locations for availability).

get '/packages/:name' do |name|
  raise_exception_if_missing(name)
  locations = Package.lookup(name).locations
  raise Http404, "No remote storage locations are associated with #{this_resource}" unless locations.length > 0
  redirect locations[0].to_s_with_userinfo, 303
end

# GET /packages.xml
#
# Return an XML report of all the packages we know about, ordered by package name. For
# example:
#
#  <packages location="http://storage-master.example.com/packages" time="2011-01-22T16:32:11-05:00">
#    <package name="E20000000_AAAAAA.001" ieid="E20000000_AAAAAA" location="http://storage-master.example.com/packages/E20000000_AAAAAA.001"/>
#    <package name="E20100727_AAAAAA.008" ieid="E20100727_AAAAAA" location="http://storage-master.example.com/packages/E20100727_AAAAAA.008"/>
#    <package name="E20111201_AAAAAA.000" ieid="E20111201_AAAAAA" location="http://storage-master.example.com/packages/E20111201_AAAAAA.000"/>
#    <package name="E20111201_AAAAAA.001" ieid="E20111201_AAAAAA" location="http://storage-master.example.com/packages/E20111201_AAAAAA.001"/>
#  </packages>


get '/packages.xml' do
  log_start_of_request
  [ 200, {'Content-Type'  => 'application/xml'}, PackageXmlReport.new(service_name + '/packages') ]
end


# GET /packages.csv
#
# Return a CSV report of all the packages we know about, ordered by package name
#
#   "name","location","ieid"
#   "E20000000_AAAAAA.001","http://storage-master.local/packages/E20000000_AAAAAA.001","E20000000_AAAAAA"
#   "E20100727_AAAAAA.008","http://storage-master.local/packages/E20100727_AAAAAA.008","E20100727_AAAAAA"
#   "E20111201_AAAAAA.000","http://storage-master.local/packages/E20111201_AAAAAA.000","E20111201_AAAAAA"
#   "E20111201_AAAAAA.001","http://storage-master.local/packages/E20111201_AAAAAA.001","E20111201_AAAAAA"

get '/packages.csv' do
  log_start_of_request
  [ 200, {'Content-Type'  => 'text/csv'}, PackageCsvReport.new(service_name + '/packages') ]
end

# Redirect from plain old /packages or /packages/ to the XML document

get '/packages/?' do
  redirect '/packages.xml', 303
end
