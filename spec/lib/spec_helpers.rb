# require 'store/tables'
require 'digest/md5'
require 'digest/sha1'
require 'fileutils'
require 'socket'
require 'yaml'

def my_host
  Socket.gethostname
end

@@base = Time.now.strftime("%Y%m%d_AAAAAA")

def some_name
  (@@base.succ!).clone
end

def some_data
  data = "Some test data: " + rand(100000000).to_s + "\n"
end

def some_sha1
  Digest::SHA1.hexdigest("Some test data: " + rand(100000000).to_s + "\n")
end

def some_md5
  Digest::MD5.hexdigest("Some test data: " + rand(100000000).to_s + "\n")
end

# sh = SubtractableHash.new(1 => :a, 2 => :b, 3 => :c)  # returns { 1 => :a, 3 => :c, 2 => :b }, say.
# Then sh.minus(2) # returns { 1 => :a, 3 => :c }  without modifying the 'sh' object.

class SubtractableHash < Hash
  def initialize *args
    super
    self.merge! *args unless args.empty?
  end

  def minus key
    partial = self.clone
    partial.delete key
    partial
  end
end

def some_attributes
  hash = SubtractableHash.new  :sha1 => some_sha1, :md5 => some_md5, :timestamp => DateTime.now - rand(100), :size => rand(10000), :type => 'x-application/tar'
end

def recreate_database

  # We have db configuration data in a yaml file; it might look like:
  #
  # silo_spec_test:   { vendor: mysql, hostname: localhost, database: silo_spec_test, username: root, password: }
  #
  # We expect a silo_spec_test, and expect to be able to drop and recreate the tables via DM.automigrate!

  yaml_filename = '/opt/fda/etc/db.yml'  

  if not (File.exists?(yaml_filename) and File.readable?(yaml_filename))
    pending "Can't contine - see the comments in 'def recreate_database' in #{__FILE__} to fix this"
  end

  DB.setup yaml_filename, 'silo_spec_test'
  DB::DM.automigrate!
end
