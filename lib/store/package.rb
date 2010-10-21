require 'store/diskstore'
require 'store/dm'
require 'store/exceptions'
require 'dm-types'

# For StoreMaster, a package takes one of two forms:

# A package name (IEID) - a string; and  local storage - a DiskStore.
# A package name, and remote silos where copies are storem

module Store
  class Package

    def self.exists? name
      not DM::Package.first(:name => name, :extant => true).nil?
    end

    attr_reader :name
    attr_accessor :dm_record

    # this constructor is not really meant to be used externally!

    def initialize name
      @name      = name
      @dm_record = nil
    end

    # Create a new package record from our temporary storage.  It does not have events or copies associated with it.

    def self.new_from_diskstore ieid, name, diskstore
      raise DiskStoreError, "Can't create new package #{name}, it already exists"            if Package.exists? name
      raise DiskStoreError, "Can't create new package #{name} from diskstore #{diskstore}"   unless diskstore.exists? name
      raise DiskStoreError, "Can't reuse name #{name}: it has been previously created and deleted"  if Package.was_deleted?(name)

      pkg = Package.new name
      rec = DM::Package.create

      rec.name      = name
      rec.ieid      = ieid
      rec.md5       = diskstore.md5(name)
      rec.sha1      = diskstore.sha1(name)
      rec.type      = diskstore.type(name)
      rec.size      = diskstore.size(name)
      rec.datetime  = diskstore.datetime(name)

      rec.save or raise DataBaseError, "Can't save DB record for package #{name} - #{rec.errors.map { |e| e.to_s }.join('; ')}"

      pkg.dm_record = rec
      pkg
    end

    # def self.find_in_cloud name
    #   raise PackageMissingError, "Can't find package #{name}, it already exists" unless Package.exists? name
    # end

    def self.names
      DM::Package.all(:extant => true, :order => [ :name.asc ] ).map { |rec| rec.name }
    end

    # Find a previously saved package

    def self.lookup name
      pkg = Package.new name
      pkg.dm_record = DM::Package.first(:name => name, :extant => true)
      pkg.dm_record.nil? ? nil : pkg
    end

    def self.was_deleted? name
      not DM::Package.first(:name => name, :extant => false).nil?
    end

    # urg.  remove this:

    def self.delete name
      pkg = Package.lookup(name) or
        raise "Can't delete #{name} - there is no such package"
      pkg.dm_record.extant = false
      pkg.dm_record.save or
        raise DataBaseError, "Can't save DB record for deletion of package #{name}"
    end

    # Get basic DB data about a package
         
    def datetime; dm_record.datetime;  end
    def ieid;     dm_record.ieid;      end
    def md5;      dm_record.md5;       end
    def sha1;     dm_record.sha1;      end
    def size;     dm_record.size;      end
    def type;     dm_record.type;      end


    def delete      
      # TODO: run down silos first

      dm_record.delete
      dm_record.save or
        raise DataBaseError, "Can't save DB record for update of package #{name}"      
    end

    # Save our package to a remote location.
    
    def put data, pool
  
      uri  = URI.parse(pool.put_location)
      http = Net::HTTP.new(uri.host, uri.port)

      http.open_timeout = 5
      http.read_timeout = 60 * 30  # thirty minute timeout for PUTs

      # TODO: request.basic_auth("silo-writer", "top secret")

      request = Net::HTTP::Put.new(uri.request_uri)  # testing with netcat -l -p 6969

      if data.respond_to? :read
        request.body_stream = data
      elsedata.respond_to? :to_str
        request.body = data
      end

      request.initialize_http_header({ 
                                       "Content-MD5"    => StoreUtils.md5hex_to_base64(md5), 
                                       "Content-Length" => size.to_s, 
                                       "Content-Type"   => type,
                                     })
  
      response = http.request(request)

      if response.code.to_i >= 300
        err   = "#{response.code} #{response.message} was returned for failed package PUT request to #{put_location}"
        errr += "; body text: #{response.body}" if response.body.length > 0
        raise err
      end

      if response['content-type'] != 'application/xml'
        raise "Media type #{response['content-type']} returned for package PUT request to #{put_location}, expected applicatio/xml"
      end

      # Sample XML document returned from PUT
      #
      #  <?xml version="1.0" encoding="UTF-8"?>
      #  <created type="application/x-tar" 
      #           time="2010-10-21T10:29:19-04:00" 
      #           sha1="ac4d813081e066422bc1dc7e7997ace1bfb858b2" 
      #           etag="a3f07bc57127112f2a2c40d026b1abe1" 
      #           md5="32e2ce3af2f98a115e121285d042c9bd" 
      #           size="6031360" 
      #           location="http://storage.local/b/data/E20101021_LJLAMU" 
      #           name="E20101021_LJLAMU"/>

      # TODO: we should probably double check md5, sum, etc.

      begin 
        parser   = XML::Parser.string(response.body).parse
        location =  parser.find('/created')[0]['location']
      rescue => e
        raise "Can't find the package location in the XML document returned from a successful package PUT request to #{put_location}: #{e.message}"
      end

      ### TODO: events

      @dm_record.copies << DM::Copy.create(:store_location => location, :pool => pool.datamapper_record)
      @dm_record.save

      


    end


  end # of class Package
end  # of module Store


