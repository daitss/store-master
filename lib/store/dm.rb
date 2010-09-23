require 'dm-core'
require 'dm-types'
require 'dm-validations'
require 'dm-aggregates'
require 'dm-transactions'
require 'dm-migrations'
require 'store/exceptions'
require 'store/diskstore'

module DM

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
    
    connection_string = 
      dbinfo['vendor'] + 
      '://' + 
      (dbinfo['username'] or '') +
      (dbinfo['password'] ? ':' + dbinfo['password'] : '') +
      '@' + dbinfo['hostname'] + '/' + dbinfo['database']

    begin
      dm = DataMapper.setup(:default, connection_string)
      dm.select('select 1 + 1')  # if we're going to fail (with, say, a non-existant database), let's fail now - thanks Franco for the SQL idea.
      return dm
      
    rescue => e
      raise Store::ConfigurationError,
      "Failure setting up the #{dbinfo['vendor']} #{dbinfo['database']} database for #{dbinfo['username']} on #{dbinfo['hostname']} (#{dbinfo['password'] ? 'password supplied' : 'no password'}) - used the configuration file #{yaml_file}: #{e.message}"
    end
  end


  def self.recreate_tables
    Silo.auto_migrate!
    Package.auto_migrate!
    Copy.auto_migrate!
    Event.auto_migrate!
  end
  
  class Package
    
    include DataMapper::Resource
    storage_names[:default] = 'packages'    # don't want dm_packages
    
    property   :id,         Serial
    property   :extant,     Boolean,  :default  => true, :index => true
    property   :name,       String,   :required => true, :index => true
    
    property   :sha1,       String,   :required => true, :length => (40..40), :index => true
    property   :md5,        String,   :required => true, :length => (32..32), :index => true
    property   :datetime,   DateTime, :index => true, :default => lambda { |resource, property| DateTime.now }
    
    property   :size,       Integer,  :required => true, :index => true, :min => 0, :max => 2**63 - 1  # (2**63 - 1 for postgress, 2**64 -1 for mysql)
    property   :type,       String,   :required => true, :default => 'application/x-tar'
    
    # many-to-many  relationship - a package can (and should) have copies on several different silos
    
    has n,      :copies
    has n,      :silos,     'Silo', :through => :copies, :via => :silo
    
    # all sorts of things can happen to a package, events is where we keep them.
    
    has n,      :events
        
    validates_uniqueness_of  :name
  end # of Package
  
  class Event
    include DataMapper::Resource
    storage_names[:default] = 'events'          # don't want dm_events
    
    def self.types
      [ :put, :delete, :fixity, :update ]
    end
    
    property   :id,        Serial
    property   :timestamp, DateTime,       :key => true,   :default => lambda { |resource, property| DateTime.now }
    property   :type,      Enum[ *types],  :key => true,   :required => true
    property   :outcome,   Boolean,        :key => true,   :default => true
    property   :note,      String,         :length => 255, :default => ''
    
    belongs_to :package
  end # of Event
  
  class Silo
    include DataMapper::Resource
    storage_names[:default] = 'silos'           # don't want dm_silos
    
    property   :id,         Serial
    property   :retired,    Boolean,  :default  => false
    property   :active,     Boolean,  :default  => true
    property   :location,   String,   :required => true, :index => true, :format => :url
  end # of Silo
  
  class Copy
    include DataMapper::Resource
    storage_names[:default] = 'copies'          # don't want dm_copies
    
    property   :timestamp,  DateTime, :index => true, :default => lambda { |resource, property| DateTime.now }
    belongs_to :silo,      :key => true
    belongs_to :package,   :key => true
    
  end # of Copy
end # of Module DM

