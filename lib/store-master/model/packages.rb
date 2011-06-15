require 'store-master/exceptions'
require 'store-master/model'

module StoreMasterModel

  class Package

    include DataMapper::Resource
    include StoreMaster

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

    @@server_location = nil

    # e.g. http://store-master.example.com:8080 - we're required to set this up initially

    def self.server_location= prefix
      @@server_location = prefix.gsub(/:80$/, '')
    end

    def self.server_location
      @@server_location
    end


    # return URI objects for all of the copies we have, in pool-preference order

    def locations
      copies.sort { |a,b| b.pool.read_preference <=> a.pool.read_preference }.map { |copy| copy.url }
    end

    def url
      "#{@@server_location || 'http://localhost'}/packages/#{name}"
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

    def self.search name, limit = 1
      first(limit, :name.like => "%#{name}%", :extant => true, :order => [:name.asc ])
    end


    # TODO: now that names are not sequential we may have a timing issue:
    # When a chunk is being processed, new random ids may be inserted
    # anywhere.  We don't have the capability to order by  time here.

    def self.package_chunks
      offset = 0
      while not (packages  = all(:extant => true, :order => [ :name.asc ] ).slice(offset, 2000)).empty?
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

    # Sort of like /dev/null, for the case we have no underlying silos.
    # Entirely for testing.

    def self.stub io, metadata
      required_metadata = [ :name, :ieid, :md5, :size, :type ]
      missing_metadata  = required_metadata - (required_metadata & metadata.keys)

      raise SiloStoreError, "Can't store data package, missing information for #{missing_metadata.join(', ')}"         unless missing_metadata.empty?

      raise PackageUsed, "Can't store package #{metadata[:name]}, it already exists"                                    if exists? metadata[:name]
      raise PackageUsed, "Can't store package using name #{metadata[:name]}, it's been previously created and deleted"  if was_deleted? metadata[:name]

      pkg = new(:name => metadata[:name], :ieid => metadata[:ieid])

      io.rewind if io.respond_to?('rewind')
      sha1 = Digest::SHA1.new
      md5  = Digest::MD5.new
      size = 0
      while buff = io.read(1_048_576)
        size += buff.length
        sha1 << buff
        md5  << buff
      end

      msg = "Error receiving package #{pkg.name} to stub service:"

      pkg.type = metadata[:type]
      pkg.md5  = md5.hexdigest
      pkg.size = size
      pkg.sha1 = sha1.hexdigest

      raise SiloStoreError, "#{msg} md5 mismatch (expected #{metadata[:md5]},  got #{pkg.md5})"      unless pkg.md5  == metadata[:md5]
      raise SiloStoreError, "#{msg} size mismatch (expected #{metadata[:size]}, got #{pkg.size})"    unless pkg.size == metadata[:size].to_i

      if not pkg.save
        raise "Database error saving package #{pkg.name}: " + pkg.errors.full_messages.join(', ')
      end

      return pkg
    end


    # Store a received data stream to multiple silo pools.

    def self.store io, metadata, pools
      copies = []

      required_metadata = [ :name, :ieid, :md5, :size, :type ]
      missing_metadata  = required_metadata - (required_metadata & metadata.keys)

      raise SiloStoreError, "Can't store data package, missing information for #{missing_metadata.join(', ')}"         unless missing_metadata.empty?

      raise PackageUsed, "Can't store package #{metadata[:name]}, it already exists"                                    if exists? metadata[:name]
      raise PackageUsed, "Can't store package using name #{metadata[:name]}, it's been previously created and deleted"  if was_deleted? metadata[:name]

      pkg = new(:name => metadata[:name], :ieid => metadata[:ieid])

      pkg.md5  = metadata[:md5]
      pkg.size = metadata[:size].to_i
      pkg.type = metadata[:type]

      pkg.transaction do |trans|
        begin
          pools.each do |pool|
            cpy = Copy.store(io, pkg, pool)
            copies.push cpy

            msg = "Error copying package #{pkg.name} to #{cpy.store_location}:"

            raise SiloStoreError, "#{msg} md5 mismatch (we have #{pkg.md5}, got back #{cpy.md5})"         unless pkg.md5  == cpy.md5
            raise SiloStoreError, "#{msg} size mismatch (we have #{pkg.size}, got back #{cpy.size})"      unless pkg.size == cpy.size
            raise SiloStoreError, "#{msg} mime-type mismatch (we have #{pkg.type}, got back #{cpy.type})" unless pkg.type == cpy.type

            pkg.sha1 = cpy.sha1
          end

          copies.each { |cp| pkg.copies << cp }

          if not pkg.save
            errors = []
            errors.push pkg.errors.full_messages.join(', ')
            pkg.copies { |cp|  errors.push  cp.errors.full_messages.join(', ')  }
            raise "Database error saving package #{pkg.name}: " + errors.join('; ')
          end

        rescue => e
          trans.rollback
          raise
        end
      end


    rescue => e
      copies.each { |cp| cp.quiet_delete }
      raise
    else
      pkg
    end

    # On failure may leave orphaned packages in remote silo pools.  We'll log a 207 MultiStatus on partial error,
    # and have to dig out what happened on the remote end, if possible.  TODO: add diagnostics to quiet_delete
    # and pass them up, if it proves necessary.

    def delete
      self.extant = false

      raise SiloStoreError, "Error saving package #{name} to database: #{errors.full_messages.join(', ')}" unless self.save

      probs = []
      copies.each do |copy|
        probs.push copy.store_location unless copy.quiet_delete
      end

      if not probs.empty?
        word = (probs.length == 1 ? 'entry' : 'entries')
        raise PartialDelete, "For package #{name}, failed to delete silo #{word} #{probs.join(', ')}"
      end
    end

  end # of class Package
end # of module StoreMasterModel
