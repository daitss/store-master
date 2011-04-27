require 'store-master/exceptions'
require 'store-master/model'

module StoreMasterModel

  class Pool
    include DataMapper::Resource
    include StoreMaster

    def self.default_repository_name
      :store_master
    end

    property   :id,                   Serial,   :min => 1
    property   :required,             Boolean,  :required => true, :default => true
    property   :services_location,    String,   :length => 255, :required => true
    property   :read_preference,      Integer,  :default  => 0
    property   :basic_auth_username,  String
    property   :basic_auth_password,  String   # note that it is an error if exactly one of basic_auth_xxx is NULL;
                                               # it should be the empty string in that case (need a validator?)

    has n, :copies

    validates_uniqueness_of :services_location

    def assign field, value
      send field.to_s + '=', value
      save or raise "Can't assign the pool #{self.inspect} property #{:field} to value #{value.inspect}"
    end

    attr_accessor :name

    def name 
      @name or @name = URI.parse(services_location).host
    end

    # We have a protocol that silo pools must follow: they must return a service
    # document (XML) that describes where we can locate essential silo services.
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
      url = URI.parse(services_location) rescue raise(ConfigurationError, "The silo services URL #{services_location} doesn't appear to be a valid URL")

      begin # go get information from the silo services document to determine the URLs for the sub services we'll need

        request = Net::HTTP::Get.new(url.path)
        request.basic_auth(basic_auth_username, basic_auth_password) if basic_auth_username or basic_auth_password
        response = Net::HTTP.new(url.host, url.port).start do |http|
          http.open_timeout = 60 * 15
          http.read_timeout = 60 * 15
          http.request(request)
        end

      rescue => e
        raise SiloUnreachable, "Couldn't contact the silo service at URL #{services_location}: #{e.message}"

      else
        raise SiloStoreError, "Bad response when contacting the silo at #{url}, response was #{response.code} #{response.message}." unless response.code == '200'
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


end
