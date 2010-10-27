require 'store/diskstore'
require 'store/dm'
require 'store/exceptions'
require 'dm-types'
require 'uri'
require 'net/http'
require 'xml'

module Store
  class Package

    attr_reader   :name
    attr_accessor :dm_record

    # Package.new(name) should only be called internally

    def initialize name
      @name      = name
      @dm_record = nil
    end

    def self.exists? name
      not DM::Package.first(:name => name, :extant => true).nil?
    end

    # TODO: This next is likely to result in such a long list as to be unusable in practice; need to rethink chunking this up....

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


    def self.create io, metadata, pools

      pkg = Package.new metadata[:name]

      raise "Can't create new package #{name}, it already exists"                   if Package.exists? name
      raise "Can't reuse name #{name}: it has been previously created and deleted"  if Package.was_deleted?(name)

      pkg.dm_record = DM::Package.create

      pkg.dm_record.datetime  = DateTime.now
      pkg.dm_record.ieid      = metadata[:ieid]
      pkg.dm_record.md5       = metadata[:md5]
      pkg.dm_record.name      = metadata[:name]
      pkg.dm_record.size      = metadata[:size]
      pkg.dm_record.type      = metadata[:type]

      locations = []        # TODO: add events here

      begin
        pools.each do |pool|
          loc = pool.put_location.gsub(%r{/+$}, '')  +  '/'  +  pkg.name
          pkg.dm_record.copies << DM::Copy.create(:store_location => loc, :pool => pool.dm_record)

          pkg.put_copy(io, metadata, loc)  # N.B. put_copy adds stuff to metadata
          locations << loc
        end
      rescue => e1
        hell = "Failure making copy of #{pkg.name}: #{e1.message}"
        locations.each do |loc| 
          begin
            delete_copy(loc)
          rescue => e2
            hell += "; failure deleting copy at #{loc}: #{e2.message}"
          end
        end
        raise hell
      end

      pkg.dm_record.sha1  = metadata[:sha1]  # pick up data that put_copy added

      if not pkg.dm_record.save
        cane = "DB error recording #{name} - #{pkg.dm_record.errors.map { |e| e.to_s }.join('; ')}"
        locations.each do |loc| 
          begin
            pkg.delete_copy(loc)
          rescue => e2
            cane += "; failure deleting copy at #{loc}: #{e2.message}"
          end
        end
        raise cane
      end

      pkg
    end

    # Create a new package record from our temporary storage.  It does not have events or copies associated with it.
    #
    # Might come in useful again...
    #
    # def self.new_from_diskstore ieid, name, diskstore
    #   raise DiskStoreError, "Can't create new package #{name}, it already exists"            if Package.exists? name
    #   raise DiskStoreError, "Can't create new package #{name} from diskstore #{diskstore}"   unless diskstore.exists? name
    #   raise DiskStoreError, "Can't reuse name #{name}: it has been previously created and deleted"  if Package.was_deleted?(name)
    #
    #   pkg = Package.new name
    #   rec = DM::Package.create
    #
    #   rec.name      = name
    #   rec.ieid      = ieid
    #   rec.md5       = diskstore.md5(name)
    #   rec.sha1      = diskstore.sha1(name)
    #   rec.type      = diskstore.type(name)
    #   rec.size      = diskstore.size(name)
    #   rec.datetime  = diskstore.datetime(name)
    #
    #   rec.save or raise DataBaseError, "Can't save DB record for package #{name} - #{rec.errors.map { |e| e.to_s }.join('; ')}"
    #
    #   pkg.dm_record = rec
    #   pkg
    # end


    # Get basic DB data about a package
         
    def datetime; dm_record.datetime;  end
    def ieid;     dm_record.ieid;      end
    def md5;      dm_record.md5;       end
    def sha1;     dm_record.sha1;      end
    def size;     dm_record.size;      end
    def type;     dm_record.type;      end
    
    def locations
      dm_record.copies.map { |cp| cp.store_location }  # TODO: check that if there are no copies, it is [] and not nil here
    end


    # delete tries to fail safe here, leaving orphans if necessary
      
    def delete
      dm_record.extant = false
      raise "DB error deleting #{name} - #{pkg.dm_record.errors.map { |e| e.to_s }.join('; ')}" unless dm_record.save

      errors = []
      locations.each do |loc| 
        begin
          delete_copy(loc)
        rescue => e
          errors.push "failed to delete remote storage at #{loc}: #{e.message}"
        end
      end
      
      raise DriveByError, errors.join('; ') unless errors.empty?
    end



    def delete_copy remote_location

      uri = URI.parse(remote_location)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 60 * 30  # thirty minute timeout for delete (since PUTs can block us from a full silo for this long!)

      forwarded_request = Net::HTTP::Delete.new(uri.request_uri)
      response = http.request(forwarded_request)
      status = response.code.to_i

      if status >= 300
        err   = "#{response.code} #{response.message} was returned for a failed delete of the package copy at #{remote_location}"
        err  += "; #{response.body}" if response.body.length > 0
        if status >= 500   
          raise err
        elsif status >= 400 
          raise Silo400Error, err
        elsif status >= 300    
          raise err
        end          
      end
    end

    def put_copy io, metadata, remote_location

      uri = URI.parse(remote_location)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 60 * 30  # thirty minute timeout for PUTs

      io.rewind if io.respond_to?('rewind')
    
      forwarded_request = Net::HTTP::Put.new(uri.request_uri)
      forwarded_request.body_stream = io
      forwarded_request.initialize_http_header({ "Content-MD5"    => StoreUtils.md5hex_to_base64(metadata[:md5]), "Content-Length" => metadata[:size], "Content-Type"   => metadata[:type], })

      response = http.request(forwarded_request)

      if response.code.to_i >= 300
        err   = "#{response.code} #{response.message} was returned for a failed forward of package to #{remote_location}"
        err  += "; body text: #{response.body}" if response.body.length > 0
        if status >= 500   
          raise err
        elsif status >= 400 
          raise Silo400Error, err
        elsif status >= 300    
          raise err
        end          
      end
    
      # Example XML document returned from PUT:    <?xml version="1.0" encoding="UTF-8"?>
      #                                            <created type="application/x-tar" 
      #                                                     time="2010-10-21T10:29:19-04:00" 
      #                                                     sha1="ac4d813081e066422bc1dc7e7997ace1bfb858b2" 
      #                                                     etag="a3f07bc57127112f2a2c40d026b1abe1" 
      #                                                     md5="32e2ce3af2f98a115e121285d042c9bd" 
      #                                                     size="6031360" 
      #                                                     location="http://storage.local/b/data/E20101021_LJLAMU.001" 
      #                                                     name="E20101021_LJLAMU.001"/>


      returned_data = {}

      begin 
        parser = XML::Parser.string(response.body).parse
        node   = parser.find('/created')[0]
        node.each_attr { |attr| returned_data[attr.name] = attr.value }
      rescue => e
        raise "Invalid XML document returned in response to forward of package to #{remote_location}: #{e.message}"
      end

      # check the md5, size, type vs. our request to that returned by remotely created copy.

      raise "Error storing to #{remote_location} - md5 mismatch"   if returned_data["md5"]  != metadata[:md5]
      raise "Error storing to #{remote_location} - size mismatch"  if returned_data["size"] != metadata[:size]
      raise "Error storing to #{remote_location} - type mismatch"  if returned_data["type"] != metadata[:type]

      metadata[:etag]     = returned_data["etag"]
      metadata[:location] = returned_data["location"]   # the location it was actually store to
      metadata[:sha1]     = returned_data["sha1"]
    end



  end # of class Package
end  # of module Store
