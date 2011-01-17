require 'digest/md5'
require 'fileutils'
require 'optparse'
require 'ostruct';
require 'sys/filesystem'
require 'yaml'

# You know the drawer in your kitchen that has all the junk in it?  This module is like that...

module StoreUtils

  def StoreUtils.disk_id(path)
    File.stat(path).dev
  end

  def StoreUtils.disk_free(path)
    fs = Sys::Filesystem.stat(path)
    fs.fragment_size * fs.blocks    # fragment_size is used in preference to block_size, which is just the OS's preference
  end
  
  def StoreUtils.disk_size(path)
    fs = Sys::Filesystem.stat(path)
    fs.fragment_size * fs.blocks_available  # blocks_available < blocks_free;  some are reserved for root.
  end
  
  def StoreUtils.strip_trailing_slash_maybe(string)
    return string if string.length == 1
    return string.gsub(/#{File::SEPARATOR}+$/, "")
  end

  def StoreUtils.valid_ieid_name? string
    string =~ /^E[A-Z0-9]{8}_[A-Z0-9]{6}$/ ? true : false
  end 

  def StoreUtils.xml_escape str
    str.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub("'", '&apos;').gsub('"', '&quot;')
  end

  def StoreUtils.csv_escape str
    '"' + str.gsub('"', '""') + '"'   # 'fo,o"bar' =>  '"fo,o""bar"'
  end

  # N.B. We depend on a trailing slash being removed
  
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
  
  # We need to provide the base64 of the original binary md5 checksum; however 
  # we typically have only the hexstring.  This funtion takes the hexstring, packs it
  # into the binary representation, then encodes that into a base64 representation.

  def StoreUtils.md5hex_to_base64(hexstring)
    return nil unless hexstring.length == 32
    [hexstring.scan(/../).pack("H2" * 16)].pack("m").chomp
  end

  # This function does the reverse of the above, taking the base64 string and returning
  # the corresponding hex string.

  def StoreUtils.base64_to_md5hex(string)
    return nil unless (string.class == String and string.length == 24)
    string.unpack("m")[0].unpack("H2" * 16).join
  end

  def StoreUtils.hashpath name
    md5  =  Digest::MD5.hexdigest name
    File.join(md5[0..2], md5[3..-1])      
  end


  def StoreUtils.hashpath_parent name
    Digest::MD5.hexdigest(name)[0..2]
  end
  
  # Without argument, give the name of the user running this process
  # as a string.  With argument PATH, a string, assume it is a
  # readable filepath and return the user name who owns it as a
  # string.

  def StoreUtils.user path = nil
    if path.nil?
      Etc.getpwuid(Process.uid).name
    else
      Etc.getpwuid(File.stat(path).uid).name
    end
  end

  # Without argument, return the group of the user running this
  # process as a string.  With argument PATH, a string, assume it is a
  # readble filepath and return the group name who owns it as a
  # string.

  def StoreUtils.group path = nil
    if path.nil? 
      Etc.getgrgid(Process.gid).name
    else
      Etc.getgrgid(File.stat(path).uid).name
    end
  end

  # put in commas in a number (American style numeric format)

  def StoreUtils.commify num
    num.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
  end

end # of Module StoreUtils
