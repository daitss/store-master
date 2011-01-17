require 'digest/md5'
require 'fileutils'
require 'find'
require 'stringio'
require 'timeout'
require 'time'
require 'store-master/utils'
require 'store-master/exceptions'

# TODO: get the lock file out of the DiskStore - need a /var/run/silos directory, or something....

module StoreMaster

  class DiskStore
    include Enumerable

    attr_reader :filesystem

    RESTRICTIVE_FILE_PERMISSIONS      = 0444
    RESTRICTIVE_DIRECTORY_PERMISSIONS = 0555
    PERMISSIVE_DIRECTORY_PERMISSIONS  = 0755

    MAX_NAME_LENGTH = 512

    LOCK_FILENAME = ".lock"

    IO_BUFFER_SIZE        = 1024 ** 2        # buffer size in bytes for reading/writing
    LOCKFILE_GRAB_TIMEOUT = 60 * 10          # seconds to wait on a lock file before we throw an error
    HEADROOM              = 50 * 1024 * 1024 # we have to have this many bytes free to perfom a PUT

    def initialize(storage_directory_root)

      unless File.directory? storage_directory_root
        raise ConfigurationError, "File path '#{storage_directory_root}' is not a directory."
      end
      unless File.readable? storage_directory_root
        raise ConfigurationError, "File path '#{storage_directory_root}' is not readable."
      end
      unless File.writable? storage_directory_root
        raise ConfigurationError, "File path '#{storage_directory_root}' is not writable."
      end
      @filesystem =  storage_directory_root.gsub(%r{/+$}, '')
    end

    def to_s
      "#<DiskStorage: #{self.filesystem}>"
    end

    # Returns true if a data identified by name is in the silo.
    # Warning: this is a read locked method, do not call when the object is write locked.

    def exists?(name)
      read_lock(name) do
        File.directory? path(name) and
          File.exists? data_path(name) and
          File.exists? datetime_path(name) and
          File.exists? md5_path(name) and
          File.exists? name_path(name) and
          File.exists? type_path(name)                  ## TODO: add sh1 here when we've got everything updated (maybe)
      end
    end

    # Put data identified by name in the silo.  Normally data will be some kind of IO object,
    # but strings (or anything with a to_s method) will work fine.

    def put(name, data, type)


      if File.exists? path(name)
        raise DiskStoreResourceExists, "#{self} error - resource #{name} already exists. You must delete this resource first."
      end

      if (name.length > MAX_NAME_LENGTH or invalid_name? name)
        raise BadName, "#{self} error - invalid name for resource '#{name}'."
      end

      # check for size, if we can

      disk_free = StoreUtils.disk_free(filesystem)

      data = StringIO.new(data.to_s) unless data.respond_to? "read"

      if data.respond_to? 'stat'
        if data.stat.size > disk_free  - HEADROOM
          raise DiskStoreError, "#{self} can't save #{name} - #{data.stat.size} bytes data > #{disk_free} free disk bytes plus #{HEADROOM} bytes headroom."
        end
      elsif data.respond_to? 'size'
        if data.size > disk_free - HEADROOM
          raise DiskStoreError, "#{self} can't save #{name} - #{data.size} bytes data > #{disk_free} free disk bytes plus #{HEADROOM} bytes headroom."
        end
      else
        raise DiskStoreError, "#{self} can't determine the size of #{name} of type #{data.class}, aborting."
      end

      write_lock(name) do
        begin
          FileUtils.mkdir_p path(name)
        rescue => e
          raise DiskStoreError, "#{self} directory creation for #{name} failed: #{e.message}"
        end

        metafile = ''
        begin
          metafile = 'data'
          md5  = Digest::MD5.new
          sha1 = Digest::SHA1.new         # recent addition - not all old silos will have this, initially (unfortunately)

          open(data_path(name), "w") do |output|
            while buff = data.read(IO_BUFFER_SIZE)
              md5 << buff
              sha1 << buff
              output.write buff
              output.fsync
            end
          end

          metafile = 'sha1'
          open(sha1_path(name), "w") do |io|
            io.puts sha1.hexdigest
            io.fsync
          end

          metafile = 'md5'
          open(md5_path(name), "w") do |io|
            io.puts md5.hexdigest
            io.fsync
          end

          metafile = 'datetime'
          open(datetime_path(name), "w") do |io|
            io.puts Time.new.iso8601
            io.fsync
          end

          metafile = 'name'
          open(name_path(name), "w") do |io|
            io.puts name
            io.fsync
          end

          metafile = 'type'
          open(type_path(name), "w") do |io|
            io.puts type
            io.fsync
          end
        rescue => e
          raise DiskStoreError, "#{self} can't write the '#{metafile}' metafile for  #{name}: #{e.message}"
        end

        unless 6 == File.chmod(RESTRICTIVE_FILE_PERMISSIONS,
                               data_path(name),
                               datetime_path(name),
                               name_path(name),
                               md5_path(name),
                               sha1_path(name),
                               type_path(name))
          raise DiskStoreError, "#{self} can't set restrictive permissions on all data files for #{describe name}"
        end

        unless 1 == File.chmod(RESTRICTIVE_DIRECTORY_PERMISSIONS, path(name))
          raise DiskStoreError, "#{self} can't set restrictive permissions on data file directory for #{describe name}"
        end
      end # write_lock
    end # def

    # Get data identified by name from the silo. Takes an optional block for reading.
    #
    # open("MyStuff/MyFile", "w") do |output|
    #   silo.get(name) do |buff|
    #      output.write buff
    #   end
    # end
    #
    # or simply:
    #
    # data = silo.get(name)

    def get(name)
      return nil unless exists? name

      read_lock(name) do
        begin
          open(data_path(name)) do |io|
            if block_given?
              while buff = io.read(IO_BUFFER_SIZE)
                yield buff
              end
            else
              io.read
            end
          end
        rescue => e
          raise DiskStoreError, "#{self} can't get #{describe name}: #{e.message}"
        end
      end
    end


    # For those times when you really, really need an io object on the data

    def dopen(name)
      return nil unless exists? name
      read_lock(name) do
        begin
          open(data_path(name)) { |io|  yield io }
        rescue => e
          raise DiskStoreError, "#{self} can't get io object from #{describe name}: #{e.message}"
        end
      end
    end


    # Delete data identified by name. Deletes are done one file at a time with no recursion.

    def delete(name)
      write_lock(name) do
        begin
          File.chmod(PERMISSIVE_DIRECTORY_PERMISSIONS, path(name))
          [ datetime_path(name),
            data_path(name),
            type_path(name),
            sha1_path(name),
            md5_path(name),
            name_path(name) ].each { |filename| FileUtils.rm(filename)  }
          FileUtils.rmdir path(name)
        rescue => e
          raise DiskStoreError, "Can't delete #{describe name}: #{e.message}"
        end
      end
    end


    # Return the size (in bytes) of the data described by name.

    def size(name)
      read_lock(name) do
        begin
          File.size data_path(name)
        rescue => e
          raise DiskStoreError, "Can't determine size for #{describe name}: #{e.message}"
        end
      end
    end

    # Returns the content type of the data

    def type(name)
      read_lock(name) do
        begin
          open(type_path(name)) { |f| f.gets.chomp }
        rescue => e
          raise DiskStoreError, "Can't determine type for #{describe name}: #{e.message}"
        end
      end
    end

    # Returns the (saved) md5 hexdigest of data identified by name

    def md5(name)
      read_lock(name) do
        begin
          open(md5_path(name)) { |f| f.gets.chomp }
        rescue => e
          raise DiskStoreError, "Can't determine md5 for #{describe name}: #{e.message}"
        end
      end
    end

    # Returns the saved sha1 hexdigest of data

    def sha1(name)
      read_lock(name) do
        begin
          open(sha1_path(name)) { |f| f.gets.chomp }
        rescue => e
          raise DiskStoreError, "Can't determine sha1 for #{describe name}: #{e.message}"
        end
      end
    end

    # Return the iso8601 representation of date/time of the data described by name.

    def datetime(name)
      read_lock(name) do
        begin
          open(datetime_path(name)) { |f| DateTime.parse(f.gets.chomp) }
        rescue => ex
          raise DiskStoreError, "Can't determine the date time for #{describe name}: #{ex.message}"
        end
      end
    end

    def last_access(name)
      read_lock(name) do
        begin
          DateTime.parse File.atime(data_path(name)).to_s
        rescue => ex
          raise DiskStoreError, "Can't determine the date time for #{describe name}: #{ex.message}"
        end
      end
    end


    def etag(name)
      Digest::MD5.hexdigest(name + md5(name))
    end

    # Used to mixin enumerable's such as grep, etc.

    def each
      Find.find(filesystem) do |path|
        if path =~ %r|/([a-f0-9]{3})/[a-f0-9]{29}/name|
            yield open(path) { |io| io.read.chomp }
        end
      end
    end

    ### protected

    # The write/read_lock methods take care of opening closing the file locks; mostly, they
    # should just pass exceptions up, since they'll be wrapping specific silo operations.

    # We're creating lock files in the parent directories of the object, not the created
    # directories of the objects nor the silo filesystem - this limits contention.

    # Write and read use fstat to lock: once a write lock is acquired, no one else can
    # get a lock to read (a shared lock) or write (an exclusive lock). The way it works
    # is this: you can have as many read locks as you want, but the OS guarantees that
    # there will be never more than one write lock on a filehandle, nor will it allow
    # a write lock and read lock exist at the same time.

    def write_lock(name)
      begin
        FileUtils.mkdir_p parent_path(name)
      rescue => e
        raise DiskStoreError, "Parent directory creation for #{describe name} failed: #{e.message}"
      end
      lockfile = File.join(parent_path(name), LOCK_FILENAME)

      begin
        open(lockfile, "w") do |lock|
          Timeout.timeout(LOCKFILE_GRAB_TIMEOUT) { lock.flock(File::LOCK_EX) }
          yield
        end
      rescue Timeout::Error => e
      end
    end

    # read shared lock - any one can get another read lock, but no-one can get an exclusive (write) lock

    def read_lock(name)
      begin
        FileUtils.mkdir_p parent_path(name)
      rescue => e
        raise DiskStoreError, "Parent directory creation for #{describe name} failed: #{e.message}"
      end
      lockfile = File.join(parent_path(name), LOCK_FILENAME)

      begin
        open(lockfile, "w") do |lock|
          Timeout.timeout(LOCKFILE_GRAB_TIMEOUT) { lock.flock(File::LOCK_SH) }
          yield
        end
      rescue Timeout::Error => e
        raise DiskStoreError, "Timed out waiting for #{LOCKFILE_GRAB_TIMEOUT} seconds for read lock to #{describe name}: #{e.message}"
      end
    end

    # What's in a name?  no embedded control characters, that's for sure.

    def invalid_name?(string)
      string =~ /[^ a-zA-Z\/.,0-9_+~!\'\"@#*\(\)=-]/
    end

    # Return the filesystem paths of the various meta/data associated with and object identified by name.
    #
    # Here are the directories and file layouts: say we have an object named "my/stuff.txt" and
    # silo.filesystem is "/tmp/store/".  The the md5 checksum of "my/stuff.txt" (of the string itself,
    # not the contents of a file) is "9203e38408ebed690ecdf40953558dbb". We have the following:
    #
    # parent_path     /tmp/store/920/  (this is where we create lock files)
    # path            /tmp/store/920/3e38408ebed690ecdf40953558dbb/
    # data_path       /tmp/store/920/3e38408ebed690ecdf40953558dbb/data
    # datetime_path   /tmp/store/920/3e38408ebed690ecdf40953558dbb/datetime
    # md5_path        /tmp/store/920/3e38408ebed690ecdf40953558dbb/md5
    # sha1_path       /tmp/store/920/3e38408ebed690ecdf40953558dbb/sha1
    # name_path       /tmp/store/920/3e38408ebed690ecdf40953558dbb/name
    # type_path       /tmp/store/920/3e38408ebed690ecdf40953558dbb/type

    def path(name)
      md5  =  Digest::MD5.hexdigest name
      File.join(filesystem,  StoreUtils.hashpath(name))
    end

    def parent_path(name)
      md5  =  Digest::MD5.hexdigest name
      File.join(filesystem,  StoreUtils.hashpath_parent(name))
    end

    def data_path(name)
      File.join(path(name), "data")
    end

    def datetime_path(name)
      File.join(path(name), "datetime")
    end

    def type_path(name)
      File.join(path(name), "type")
    end

    def md5_path(name)
      File.join(path(name), "md5")
    end

    def sha1_path(name)
      File.join(path(name), "sha1")
    end

    def name_path(name)
      File.join(path(name), "name")
    end

    # Mostly for error messages:

    def describe(name)
      "'#{name}' (located at '#{path name}')"
    end

  end
end
