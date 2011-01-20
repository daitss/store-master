require 'dm-core'
require 'dm-types'
require 'dm-aggregates'
require 'dm-migrations'
require 'dm-transactions'
require 'dm-validations'
require 'store-master/disk-store'
require 'store-master/exceptions'
require 'store-master/utils'
require 'time'
require 'uri'
require 'net/http'
require 'xml'

# URI#to_s method includes basic credentials.  This provides an alternative print method.

module URI
  class HTTP
    def sanitized
      userinfo ? to_s.sub(userinfo + '@', '') : to_s
    end
  end
end

## TODO: returned etag is missing quotes

module DataModel

include StoreMaster

  # Purpose here is to provide connections for datamapper using our yaml configuration file + key technique;

  def self.setup yaml_file, key
    oops = "DB setup can't"

    raise ConfigurationError, "#{oops} understand the configuration file name - it's not a filename string, it's a #{yaml_file.class}."  unless (yaml_file.class == String)
    raise ConfigurationError, "#{oops} understand key for the configuration file #{yaml_file} - it's not a string, it's a #{key.class}." unless (key.class == String)
    begin
      dict = YAML::load(File.open(yaml_file))
    rescue => e
      raise ConfigurationError, "#{oops} parse the configuration file #{yaml_file}: #{e.message}."
    end
    raise ConfigurationError, "#{oops} parse the data in the configuration file #{yaml_file}." if dict.class != Hash
    dbinfo = dict[key]
    raise ConfigurationError, "#{oops} get any data from the #{yaml_file} configuration file using the key #{key}."                                    unless dbinfo
    raise ConfigurationError, "#{oops} get the vendor name (e.g. 'mysql' or 'postsql') from the #{yaml_file} configuration file using the key #{key}." unless dbinfo.include? 'vendor'
    raise ConfigurationError, "#{oops} get the database name from the #{yaml_file} configuration file using the key #{key}."                           unless dbinfo.include? 'database'
    raise ConfigurationError, "#{oops} get the host name from the #{yaml_file} configuration file using the key #{key}."                               unless dbinfo.include? 'hostname'
    raise ConfigurationError, "#{oops} get the user name from the #{yaml_file} configuration file using the key #{key}."                               unless dbinfo.include? 'username'

    # Example string: 'mysql://root:topsecret@localhost/silos'

    connection_string =                                               # e.g.
      dbinfo['vendor']    + '://' +                                   # mysql://
      dbinfo['username']  +                                           # mysql://fischer
     (dbinfo['password']  ? ':' + dbinfo['password'] : '') + '@' +    # mysql://fischer:topsecret@  (or mysql://fischer@)
      dbinfo['hostname']  + '/' +                                     # mysql://fischer:topsecret@localhost/
      dbinfo['database']                                              # mysql://fischer:topsecret@localhost/store_master

    begin
      dm = DataMapper.setup(:default, connection_string)
      DataMapper.finalize
      dm.select('select 1 + 1')  # if we're going to fail (with, say, a non-existant database), let's fail now - thanks Franco for the SQL idea.
      return dm

    rescue => e
      raise ConfigurationError,
      "Failure setting up the #{dbinfo['vendor']} #{dbinfo['database']} database for #{dbinfo['username']} on #{dbinfo['hostname']} (#{dbinfo['password'] ? 'password supplied' : 'no password'}) - used the configuration file #{yaml_file}: #{e.message}"
    end
  end

  # Recreate tables for test.  We also keep mysql.ddl and psql.ddl for creating
  # the tables, which gives us a bit more flexibility (e.g., cascading deletes)

  def self.recreate_tables
    Reservation.auto_migrate!
    Pool.auto_migrate!
    Package.auto_migrate!
    Copy.auto_migrate!
  end

  # A database for reserving names for URLs based on IEIDs.

  class Reservation
    include DataMapper::Resource
    storage_names[:default] = 'reservations'    # don't want dm_packages

    property   :id,         Serial
    property   :ieid,       String,   :required => true, :index => true, :length => (16..16)
    property   :name,       String,   :required => true, :index => true, :length => (20..20) # unique name, used as part of a url

    validates_uniqueness_of :name

    def self.find_ieid name
      res = first(:name => name)
      raise NoReservation, "Can't find a reservation for #{name}: make a reservation using an IEID first"  unless res
      res.ieid
    end

    def self.make ieid

      raise NoIEID, "Missing expected parameter 'ieid'."               unless ieid
      raise BadName, "IEID #{ieid} doesn't meet our naming convention" unless StoreUtils.valid_ieid_name? ieid

      last = all(:ieid => ieid).map { |rec| rec.name.sub(/^#{ieid}/, '') }.sort.pop
      vers = last ? last.succ! : '.000'

      while vers <= '.999' do
        res  = create(:name => ieid + vers, :ieid => ieid)
        return res.name if res.saved?
        vers.succ!
      end
      raise DataBaseError, "Can't create a new name for IEID '#{ieid}'."
    end

  end


  class Package
    include DataMapper::Resource
    storage_names[:default] = 'packages'    # don't want dm_packages

    property   :id,         Serial,   :min => 1
    property   :extant,     Boolean,  :default  => true, :index => true
    property   :ieid,       String,   :required => true, :index => true
    property   :name,       String,   :required => true, :index => true      # unique name, used as part of a url

    # many-to-many  relationship - a package can (and should) have copies on several different pools

    has n,      :copies

    validates_uniqueness_of  :name

    attr_accessor :md5, :size, :type, :sha1, :etag   # scratch pad attributes filled in on succesful store

    # return URI objects for all of the copies we have, in pool-preference order

    def locations
      copies.sort { |a,b| b.pool.read_preference <=> a.pool.read_preference }.map { |copy| copy.url }
    end

    def self.exists? name
      not first(:name => name, :extant => true).nil?
    end

    def self.was_deleted? name
      not first(:name => name, :extant => false).nil?
    end

    def self.lookup name
      first(:name => name, :extant => true)
    end

    # TODO: This next is likely to result in such a long list as to be unusable in practice; need to rethink chunking this up,
    # perhaps with yield

    def self.names
      all(:extant => true, :order => [ :name.asc ] ).map { |rec| rec.name }
    end


    def store_copy io, posting_url, metadata

      # Note: posting_url may have credentials, be sure to use sanitized method on it.

      http = Net::HTTP.new(posting_url.host, posting_url.port)
      http.open_timeout = 60 * 2
      http.read_timeout = 60 * 2
      request = Net::HTTP::Post.new(posting_url.request_uri)
      io.rewind if io.respond_to?('rewind')
      request.body_stream = io
      request.initialize_http_header("Content-MD5" => StoreUtils.md5hex_to_base64(metadata[:md5]), "Content-Length" => metadata[:size].to_s, "Content-Type" => metadata[:type])
      request.basic_auth(posting_url.user, posting_url.password) if posting_url.user or posting_url.password
      response = http.request(request)
      status = response.code.to_i

      raise(SiloStoreError, "#{response.code} #{response.message} - when saving package #{metadata[:name]} to silo #{posting_url.sanitized} - #{response.body}") if status >= 300

      # Example XML document returned from POST, giving details about the resource
      # 
      #   <?xml version="1.0" encoding="UTF-8"?>                              
      #   <created type="application/x-tar"                                                                            
      #            time="2010-10-21T10:29:19-04:00"                                                                    
      #            sha1="ac4d813081e066422bc1dc7e7997ace1bfb858b2"                                                     
      #            etag="a3f07bc57127112f2a2c40d026b1abe1"                                                             
      #            md5="32e2ce3af2f98a115e121285d042c9bd"                                                              
      #            size="6031360"                                                                                      
      #            location="http://storage.local/b/data/E20101021_LJLAMU.001"                                         
      #            name="E20101021_LJLAMU.001"/>

      returned_data = {}
      begin
        parser = XML::Parser.string(response.body).parse
        parser.find('/created')[0].each_attr { |attr| returned_data[attr.name] = attr.value }
      rescue => e
        raise SiloStoreError, "Invalid XML document returned when saving package to #{posting_url.sanitized}: #{e.message}"
      end

      # check the md5, size, type vs. our request to that returned by remotely created copy.

      raise SiloStoreError, "Error storing to #{posting_url.sanitized} - md5 mismatch"   if returned_data["md5"]  != metadata[:md5]
      raise SiloStoreError, "Error storing to #{posting_url.sanitized} - size mismatch"  if returned_data["size"] != metadata[:size].to_s
      raise SiloStoreError, "Error storing to #{posting_url.sanitized} - type mismatch"  if returned_data["type"] != metadata[:type]

      self.md5  = returned_data['md5']
      self.sha1 = returned_data['sha1']
      self.type = returned_data['type']
      self.size = returned_data['size'].to_i
      self.etag = returned_data['etag']

      returned_data['location']
    end


    def self.store data_io, metadata

      required_metadata = [ :name, :ieid, :md5, :size, :type ]
      missing_metadata  = required_metadata - (required_metadata & metadata.keys)

      raise "Can't store data package, missing information for #{missing_metadata.join(', ')}"         unless missing_metadata.empty?
      raise "Can't store package #{metadata[:name]}, it already exists"                                    if exists? metadata[:name]
      raise "Can't store package using name #{metadata[:name]}, it's been previously created and deleted"  if was_deleted? metadata[:name]

      pkg = create(:name => metadata[:name], :ieid => metadata[:ieid])

      begin
        Pool.list_active.each do |pool|
          location = pkg.store_copy(data_io, pool.post_url(pkg.name), metadata)
          pkg.copies << Copy.create(:store_location => location, :pool => pool)
        end

      rescue => e1
        msg = "Failure storing a copy of #{metadata[:name]}: #{e1.message}"
        pkg.locations.each do |loc|
          begin
            pkg.delete_copy(loc)
          rescue => e2
            msg += "; also, failed in cleanup, when trying to delete copy at #{loc}: #{e2.message}"
          end
        end
        pkg.destroy if pkg.respond_to? :destroy
        raise e1, msg
      end

      if not pkg.save
        msg = "DB error recording #{name} - #{pkg.errors.full_messages.join('; ')}"
        pkg.locations.each do |loc|
          begin
            pkg.delete_copy(loc)
          rescue => e
            msg += "; also, failed in cleanup, when trying to delete copy at #{loc}: #{e.message}"
          end
        end
        raise DataBaseError, msg
      end
      pkg
    end
    
    def delete_copy silo_resource

      http = Net::HTTP.new(silo_resource.host, silo_resource.port)
      http.open_timeout = 10
      http.read_timeout = 60 * 2  # deletes are relatively fast

      request = Net::HTTP::Delete.new(silo_resource.request_uri)
      request.basic_auth(silo_resource.user, silo_resource.password) if silo_resource.user or silo_resource.password

      response = http.request(request)
      status = response.code.to_i

      raise SiloStoreError, "#{response.code} #{response.message} was returned for a failed delete of the package copy at #{silo_resource.sanitized} - #{response.body}" if status >= 300
    end

    # on failure may leave orphan

    def delete
      self.extant = false
      raise  DataBaseError, "error deleting #{self.name} - #{self.errors.full_messages.join('; ')}" unless self.save

      errs = []
      locations.each do |loc|
        begin
          delete_copy(loc)
        rescue => e
          errs.push "failed to delete storage at #{loc.sanitized}: #{e.message}"
        end
      end

      raise DriveByError, errs.join('; ') unless errs.empty?
    end

  end # of Package



  class Pool
    include DataMapper::Resource
    storage_names[:default] = 'pools'           # don't want dm_pools

    property   :id,                   Serial,   :min => 1
    property   :required,             Boolean,  :required => true, :default => true
    property   :services_location,    String,   :length => 255, :required => true
    property   :read_preference,      Integer,  :default  => 0
    property   :basic_auth_username,  String
    property   :basic_auth_password,  String

    has n, :copies

    validates_uniqueness_of :services_location

    def assign field, value
      send field.to_s + '=', value
      save or raise "Can't assign the pool #{self.inspect} property #{:field} to value #{value.inspect}"
    end


    # We have a protocol that silo pools must follow: they must return a service
    # document (XML) that descirbes where we can locate essential silo services.
    # Here's an example document:
    #
    #  <?xml version="1.0" encoding="UTF-8"?>
    #  <services version="0.0.1">
    #    <create method="post" location="http://pool-one.example.com/create/%s"/>
    #    <fixity mime_type="text/csv" method="get" location="http://pool-one.example.com/fixity.csv"/>
    #    <fixity mime_type="application/xml" method="get" location="http://pool-one.example.com/fixity.xml"/>
    #  </services>
    #
    # We require one create service that specifies a URL template (it has a slot for a name)
    # and when we POST data to that filled-in URL we'll produce a new resource; the document
    # returned from the POST will tell us where the resource has been place.
    #
    # We also have one or more URLs that describe where we can requester fixity data from; the
    # MIME type of the returned data is provided.


    def service_document
      url = URI.parse(services_location) rescue raise(ConfigurationError, "The silo services URL #{services_location.sanitized} doesn't appear to be a valid URL")

      begin # go get information from the silo services document to determine the URLs for the sub services we'll need

        request = Net::HTTP::Get.new(url.path)
        request.basic_auth(basic_auth_username, basic_auth_password) if basic_auth_username or basic_auth_password
        response = Net::HTTP.new(url.host, url.port).start do |http|
          http.open_timeout = 120
          http.read_timeout = 120
          http.request(request)
        end

      rescue => e
        raise SiloUnreachable, "Couldn't contact the silo service at URL #{services_location}: #{e.message}"

      else
        raise ConfigurationError, "Bad response when contacting the silo at #{url}, response was #{response.code} #{response.message}." unless response.code == '200'
        return response.body
      end
    end

    # return a URL we can post data directly to; we do this by requesting the silo's '/service' document
    # and parsing it for the 'create' service.  we expect it to have a '%s' in that string into which we'll
    # place the name of the resource we wish to create.

    def post_url name
      text = service_document
      parser = XML::Parser.string(text).parse
      node  = parser.find('create')[0]

      raise ConfigurationError, "When retreiving service information from the silo pool at #{services_location}, no create service was declared. The service document returned was was:\n#{text}." unless node
      raise ConfigurationError, "When retreiving service information from the silo pool at #{services_location}, no create location could be found. The create information was: #{node}." unless node['location']

      create_location = node['location']

      create_location.scan('%s').length == 1 or raise ConfigurationError, "The silo pool at #{services_location} is misconfigured; it returns the bad URL template '#{create_location}' - we expected exactly one '%s' in it."

      url = URI.parse(URI.encode(sprintf(create_location, name))) rescue raise(ConfigurationError, "When retreiving service information from the silo pool at #{services_location}, the create link was malformed: #{node['location']}.")

      if basic_auth_username or basic_auth_password
        url.user     = URI.encode basic_auth_username
        url.password = URI.encode basic_auth_password
      end
      return url
    end

    # Return a URL that we can use to get fixity data from the pool: a
    # specific mime-type can be requested (at the time of this
    # writing, deployed silos support text/csv and application/xml).
    # The default mime-type is text/csv.

    def fixity_url mime_type = 'text/csv'
      text = service_document
      parser = XML::Parser.string(text).parse
      if  parser.find('fixity') == 0
        raise ConfigurationError, "When retreiving service information from the silo at #{services_location}, no fixity service was declared. The service document returned was was:\n#{text}."
      end

      parser.find('fixity').each do |node|
        if node['mime_type'] == mime_type
          begin
            url =  URI.parse node['location']
          rescue => e
            raise ConfigurationError, "When retreiving service information from the silo at #{services_location}, the fixity service information did not include a valid location; the fixity information was: #{node}."
          end

          if basic_auth_username or basic_auth_password
            url.user     = URI.encode basic_auth_username
            url.password = URI.encode basic_auth_password
          end
          return url
        end
      end
      raise ConfigurationError, "When retreiving service information from the silo at #{services_location}, no fixity service with mime type #{mime_type} could be found.  The service document returned was was:\n#{text}."
    end

    # Create a new pool based on its services URL and optionally a read preference.

    def self.add services_location, read_preference = nil
      params = { :services_location => services_location }
      params[:read_preference] = read_preference unless read_preference.nil?
      rec = create(params)
      rec.saved? or raise "Can't create new pool record #{services_location}; DB errors: " + rec.errors.full_messages.join('; ')
      return rec
    end

    def self.list_active
      all(:required => true, :order => [ :read_preference.desc ])
    end

    def self.exists? services_location
      not first(:services_location => services_location).nil? 
    end

    def self.lookup services_location
      first(:services_location => services_location)
    end
  end # of Pool


  class Copy
    include DataMapper::Resource
    storage_names[:default] = 'copies'          # don't want dm_copies

    property   :id,               Serial,   :min => 1
    property   :datetime,         DateTime, :index => true, :default => lambda { |resource, property| DateTime.now }
    property   :store_location,   String,   :length => 255, :required => true, :index => true  #, :format => :url

    belongs_to :pool
    belongs_to :package

    validates_uniqueness_of :pool, :scope => :package

    # Careful with the URL returned here; it may have an associated username and password
    # which will print out in the URL.to_s method as http://user:password@example.com/ - you
    # don't want that logged. Use the url.sanitized method in preference to url.to_s.

    def url
      url = URI.parse store_location
      if pool.basic_auth_username or pool.basic_auth_password
        url.user     = URI.encode pool.basic_auth_username
        url.password = URI.encode pool.basic_auth_password
      end
      url
    end
  end # of Copy



end # of Module DataModel
