require 'storage-master/exceptions'
require 'storage-master/model'

module StorageMasterModel

  # The StorageMasterModel::Pool class encapsulates the information about a Silo Pool.
  # A Package object has one or more Copy objects, each of which are associated with
  # exactly one Pool.
  #
  # The pools table includes the following columns of note:
  #
  #  * required            - a boolean telling us whether we *may* use this silo pool (TODO: misnomer now)
  #  * read_preference     - an integer giving a preference for sorting the list of Copy objects for a Package object, larger numbers favored
  #  * services_location   - a URL (e.g. http://silos.darchive.fcla.edu:70/services) where we can information about the silo pool
  #  * basic_auth_password - the password in clear text for accessing the pool
  #  * basic_auth_username - the username for accessing the pool
  #
  # If basic_auth_username is present then basic_auth_password must be,
  # and vice versa. When both are present, we'll use basic
  # authentication for storing to the silo pool.  Use SSL, Luke.
  #
  # A GET to the services_location will return an XML document such as
  #
  #   <?xml version="1.0" encoding="UTF-8"?>
  #   <services version="1.1.4">
  #     <create method="post" location="http://silos.darchive.fcla.edu:70/create/%s"/>
  #     <fixity method="get" mime_type="text/csv" location="http://silos.darchive.fcla.edu:70/fixity.csv"/>
  #     <fixity method="get" mime_type="application/xml" location="http://silos.darchive.fcla.edu:70/fixity.xml"/>
  #     ...
  #     <partition_fixity method="get" mime_type="application/xml" localtion="http://silos.darchive.fcla.edu:70/001/fixity/"/>
  #     <partition_fixity method="get" mime_type="application/xml" localtion="http://silos.darchive.fcla.edu:70/002/fixity/"/>
  #     ...
  #     <store method="put" location="http://silos.darchive.fcla.edu:70/001/data/%s"/>
  #     <store method="put" location="http://silos.darchive.fcla.edu:70/002/data/%s"/>
  #     <store method="put" location="http://silos.darchive.fcla.edu:70/003/data/%s"/>
  #     ...
  #     <retrieve method="get" location="http://silos.darchive.fcla.edu:70/001/data/%s"/>
  #     <retrieve method="get" location="http://silos.darchive.fcla.edu:70/002/data/%s"/>
  #     <retrieve method="get" location="http://silos.darchive.fcla.edu:70/003/data/%s"/>
  #     ...
  #   </services>
  #
  # For our purposes here, only the create and fixity elements of this document is of importance.

  class Pool
    include DataMapper::Resource
    include StorageMaster

    # def self.default_repository_name
    #   :store_master
    # end

    property   :id,                   Serial,   :min => 1
    property   :required,             Boolean,  :required => true, :default => true
    property   :services_location,    String,   :length => 255, :required => true
    property   :read_preference,      Integer,  :default  => 0
    property   :basic_auth_username,  String
    property   :basic_auth_password,  String   # note that it is an error if exactly one of basic_auth_xxx is NULL;
                                               # it should be the empty string in that case

    has n, :copies

    validates_uniqueness_of :services_location

    # assign updates our datamapper object and immediately saves or raises an error.
    #
    # @param [String] field, a column name
    # @param [Object] value, the appropriate value and type for the column

    def assign field, value
      send field.to_s + '=', value
      save or raise "Can't assign the pool #{self.inspect} property #{:field} to value #{value.inspect}"
    end

    attr_accessor :name

    # name returns the hostname of this pool 
    #
    # @return [String] the hostname of this pool server

    def name
      @name or @name = URI.parse(services_location).host
    rescue => e
      raise ConfigurationError, "The silo pool services_location '#{services_location}' was not recognized as a valid URL: #{e.class} #{e.message}"
    end

    # server_url 
    #
    # @return [String] the base URL of this pool server, e.g. http://silo-pool.dev:70/

    def server_url
      u = URI.parse(services_location)
      u.scheme + "://#{u.host}" + (u.port == 80 ? "/" : ":#{u.port}/")
    rescue => e
      raise ConfigurationError, "The silo pool services_location '#{services_location}' was not recognized as a valid URL: #{e.class} #{e.message}"
    end
    
    # service_document returns an XML document from the silo pool service, which 
    # contains information about how to store packages to it.
    #
    # Here's an example document:
    #
    #  <?xml version="1.0" encoding="UTF-8"?>
    #  <services version="0.0.1">
    #    <create method="post" location="http://pool-one.example.com/create/%s"/>
    #    <fixity mime_type="text/csv" method="get" location="http://pool-one.example.com/fixity.csv"/>
    #    <fixity mime_type="application/xml" method="get" location="http://pool-one.example.com/fixity.xml"/>
    #  </services>
    #
    # We require one create service that specifies a URL template (it
    # has a slot "%s" for a name) and when we POST data to that
    # filled-in URL we'll produce a new resource; the document
    # returned from the POST will tell us where the resource has been
    # place.
    #
    # We also have one or more URLs that describe where we can
    # requester fixity data from; the MIME type of the returned data
    # is provided.
    #
    # TODO: this is not the best way to do this: we should have the
    # services_location return a media-type specific to our needs, in
    # line with best HATEOS principles.
    #
    # @return [String] the XML document text.

    def service_document
      url = URI.parse(services_location) rescue raise("The silo pool services_location '#{services_location}' was not recognized as a valid URL: #{e.class} #{e.message}")

      begin # go get information from the silo services document to determine the URLs for the sub services we'll need

        request = Net::HTTP::Get.new(url.path)
        request.basic_auth(basic_auth_username, basic_auth_password) if basic_auth_username or basic_auth_password
        response = Net::HTTP.new(url.host, url.port).start do |http|
          http.open_timeout = OPEN_TIMEOUT
          http.read_timeout = READ_TIMEOUT
          http.request(request)
        end

      rescue Exception => e
        raise SiloUnreachable, "Couldn't contact the silo service at URL #{services_location}: #{e.class} - #{e.message}"

      else
        raise SiloStoreError, "Bad response when contacting the silo at #{url}, response was #{response.code} #{response.message}." unless response.code == '200'
        return response.body
      end
    end

    # post_url, given a package name, returns a URL on this silo pool
    # to which we can post package data to be saved.
    #
    # @param [String] name, the name of the package to create
    # @return [URI] the POST URL to which we can save the package.

    def post_url name
      text = service_document

      parser = LibXML::XML::Parser.string(text).parse
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

    # fixity_url returns a URL that we can use to GET fixity data from the pool.
    # Silo pools currently support CSV and XML listings of fixity data.
    #
    # @param [String] mime_type, an optional MIME type
    # @return [URI] the location for the GET request

    def fixity_url(mime_type = 'text/csv')
      text = service_document
      parser = LibXML::XML::Parser.string(text).parse
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

    # Pool.add creates a new pool based on its services URL and optionally a read preference.
    # The higher the preference, the more it's preferred.
    #
    # @param [String] services_location, the entry URL for this pool
    # @param [Fixnum] read_preference, optional, defaults to 0
    # @return [Pool] the created pool

    def self.add services_location, read_preference = nil
      params = { :services_location => services_location }
      params[:read_preference] = read_preference unless read_preference.nil?
      rec = create(params)
      rec.saved? or raise "Can't create new pool record #{services_location}; DB errors: " + rec.errors.full_messages.join('; ')
      return rec
    end

    # Pool.list_active 
    #
    # @return [Array] returns a list of all active Pools

    def self.list_active
      all(:required => true, :order => [ :read_preference.desc ])
    end

    # Pool.list_all
    #
    # @return [Array] returns a list of all Pools, active or not

    def self.list_all
      all(:order => [ :read_preference.desc ])
    end

    # Pool.exists?
    #
    # @param [String] services_location, the URL entry point to the service
    # @return [Boolean] whether it exists

    def self.exists? services_location
      not first(:services_location => services_location).nil?
    end

    # Pool.lookup returns a Pool based on its services_location
    #
    # @param [String] services_location, the URL entry point to the service
    # @return [Pool] the Pool object found or nil

    def self.lookup services_location
      first(:services_location => services_location)
    end

  end # of class Pool
end # of module StorageMasterModel
