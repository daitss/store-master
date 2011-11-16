require 'digest/md5'
require 'fileutils'
require 'optparse'
require 'ostruct'
require 'socket'
require 'sys/filesystem'
require 'yaml'

# You know the drawer in your kitchen that has all the junk in it?  That's the StoreUtils module...

module StoreUtils

  # disk_id returns a unique device id for a disk
  #
  # @param [String] path, a filepath to an existing directory
  # @return [Fixnum] a unique id for the disk the path is ion

  def StoreUtils.disk_id(path)
    File.stat(path).dev
  end

  # disk_size returns the number of bytes on a disk
  #
  # @param [String] path, a filepath to an existing directory
  # @return [Fixnum] the number of bytes on a disk

  def StoreUtils.disk_size(path)
    fs = Sys::Filesystem.stat(path)
    fs.fragment_size * fs.blocks            # fragment_size is used in preference to block_size, which is just the OS's preference
  end

  # disk_free returns the number of bytes free on a disk
  #
  #
  # @param [String] path, a filepath to an existing directory
  # @return [Fixnum] the number of bytes free on a disk

  def StoreUtils.disk_free(path)
    fs = Sys::Filesystem.stat(path)
    fs.fragment_size * fs.blocks_available  # blocks_available < blocks_free; some are reserved for root's exclusive use.
  end

  # strip_trailing_slash_maybe removes the trailing slash on a directory path, unless it is root
  #
  # @param [String] string, a pathname, possibly non-existent
  # @return [String] the new pasth without unnecessary slashes

  def StoreUtils.strip_trailing_slash_maybe(string)
    return string if string.length == 1
    return string.gsub(/#{File::SEPARATOR}+$/, "")
  end

  # valid_ieid_name?  returns true if the argument can be used as a valid IEID
  #
  # @param [String] string, a candidate IEID string
  # @return [Boolean] true if the string can be used as an IEID

  def StoreUtils.valid_ieid_name? string
    string =~ /^E[A-Z0-9]{8}_[A-Z0-9]{6}$/ ? true : false
  end

  # xml_escape turns a simple string into valid XML data
  #
  # @param [String] str, a string
  # @return [String] the escaped string

  def StoreUtils.xml_escape str
    str.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub("'", '&apos;').gsub('"', '&quot;')
  end

  # csv_escape turns a simple string into valid CSV data
  #
  # @param [String] str, a string
  # @return [String] the escaped string

  def StoreUtils.csv_escape str
    '"' + str.gsub('"', '""') + '"'   # 'fo,o"bar' =>  '"fo,o""bar"'
  end


  # disk_mount_point takes a path and gives us the mount point
  #
  # @param [String] path, a filepath
  # @return [String] the filepath mountpoint, without trailing slash

  def StoreUtils.disk_mount_point(path)
    path = File.expand_path(path)
    path = File.dirname(path) unless File.directory? path
    path = path.gsub(%r{/+$}, '')

    id = disk_id path
    components = path.split File::SEPARATOR  # break into path components and remove leading empty string
    components.shift

    topdown = File::SEPARATOR
    components.each do |c|
      return strip_trailing_slash_maybe(topdown) if disk_id(topdown) == id
      topdown += c + File::SEPARATOR
    end
    return strip_trailing_slash_maybe(topdown)
  end

  # md5hex_to_base64 base64-encodes an md5 checksum
  #
  # We need to provide the base64 of the original binary md5 checksum; however
  # we typically have only the hexstring.  This funtion takes the hexstring, packs it
  # into the binary representation, then encodes that into a base64 representation.
  #
  # @param [String] hexstring, the 32-character hex encoding representation of an MD5 checksum
  # @return [String] a base64 encoding of the binary representation of an MD5 checksum

  def StoreUtils.md5hex_to_base64(hexstring)
    return nil unless hexstring.length == 32
    [hexstring.scan(/../).pack("H2" * 16)].pack("m").chomp
  end

  # base64_to_md5hex does the reverse of md5hex_to_base64, taking the base64 string and returning
  # the corresponding hex string.
  #
  # @param [String] string, a base64 encoding of the binary representation of an MD5 checksum
  # @return [String] the 32-character hex encoding representation of an MD5 checksum


  def StoreUtils.base64_to_md5hex(string)
    return nil unless (string.class == String and string.length == 24)
    string.unpack("m")[0].unpack("H2" * 16).join
  end

  # hashpath returns the pathname fragment the StorageMaster::DiskStore module
  # uses when storing a package with the given name
  #
  # @param [String] name, a package name
  # @return [String] the pathname

  def StoreUtils.hashpath name
    md5  =  Digest::MD5.hexdigest name
    File.join(md5[0..2], md5[3..-1])
  end

  # hashpath_parent returns the first pathname component the StorageMaster::DiskStore module
  # uses when storing a package with the given name
  #
  # @param [String] name, a package name
  # @return [String] the pathname

  def StoreUtils.hashpath_parent name
    Digest::MD5.hexdigest(name)[0..2]
  end

  # user, without argument, give the name of the user running this process
  # as a string.  With argument PATH, a string, assume it is a readable filepath and return 
  # its owner's username.
  #
  # @param [String] path, if provided, a filepath to an existing file
  # @return [String] username

  def StoreUtils.user path = nil
    return Etc.getpwuid(Process.uid).name if path.nil?
    return Etc.getpwuid(File.stat(path).uid).name
  end

  # group, without argument, give the name of the group running this process
  # as a string.  With argument PATH, a string, assume it is a readable filepath and return 
  # its group name.
  #
  # @param [String] path, if provided, a filepath to an existing file
  # @return [String] username

  def StoreUtils.group path = nil
    return Etc.getgrgid(Process.gid).name if path.nil?
    return Etc.getgrgid(File.stat(path).uid).name
  end

  # commify turns a number into a more readable string format with commas in the American style.
  #
  # @param [Fixnum] num, a number (may also be a string)
  # @return [String] the number formated with commas

  def StoreUtils.commify num
    num.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
  end

  # connection_string is deprecated

  def StoreUtils.connection_string yaml_file, key

    oops = "Database setup can't"

    # This looks like excessive error checking, but configuration errors need a lot of explanation for new users of DAITSS.

    begin
      dict = YAML::load(File.open(yaml_file))
    rescue => e
      raise "#{oops} parse the configuration file '#{yaml_file}': #{e.message}."
    end

    raise "#{oops} parse the data in the configuration file '#{yaml_file}'." if dict.class != Hash

    dbinfo = dict[key]
    raise "#{oops} get any data from the configuration file '#{yaml_file}' using the key '#{key}'"                                     unless dbinfo
    raise "#{oops} get the vendor name (e.g. 'mysql' or 'postgres') from the configuration file '#{yaml_file}' using the key '#{key}'" unless dbinfo.include? 'vendor'
    raise "#{oops} get the database name from the configuration file '#{yaml_file}' using the key '#{key}'"                            unless dbinfo.include? 'database'
    raise "#{oops} get the host name from the configuration file '#{yaml_file}' using the key '#{key}'"                                unless dbinfo.include? 'hostname'
    raise "#{oops} get the user name from the configuration file '#{yaml_file}' using the key '#{key}'"                                unless dbinfo.include? 'username'

    # Example string: 'mysql://root:topsecret@localhost/silos'

    return \
      dbinfo['vendor']    + '://' +                                   # mysql://
      dbinfo['username']  +                                           # mysql://fischer
     (dbinfo['password']  ? ':' + dbinfo['password'] : '') + '@' +    # mysql://fischer:topsecret@  (or mysql://fischer@)
      dbinfo['hostname']  +
     (dbinfo['port']      ? ':' + dbinfo['port'].to_s : '')  + '/' +  # mysql://fischer:topsecret@localhost/ (or mysql://fischer:topsecret@localhost:port/)
      dbinfo['database']                                              # mysql://fischer:topsecret@localhost/store_master
  end

  # pid_file returns a filepath we can use for creating a lock fail based on this process's PID.
  # If out process name was 'foo' and we use '/var/run' then we'd return '/var/run/foo.pid'
  #
  # @param [String] dir, a directory path
  # @return [String] a filepath

  # Given a directory, return a path to a PID file in it, naming based on the currently running process name

  def StoreUtils.pid_file dir
    File.join(dir, $0.split(File::SEPARATOR).pop + '.pid')
  end


  # safen_connection_string removes password information from a DataMapper-style connection string
  #
  # @param [String] str, a connection string
  # @return [String] a connection string with the password obscurred, or the original string if no password

  def StoreUtils.safen_connection_string str

    vendor, rest = str.split('://', 2)              # postgres://fischer:topsecret@example.org:5432/mydb => [ postgres, fischer:topsecret@example.org:5432/mydb ]
    return str unless rest

    userinfo, host_and_db = rest.split('@', 2)      # fischer:topsecret@example.org:5432/mydb => [ fischer:topsecret, example.org:5432/mydb ]
    return str unless host_and_db

    user, pass = userinfo.split(':', 2)             # fischer:topsecret => [ fischer, topsecret ]
    return str unless pass

    return vendor + '://' + user + ':********@' + host_and_db   # return postgres://fischer:********@example.org:5432/mydb
  end

end # of Module StoreUtils
