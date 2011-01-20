require 'store-master/disk-store'
require 'store-master/data-model'
require 'store-master/exceptions'
require 'dm-types'
require 'uri'
require 'net/http'
require 'xml'

# TO DO:  Move everything into DataModel::Package and use those methods....

# Two basic ways to instantiate package objects, which
#
# pkg = Package.lookup(name)
#
# pkg.locations  =>
# pkg.ieid       =>
# pkg.name       =>
#
#
# pkg = Package.store(data, pools, metadata)

module StoreMaster

  # TODO: we're going to completely deprecate this aqnd go straight at the DataModel classes. RSN.

  class Package

    attr_reader   :name
    attr_accessor :dm_record

    # Refactoring in progress - everything being migrated to the  DataModel::Package class

    # Package.new(name) really meant to only be called internally.  Use lookup or create.

    def initialize name
      @name      = name
      @dm_record = nil
      @md5 	 = nil
      @size	 = nil
      @type	 = nil
      @sha1	 = nil
      @etag	 = nil
    end

    def ieid
      @dm_record.ieid
    end

    def md5;          @dm_record.md5;          end
    def md5= datum;   @dm_record.md5 = datum;  end

    def sha1;         @dm_record.sha1;         end
    def sha1= datum;  @dm_record.sha1 = datum; end

    def etag;         @dm_record.etag;         end
    def etag= datum;  @dm_record.etag = datum; end

    def size;         @dm_record.size;         end
    def size= datum;  @dm_record.size = datum; end

    def type;         @dm_record.type;         end
    def type= datum;  @dm_record.type = datum; end

    def locations
      dm_record.locations
    end

    def self.exists? name
      DataModel::Package.exists? name
    end

    def self.names
      DataModel::Package.names
    end

    def self.was_deleted? name
      DataModel::Package.was_deleted? name
    end

    # Find a previously saved package

    def self.lookup name
      pkg = Package.new name
      pkg.dm_record = DataModel::Package.lookup name
      return nil if pkg.dm_record.nil?
      pkg
    end

    def self.store data_io, pools, metadata

      raise "Can't create new package #{name}, it already exists"                   if Package.exists? metadata[:name]
      raise "Can't reuse name #{name}: it has been previously created and deleted"  if Package.was_deleted? metadata[:name]

      pkg = Package.new metadata[:name]

      pkg.dm_record = DataModel::Package.create(:name => metadata[:name], :ieid => metadata[:ieid])

      begin
        pools.each do |pool|
          store_info = pkg.store_copy(data_io, pool.post_url(pkg.name), metadata)

          pkg.dm_record.copies << DataModel::Copy.create(:store_location => store_info['location'], :pool => pool)

          # TODO: Why am I having problems doing the following in store_copy?  I'd like store_copy to return only the location,
          # instead of all this ancilliary crap.

          pkg.md5  = store_info['md5']
          pkg.sha1 = store_info['sha1']
          pkg.type = store_info['type']
          pkg.size = store_info['size'].to_i
          pkg.etag = store_info['etag']
        end

      rescue => e1
        msg = "Failure storing copy of #{pkg.name}: #{e1.message}"
        pkg.locations.each do |loc|
          begin
            pkg.delete_copy(loc)
          rescue => e2
            msg += "; also, failure deleting copy at #{loc}: #{e2.message}"
          end
        end
        raise e1, msg # re-raise error
      end

      if not pkg.dm_record.save
        msg = "DB error recording #{name} - #{pkg.dm_record.errors.full_messages.join('; ')}"
        pkg.locations.each do |loc|
          begin
            pkg.delete_copy(loc)
          rescue => e
            msg += "; also, failure deleting copy at #{loc}: #{e.message}"
          end
        end
        raise DataBaseError, msg
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
    #   rec = DataModel::Package.create
    #
    #   rec.name      = name
    #   rec.ieid      = ieid
    #
    #   rec.save or raise DataBaseError, "Can't save DB record for package #{name} - #{rec.errors.full_messages.join('; ')}"
    #
    #   pkg.dm_record = rec
    #   pkg
    # end

    # delete tries to fail safe here, leaving orphans if necessary

    def delete
      dm_record.extant = false
      raise  DataBaseError, "error deleting #{name} - #{pkg.dm_record.errors.full_messages.join('; ')}" unless dm_record.save

      errors = []
      dm_record.locations.each do |loc|
        begin
          delete_copy(loc)
        rescue => e
          errors.push "failed to delete remote storage at #{loc}: #{e.message}"
        end
      end

      raise DriveByError, errors.join('; ') unless errors.empty?
    end

    def sanitized_location url
      url.password ?  url.to_s.gsub(url.userinfo + '@', '') + ' (using password)' : url.to_s
    end

    def delete_copy url

      http = Net::HTTP.new(url.host, url.port)
      http.open_timeout = 10
      http.read_timeout = 60 * 2  # deletes are relatively fast

      request = Net::HTTP::Delete.new(url.request_uri)
      request.basic_auth(url.user, url.password) if url.user or url.password

      response = http.request(request)
      status = response.code.to_i

      if status >= 300
        err   = "#{response.code} #{response.message} was returned for a failed delete of the package copy at #{sanitized_location(url)}"
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

    def store_copy io, url, metadata

      http = Net::HTTP.new(url.host, url.port)

      http.open_timeout = 10
      http.read_timeout = 60 * 60  # sixty minute timeout for PUTs

      io.rewind if io.respond_to?('rewind')

      request = Net::HTTP::Post.new(url.request_uri)
      request.body_stream = io

      request.initialize_http_header("Content-MD5"    => StoreUtils.md5hex_to_base64(metadata[:md5]),
                                     "Content-Length" => metadata[:size].to_s,
                                     "Content-Type"   => metadata[:type])

      request.basic_auth(url.user, url.password) if url.user or url.password

      response = http.request(request)  # finally.

      status = response.code.to_i
      location = sanitized_location(url)


      if status >= 300
        err   = "#{response.code} #{response.message} was returned for a failed forward of package to #{location}"
        err  += "; message was #{response.body}" if response.body.length > 0
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
        raise "Invalid XML document returned in response to forward of package to #{location}: #{e.message}"
      end

      # check the md5, size, type vs. our request to that returned by remotely created copy.

      raise "Error storing to #{location} - md5 mismatch"   if returned_data["md5"]  != metadata[:md5]
      raise "Error storing to #{location} - size mismatch"  if returned_data["size"] != metadata[:size].to_s
      raise "Error storing to #{location} - type mismatch"  if returned_data["type"] != metadata[:type]

      returned_data
    end

  end # of class Package
end  # of module StoreMaster


# curl -sv -d ieid=E000019QB_BZ81F4  http://store-master.local/reserve/
# curl -sv -X PUT -H "Content-Type: application/x-tar" -H "Content-MD5: `md5-base64 E20080805_AAAAAM`" --upload-file E20080805_AAAAAM http://store-master.local/packages/E000019QB_BZ81F4.003
