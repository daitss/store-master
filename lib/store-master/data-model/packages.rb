module DataModel

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


end
