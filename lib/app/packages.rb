# Package handling

# Reserve a new name to PUT to.  Requires a well-formed parameter
# IEID, and returns an XML document providing the named resource; If
# the IEID E20000000_AAAAAA is provided, it might return the following
# document:
#
#   <?xml version="1.0" encoding="UTF-8"?>
#   <reserved
#        ieid="E20000000_AAAAAA" 
#    location="http://store-master.example.com/packages/E20000000_AAAAAA.001"
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

# Put a package tarfile to previously reserved name; on success returns information
# about the created resource with an XML document. For example:
#
#  <?xml version="1.0" encoding="UTF-8"?>
#  <created 
#        ieid="E20000000_AAAAAA"
#    location="http://store-master.example.com/packages/E20000000_AAAAAA.001"
#         md5="4732518c5fe6dbeb8429cdda11d65c3d"
#        name="E20000000_AAAAAA.001"
#        sha1="ccd53fa068173b4f5e52e55e3f1e863fc0e0c201"
#        size="3667"
#        type="application/x-tar"
#  />

put '/packages/:name' do |name|

  raise_exception_if_in_use(name)

  raise Http400, "Missing the Content-MD5 header, required for PUTs to #{this_resource}"  unless request_md5
  raise Http400, "#{this_resource} only accepts content types of application/x-tar"       unless request.content_type == 'application/x-tar'

  ieid = Reservation.find_ieid(name)

  pools = Pool.list_active

  raise ConfigurationError, "No active pools are configured." if not pools or pools.empty?

  metadata = { :name => name, :ieid => ieid, :md5 => request_md5, :type => request.content_type, :size => request.content_length }

  pkg = Package.store(request.body, metadata)

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

# Delete a package by name.

delete '/packages/:name' do |name|

  raise_exception_if_missing(name)

  begin
    Package.lookup(name).delete
  rescue DriveByError => e
    Logger.err "Orphan alert - DELETE of resource #{this_resource} partially failed:  #{e.message}"
  end

  status 204
end

# Return a package via redirect

get '/packages/:name' do |name|

  raise_exception_if_missing(name)

  locations = Package.lookup(name).locations

  # TODO, maybe: ping them (via head) in order with an aggressive timeout,  using first that responds.
  # needs to wait on silo rework to make sure we can do HEADs on tape-based systems quickly.

  raise "No remote storage locations are associated with #{this_resource}" unless locations.length > 0

  redirect locations[0].to_s_with_userinfo, 303
end

# Return an XML report of all the packages we know about, ordered by package name. For
# example:
#
#  <packages location="http://store-master.example.com/packages" time="2011-01-22T16:32:11-05:00">
#    <package name="E20000000_AAAAAA.001" ieid="E20000000_AAAAAA" location="http://store-master.example.com/packages/E20000000_AAAAAA.001"/>
#    <package name="E20100727_AAAAAA.008" ieid="E20100727_AAAAAA" location="http://store-master.example.com/packages/E20100727_AAAAAA.008"/>
#    <package name="E20111201_AAAAAA.000" ieid="E20111201_AAAAAA" location="http://store-master.example.com/packages/E20111201_AAAAAA.000"/>
#    <package name="E20111201_AAAAAA.001" ieid="E20111201_AAAAAA" location="http://store-master.example.com/packages/E20111201_AAAAAA.001"/>
#  </packages>

get '/packages.xml' do
  [ 200, {'Content-Type'  => 'application/xml'}, PackageXmlReport.new(service_name + '/packages') ]   ## TODO: use Package.server_location= in setup
end

# Return a CSV report of all the packages we know about, ordered by package name
#
#   "name","location","ieid"
#   "E20000000_AAAAAA.001","http://store-master.local/packages/E20000000_AAAAAA.001","E20000000_AAAAAA"
#   "E20100727_AAAAAA.008","http://store-master.local/packages/E20100727_AAAAAA.008","E20100727_AAAAAA"
#   "E20111201_AAAAAA.000","http://store-master.local/packages/E20111201_AAAAAA.000","E20111201_AAAAAA"
#   "E20111201_AAAAAA.001","http://store-master.local/packages/E20111201_AAAAAA.001","E20111201_AAAAAA"

get '/packages.csv' do
  [ 200, {'Content-Type'  => 'text/csv'}, PackageCsvReport.new(service_name + '/packages') ]        ## TODO: use Package.server_location= in setup
end

# Redirect from plain old /packages or /packages/

get '/packages/?' do
  redirect '/packages.xml', 301
end
