require 'storage-master/exceptions'
require 'storage-master/model'

module StorageMasterModel

  class Copy
    include DataMapper::Resource
    include StorageMaster

    # def self.default_repository_name
    #   :store_master
    # end

    property   :id,               Serial,   :min => 1
    property   :datetime,         DateTime, :index => true, :default => lambda { |resource, property| DateTime.now }
    property   :store_location,   String,   :length => 255, :required => true, :index => true

    belongs_to :pool
    belongs_to :package

    validates_uniqueness_of :pool, :scope => :package

    attr_accessor :md5, :size, :type, :sha1, :etag   # scratch pad attributes filled in on succesful store

    # Note: storage-master/model.rb redefines the print method for URI so that
    # username/password credentials won't be exposed.

    def url
      url = URI.parse store_location
      if pool.basic_auth_username or pool.basic_auth_password
        url.user     = URI.encode pool.basic_auth_username
        url.password = URI.encode pool.basic_auth_password
      end
      url
    end

    # Delete the resource at silo_resource, a URI object, with no possibilitiy of raising an exception.
    # Returns true on success, false on failure.

    def quiet_delete

      silo_resource = self.url

      http = Net::HTTP.new(silo_resource.host, silo_resource.port)
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Delete.new(silo_resource.request_uri)
      request.basic_auth(silo_resource.user, silo_resource.password) if silo_resource.user or silo_resource.password

      response = http.request(request)
      status = response.code.to_i

      return (status == 404 or status == 410 or (status >= 200 and status < 300))

    rescue Exception => e
      return false
    end


    def self.store io, package, pool
      post_address = pool.post_url(package.name)

      http = Net::HTTP.new(post_address.host, post_address.port)
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      request = Net::HTTP::Post.new(post_address.request_uri)
      io.rewind if io.respond_to?('rewind')
      request.body_stream = io
      request.initialize_http_header("Content-MD5" => StoreUtils.md5hex_to_base64(package.md5), "Content-Length" => package.size.to_s, "Content-Type" => package.type)
      request.basic_auth(post_address.user, post_address.password) if post_address.user or post_address.password
      response = http.request(request)
      status = response.code.to_i

      if status < 200 or status >= 300
        message =   "Store of package #{package.name} to #{post_address} failed with status #{response.code} - #{response.message}"
        message +=  "; response from server was: #{response.body.strip}" if response.body and not response.body.strip.empty?

        raise SiloStoreError, message
      end

      # Example XML document returned from a successful POST to a silo, giving details about the resource
      #
      #   <?xml version="1.0" encoding="UTF-8"?>
      #   <created type="application/x-tar"
      #            time="2010-10-21T10:29:19-04:00"
      #            sha1="ac4d813081e066422bc1dc7e7997ace1bfb858b2"
      #            etag="a3f07bc57127112f2a2c40d026b1abe1"
      #            md5="32e2ce3af2f98a115e121285d042c9bd"
      #            size="6031360"
      #            location="http://silo.example.com/001/data/E20101021_LJLAMU.001"
      #            name="E20101021_LJLAMU.001"/>

      info = {}

      parser = LibXML::XML::Parser.string(response.body).parse
      parser.find('/created')[0].each_attr { |attr| info[attr.name] = attr.value }

      [ 'location', 'time', 'sha1', 'md5', 'size', 'etag' ].each do |required|
        unless info[required]
          raise SiloStoreError, "Store of package #{package.name} to #{post_address} failed to return the #{required} information"
        end
      end

      cpy = new(:pool => pool, :store_location => info['location'], :datetime => DateTime.parse(info['time']))

      cpy.etag = info['etag']
      cpy.md5  = info['md5']
      cpy.sha1 = info['sha1']
      cpy.size = info['size'].to_i
      cpy.type = info['type']

    rescue SiloStoreError => e
      raise

    rescue Exception => e
      raise SiloStoreError, "Store of package #{package.name} to #{post_address} failed with exception #{e.class} - #{e.message}"
    else
      return cpy
    end

  end

end # of class Copy
