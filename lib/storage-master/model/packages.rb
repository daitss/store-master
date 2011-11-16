require 'storage-master/exceptions'
require 'storage-master/model'

module StorageMasterModel

  # The StorageMasterModel::Package class keeps track of what packages we've successfully
  # received and stored to one or more Silo Pools.
  #
  #  It requires a class member to be initialized before use, e.g.
  #
  #    StorageMasterModel::Package.server_location = 'https://storage-master.fda.fcla.edu:70'  
  #
  #  The class method store can then be used to construct a package:
  #
  #    pkg = StorageMasterModel::Package.store(IO, metadata, [ silo_one, silo_two ])
  #
  #  The class method lookup can be used to find an extant package:
  #
  #    pkg = StorageMasterModel::Package.store('E20111201_AAAAZR')
  #

  class Package

    include DataMapper::Resource
    include StorageMaster

    # def self.default_repository_name
    #   :store_master
    # end

    property   :id,         Serial,   :min => 1
    property   :extant,     Boolean,  :default  => true, :index => true
    property   :ieid,       String,   :required => true, :index => true
    property   :name,       String,   :required => true, :index => true      # unique name, used as part of a url

    # many-to-many  relationship - a package can (and should) have copies on several different pools

    has n,      :copies

    validates_uniqueness_of  :name

    attr_accessor :md5, :size, :type, :sha1, :etag   # scratch pad attributes filled in on succesful store

    @@server_location = nil   # the location of the Storage Master service, e.g. http://storage-master.example.com:8080

    def self.server_location= prefix
      @@server_location = prefix.gsub(/:80$/, '')
    end

    def self.server_location
      @@server_location
    end


    # Return the locations of outr package. It's a list URI objects for all of the copies we have, in pool-preference order.
    # There may be username and passwords on a URI object, but the URI#to_s method has been over-ridden so they can't be accidentally
    # printed (use #to_s_with_userinfo for that, defined in model.rb)
    #
    # @return [ARRAY] list of URI objects
    
    def locations
      copies.sort { |a,b| b.pool.read_preference <=> a.pool.read_preference }.map { |copy| copy.url }
    end

    # Return a string that gives the Stoage Master's location of this package.

    def url
      "#{@@server_location || 'http://localhost'}/packages/#{name}"
    end

    # Package.exists? tells us if the package stored with name still
    # exists.  It is not safe to use the name for a package creation,
    # since it may have been created and deleted, and we never allow a
    # name to be reused.
    #
    # @param [String] name, the name of the package, e.g. E20111201_AAAAZR

    def self.exists? name
      not first(:name => name, :extant => true).nil?
    end

    # Package.was_deleted? tells us if a package was created and subsequently deleted.
    #
    # @param [String] name, the name of the package, e.g. E20111201_AAAAZR

    def self.was_deleted? name
      not first(:name => name, :extant => false).nil?
    end

    # Package.was_deleted? tells us if a package was created and subsequently deleted.
    #
    # @param [String] name, the name of the package, e.g. E20111201_AAAAZR
    # @return [StorageMasterModel::Package] the package object, if it still exists

    def self.lookup name
      first(:name => name, :extant => true)
    end


    # Package.search returns a list of packages objects matching a search string.
    #
    # @param [String] name, the partial name of the packages to search for, e.g. 'E2011'
    # @param [Fixnum] limit, optionally, the number of packages to return, defaults to 1
    # @return [Array] a list of the package objects, ordered alphabetically by name

    def self.search name, limit = 1
      first(limit, :name.like => "%#{name}%", :extant => true, :order => [:name.asc ])
    end

    private

    # package_chunks lets us effciently trundle through all of the
    # packages - we have hundreds of thousands of them.

    def self.package_chunks
      offset = 0
      while not (packages  = all(:extant => true, :order => [ :name.asc ] ).slice(offset, 2000)).empty?
        offset += packages.length
        yield packages
      end
    end

    public

    # Package.list yields all of the package objects, one at a time.

    def self.list
      Package.transaction do              # isolation, we don't want updates/deletes to throw package_chunks off.
        package_chunks do |records|
          records.each do |rec|
            yield rec
          end
        end
      end
    end


    # Package.store sends a data stream to multiple silo pools and returns a new package object. In the case
    # of error we clean up as best we can.
    #
    # @param [IO] io, the package contents (usually an opened tarfile)
    # @param [Hash] metadata, metadata for the package contents, including the name, size and md5 checksum of the package
    # @param [ARRAY] pools, a list of Pool objects to which we will store the package
    #
    # @return [StoreMasterModel::Package] the created package on success

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

      Package.transaction do |trans|
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

    # Package.stub is like a /dev/null version of Package.store. It is entirely for test setups
    # where we don't want to create back-end silo pools.

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

    # delete attempts to remove all copies of a package and mark it as deleted.
    #
    # On failure this may leave orphaned packages in remote silo pools. We'll raise an error that
    # will ultimately return a 207 MultiStatus to the Storage Master client.
    #
    # TODO: add diagnostics to returned data from the quiet_delete
    # call and pass them up, if it proves necessary.

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
end # of module StorageMasterModel
