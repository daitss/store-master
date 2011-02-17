module StoreMasterModel

  class Package

    include DataMapper::Resource

    def self.default_repository_name
      :store_master
    end

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

    def self.package_chunks
      offset = 0
      while not (packages  = all(:extant => true, :order => [ :name.asc ] ).slice(offset, 1000)).empty?
        offset += packages.length
        yield packages
      end
    end

    def self.list
      package_chunks do |records|
        records.each do |rec|
          yield rec
        end
      end
    end

    ### TODO

    # def safe_delete loc
    #   delete_copy loc
    # rescue => e
    #   "failed in cleanup when trying to delete copy at #{loc}: #{e.message}"
    # end


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

      # TODO: exception wrapper to DRY

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

    # on failure may leave orphan

    def delete
      self.extant = false
      raise  DataBaseError, "error deleting #{self.name} - #{self.errors.full_messages.join('; ')}" unless self.save
      errs = []
      locations.each do |loc|
        begin
          delete_copy(loc)
        rescue => e
          errs.push "failed to delete storage at #{loc}: #{e.message}"
        end
      end
      raise DriveByError, errs.join('; ') unless errs.empty?
    end


    def store_copy io, posting_url, metadata

      # Note: posting_url may have credentials, but URI#to_s has been redefined in data-model.rb to sanitize the printed output

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

      raise(SiloStoreError, "#{response.code} #{response.message} - when saving package #{metadata[:name]} to silo #{posting_url} - #{response.body}") if status >= 300

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
        raise SiloStoreError, "Invalid XML document returned when saving package to #{posting_url}: #{e.message}"
      end

      # check the md5, size, type vs. our request to that returned by remotely created copy.

      raise SiloStoreError, "Error storing to #{posting_url} - md5 mismatch"   if returned_data["md5"]  != metadata[:md5]
      raise SiloStoreError, "Error storing to #{posting_url} - size mismatch"  if returned_data["size"] != metadata[:size].to_s
      raise SiloStoreError, "Error storing to #{posting_url} - type mismatch"  if returned_data["type"] != metadata[:type]

      self.md5  = returned_data['md5']
      self.sha1 = returned_data['sha1']
      self.type = returned_data['type']
      self.size = returned_data['size'].to_i
      self.etag = returned_data['etag']

      returned_data['location']
    end


    # TODO: raise an exception for 'come back later' if remote service too busy and we get a timeout...

    def delete_copy silo_resource

      http = Net::HTTP.new(silo_resource.host, silo_resource.port) 
      http.open_timeout = 30
      http.read_timeout = 60 * 5  # deletes can take some time for large packages on active filesystems

      request = Net::HTTP::Delete.new(silo_resource.request_uri)
      request.basic_auth(silo_resource.user, silo_resource.password) if silo_resource.user or silo_resource.password

      response = http.request(request)
      status = response.code.to_i

      raise SiloStoreError, "#{response.code} #{response.message} was returned for a failed delete of the package copy at #{silo_resource} - #{response.body}" if status >= 300
    end
  end # of class Package
end # of module StoreMasterModel
