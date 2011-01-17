require 'dm-core'
require 'dm-types'
require 'dm-aggregates'
# require 'dm-constraints'  doesn't seem to work
require 'dm-migrations'
require 'dm-transactions'
require 'dm-validations'
require 'store-master/diskstore'
require 'store-master/exceptions'
require 'time'
require 'uri'

module DM

  ENV['TZ'] = 'UTC'  ### meh - replace ASAP

  # Purpose here is to provide connections for datamapper using our yaml configuration file + key technique;

  def self.setup yaml_file, key
    oops = "DB setup can't"
    
    raise StoreMaster::ConfigurationError, "#{oops} understand the configuration file name - it's not a filename string, it's a #{yaml_file.class}."  unless (yaml_file.class == String)
    raise StoreMaster::ConfigurationError, "#{oops} understand key for the configuration file #{yaml_file} - it's not a string, it's a #{key.class}." unless (key.class == String)
    begin
      dict = YAML::load(File.open(yaml_file))
    rescue => e
      raise StoreMaster::ConfigurationError, "#{oops} parse the configuration file #{yaml_file}: #{e.message}."
    end
    raise StoreMaster::ConfigurationError, "#{oops} parse the data in the configuration file #{yaml_file}." if dict.class != Hash
    dbinfo = dict[key]
    raise StoreMaster::ConfigurationError, "#{oops} get any data from the #{yaml_file} configuration file using the key #{key}."                                    unless dbinfo
    raise StoreMaster::ConfigurationError, "#{oops} get the vendor name (e.g. 'mysql' or 'postsql') from the #{yaml_file} configuration file using the key #{key}." unless dbinfo.include? 'vendor'
    raise StoreMaster::ConfigurationError, "#{oops} get the database name from the #{yaml_file} configuration file using the key #{key}."                           unless dbinfo.include? 'database'
    raise StoreMaster::ConfigurationError, "#{oops} get the host name from the #{yaml_file} configuration file using the key #{key}."                               unless dbinfo.include? 'hostname'
    raise StoreMaster::ConfigurationError, "#{oops} get the user name from the #{yaml_file} configuration file using the key #{key}."                               unless dbinfo.include? 'username'
    
    # Example string: 'mysql://root:topsecret@localhost/silos'
    
    connection_string =                                               # e.g.
      dbinfo['vendor']    + '://' +                                   # mysql://
      dbinfo['username']  +                                           # mysql://fischer
     (dbinfo['password']  ? ':' + dbinfo['password'] : '') + '@' +    # mysql://fischer:topsecret@  (or mysql://fischer@)
      dbinfo['hostname']  + '/' +                                     # mysql://fischer:topsecret@localhost/
      dbinfo['database']                                              # mysql://fischer:topsecret@localhost/store_master

    begin
      dm = DataMapper.setup(:default, connection_string)
      DataMapper.finalize
      dm.select('select 1 + 1')  # if we're going to fail (with, say, a non-existant database), let's fail now - thanks Franco for the SQL idea.
      return dm
      
    rescue => e
      raise StoreMaster::ConfigurationError,
      "Failure setting up the #{dbinfo['vendor']} #{dbinfo['database']} database for #{dbinfo['username']} on #{dbinfo['hostname']} (#{dbinfo['password'] ? 'password supplied' : 'no password'}) - used the configuration file #{yaml_file}: #{e.message}"
    end
  end

  # Recreate tables for test.  We also keep mysql.ddl and psql.ddl for creating
  # the tables, which gives us a bit more flexibility (e.g., cascading deletes)

  def self.recreate_tables
    Reservation.auto_migrate!
    Pool.auto_migrate!
    Package.auto_migrate!
    Copy.auto_migrate!
  end

  # A database for reserving names for URLs based on IEIDs.

  class Reservation
    include DataMapper::Resource
    storage_names[:default] = 'reservations'    # don't want dm_packages
    
    property   :id,         Serial
    property   :ieid,       String,   :required => true, :index => true, :length => (16..16)
    property   :name,       String,   :required => true, :index => true, :length => (20..20) # unique name, used as part of a url

    validates_uniqueness_of :name
  end
  
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

  end # of Package
  
  
  class Pool
    include DataMapper::Resource
    storage_names[:default] = 'pools'           # don't want dm_pools
    
    property   :id,                   Serial,   :min => 1
    property   :required,             Boolean,  :required => true, :default => true
    property   :put_location,         String,   :length => 255, :required => true   # :format => :url broken - use uri?
    property   :read_preference,      Integer,  :default  => 0
    property   :basic_auth_username,  String
    property   :basic_auth_password,  String

    has n, :copies

    validates_uniqueness_of :put_location

    def post_url name
      url = URI.parse(put_location.gsub(%r{/+$}, '')  +  '/'  +  name)
      if basic_auth_username or basic_auth_password
        url.user     = URI.encode basic_auth_username
        url.password = URI.encode basic_auth_password
      end
      url
    end

    def self.list_active
      DM::Pool.all(:required => true, :order => [ :read_preference.desc ])
    end

      
  end # of Pool
  
  class Copy
    include DataMapper::Resource
    storage_names[:default] = 'copies'          # don't want dm_copies
    
    property   :id,               Serial,   :min => 1
    property   :datetime,         DateTime, :index => true, :default => lambda { |resource, property| DateTime.now }
    property   :store_location,   String,   :length => 255, :required => true, :index => true  #, :format => :url

    belongs_to :pool
    belongs_to :package

    validates_uniqueness_of :pool, :scope => :package

    def url
      url = URI.parse store_location
      if pool.basic_auth_username or pool.basic_auth_password
        url.user     = URI.encode pool.basic_auth_username
        url.password = URI.encode pool.basic_auth_password
      end
      url
    end

  end # of Copy

end # of Module DM

