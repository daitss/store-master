require 'dm-core'
require 'dm-types'
require 'dm-aggregates'
# require 'dm-constraints'  doesn't seem to work
require 'dm-migrations'
require 'dm-transactions'
require 'dm-validations'
require 'store/diskstore'
require 'store/exceptions'
require 'time'

module DM

  ENV['TZ'] = 'UTC'  ### meh

  # Purpose here is to provide connections for datamapper using our yaml configuration file + key technique;

  def self.setup yaml_file, key
    oops = "DB setup can't"
    
    raise Store::ConfigurationError, "#{oops} understand the configuration file name - it's not a filename string, it's a #{yaml_file.class}."  unless (yaml_file.class == String)
    raise Store::ConfigurationError, "#{oops} understand key for the configuration file #{yaml_file} - it's not a string, it's a #{key.class}." unless (key.class == String)
    begin
      dict = YAML::load(File.open(yaml_file))
    rescue => e
      raise Store::ConfigurationError, "#{oops} parse the configuration file #{yaml_file}: #{e.message}."
    end
    raise Store::ConfigurationError, "#{oops} parse the data in the configuration file #{yaml_file}." if dict.class != Hash
    dbinfo = dict[key]
    raise Store::ConfigurationError, "#{oops} get any data from the #{yaml_file} configuration file using the key #{key}."                                    unless dbinfo
    raise Store::ConfigurationError, "#{oops} get the vendor name (e.g. 'mysql' or 'postsql') from the #{yaml_file} configuration file using the key #{key}." unless dbinfo.include? 'vendor'
    raise Store::ConfigurationError, "#{oops} get the database name from the #{yaml_file} configuration file using the key #{key}."                           unless dbinfo.include? 'database'
    raise Store::ConfigurationError, "#{oops} get the host name from the #{yaml_file} configuration file using the key #{key}."                               unless dbinfo.include? 'hostname'
    raise Store::ConfigurationError, "#{oops} get the user name from the #{yaml_file} configuration file using the key #{key}."                               unless dbinfo.include? 'username'
    
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
      raise Store::ConfigurationError,
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
    Event.auto_migrate!
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
    has n,      :events
        
    validates_uniqueness_of  :name
  end # of Package
  
  class Event
    include DataMapper::Resource
    storage_names[:default] = 'events'          # don't want dm_events
    
    def self.types
      [ :put, :delete ]
    end
    
    property   :id,        Serial,         :min => 1
    property   :datetime,  DateTime,       :index => true,   :default  => lambda { |resource, property| DateTime.now }
    property   :type,      Enum[ *types],  :index => true,   :required => true
    property   :outcome,   Boolean,        :index => true,   :default  => true
    property   :note,      String,         :length => 255,   :default  => ''
    
    belongs_to :package
  end # of Event
  
  class Pool
    include DataMapper::Resource
    storage_names[:default] = 'pools'           # don't want dm_pools
    
    property   :id,                Serial,   :min => 1
    property   :required,          Boolean,  :required => true, :default => true
    property   :put_location,      String,   :length => 255, :required => true   # :format => :url broken - use uri?
    property   :read_preference,   Integer,  :default  => 0

    has n, :copies

    validates_uniqueness_of :put_location
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
  end # of Copy

end # of Module DM

