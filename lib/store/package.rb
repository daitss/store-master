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

    # Create a new package record from our temporary storage; it's not recorded, however,
    # until it is correctly stored to a silo

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

    def put *silos
    end

    # here we delete the original, and update the new one

    def update *new_silos
      delete
      put *new_silos
      dm_record.silos.push *new_silos
      dm_record.save or
        raise DataBaseError, "Can't save DB record for update of package #{name}"
    end

    def delete      
      # TODO: run down silos
      dm_record.delete
      dm_record.save or
        raise DataBaseError, "Can't save DB record for update of package #{name}"      
    end


    def fixity silo, checksums
    end


      


    # def saved! *silos
    #   dm_record.save or
    #     raise DataBaseError, "Can't save DB record for package #{name}"
    # end

  end # of class Package
end  # of module Store


