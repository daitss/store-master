require 'dm-core'
require 'dm-types'
require 'dm-validations'
require 'dm-aggregates'
require 'dm-transactions'
require 'dm-migrations'
require 'store/exceptions'


# Purpose is to provide connections for datamapper using our yaml configuration file + key technique.
module DM

  class DB

    def self.setup yaml_file, key
      oops = "DB setup can't"
      
      raise ConfigurationError, "#{oops} understand the configuration file name - it's not a filename string, it's a #{yaml_file.class}."  unless (yaml_file.class == String)
      raise ConfigurationError, "#{oops} understand key for the configuration file #{yaml_file} - it's not a string, it's a #{key.class}." unless (key.class == String)
      begin
        dict = YAML::load(File.open(yaml_file))
      rescue => e
        raise ConfigurationError, "#{oops} parse the configuration file #{yaml_file}: #{e.message}."
      end
      raise ConfigurationError, "#{oops} parse the data in the configuration file #{yaml_file}." if dict.class != Hash
      dbinfo = dict[key]
      raise ConfigurationError, "#{oops} get any data from the #{yaml_file} configuration file using the key #{key}."                                    unless dbinfo
      raise ConfigurationError, "#{oops} get the vendor name (e.g. 'mysql' or 'postsql') from the #{yaml_file} configuration file using the key #{key}." unless dbinfo.include? 'vendor'
      raise ConfigurationError, "#{oops} get the database name from the #{yaml_file} configuration file using the key #{key}."                           unless dbinfo.include? 'database'
      raise ConfigurationError, "#{oops} get the host name from the #{yaml_file} configuration file using the key #{key}."                               unless dbinfo.include? 'hostname'
      raise ConfigurationError, "#{oops} get the user name from the #{yaml_file} configuration file using the key #{key}."                               unless dbinfo.include? 'username'
      
      # Example string: 'mysql://root:topsecret@localhost/silos'
      
      connection_string = dbinfo['vendor'] + '://' + dbinfo['username'] +
        (dbinfo['password'] ? ':' + dbinfo['password'] : '') +
        '@' + dbinfo['hostname'] + '/' + dbinfo['database']
      begin
        
        dm = DataMapper.setup(:default, connection_string)
        dm.select('select 1 + 1')  # if we're going to fail (with, say, a non-existant database), let's fail now - thanks Franco for the SQL idea.
        return dm
        
      rescue => e
        raise ConfigurationError,
        "Failure setting up the #{dbinfo['vendor']} #{dbinfo['database']} database for #{dbinfo['username']} on #{dbinfo['hostname']} (#{dbinfo['password'] ? 'password supplied' : 'no password'}) - used the configuration file #{yaml_file}: #{e.message}"
      end
    end
  end
  
  
  
  ### TODO: name unique across id scope
  
  class Package
    
    include DataMapper::Resource
    
    property   :id,         Serial
    property   :extant,     Boolean,  :default  => true, :index => true
    property   :name,       String,   :required => true, :index => true
    
    property   :sha1,       String,   :required => true, :length => (40..40), :index => true
    property   :md5,        String,   :required => true, :length => (32..32), :index => true
    property   :datetime,   DateTime, :index => true, :default => lambda { |resource, property| DateTime.now }
    
    property   :size,       Integer,  :required => true, :index => true, :min => 0, :max => 2**64 - 1
    property   :type,       String,   :required => true, :default => 'application/x-tar'
    
    # many-to-many  relationship - a package can (and should) have copies on several different silos
    
    has n,      :copies
    has n,      :silos,     'Silo', :through => :copies, :via => :silo
    
    # all sorts of things can happen to a package, events is where we keep them.
    
    has n,      :events
    
    # We find packages in the following ways:
    #
    #  package = Package.new(name, disk_store) => creates a new package based on data stored to disk; basic information is saved to the db
    #  package = Package.new(name)             => look up an existing package by name
    #  package = Package.new(id)               => look up an existing package by its id
    
    @package = nil
    
    # def initialize *args
    #   if args.length == 1 and args[0].class == String
    #     @package = initialize_from_db(args[0])
    #   elsif args.length == 1 and args[0].class == Fixnum
    #     @package = Package.get(args[0])
    #   else
    #     @package = initialize_from_disk_store(args[0], args[1])
    #   end
    # end
    
    # def initialize_from_db name
    #   @package = Packages.first(:name => name)
    # end
    
    # def initialize_from_disk_store name, diskstore
    #   @package = Packages.create
    #   @package.md5      = diskstore(name).md5
    #   @package.sha1     = diskstore(name).sha1
    #   @package.size     = diskstore(name).size
    #   @package.type     = diskstore(name).type
    #   @package.datetime = diskstore(name).datetime
    
    #   ### least surprise might be to require a record!
    
    #   @package.save or 
    #     raise Store::DataBaseError, "Can't create record for new package #{name} from #{diskstore}: " + @package.errors.join('; ')
    # end
    
    
    # # these don't save immediately
    
    # def md5;       @package.md5;      end;      def md5= datum;       @package.md5 = datum;      end
    # def sha1;      @package.sha1;     end;      def sha1= datum;      @package.sha1 = datum;     end
    # def size;      @package.size;     end;      def size= datum;      @package.size = datum;     end
    # def type;      @package.type;     end;      def type= datum;      @package.type = datum;     end
    # def datetime;  @package.datetime; end;      def datetime= datum;  @package.datetime = datum; end
    
    # def record!
    #   @package.save or 
    #     raise Store::DataBaseError, "Can't save record for package #{name}:" + @package.errors.join('; ')
    # end
    
    # # return array of silo objects where we have copies, 
    
    # def locations
    #   silos = []
    #   @packages.silos.each do |s|
    #     silos.push Silo.new(s)
    #   end
    #   silos
    # end
    
    # # add a new event
    
    # def event
    
    # end
    
    # # get all of the events; the underlying datamapper objects should suffice
    
    # def events
    #   @package.events
    # end
    
    
  end # of Package
  
  class Event
    include DataMapper::Resource
    
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
    
    property   :id,         Serial
    property   :retired,    Boolean,  :default  => false
    property   :active,     Boolean,  :default  => true
    property   :location,   String,   :required => true, :index => true, :format => :url
  end # of Silo
  
  class Copy
    include DataMapper::Resource
    
    property   :timestamp,  DateTime, :index => true, :default => lambda { |resource, property| DateTime.now }
    property   :foo,        String, :default => 'bar'
    belongs_to :silo,      :key => true
    belongs_to :package,   :key => true
    
  end # of Copy

end # of Module DM

  
DM::DB.setup('/opt/fda/etc/db.yml', 'store_master')

DM::Silo.auto_migrate!
DM::Package.auto_migrate!
DM::Copy.auto_migrate!
DM::Event.auto_migrate!

silo001 = DM::Silo.create
silo001.location = 'http://silos.darchive.flca.edu/001'
silo001.save or raise "Can't save silo"

silo003 = DM::Silo.create
silo003.location = 'http://silos.darchive.flca.edu/003'
silo003.save or raise "Can't save silo"

silo007 = DM::Silo.create
silo007.location = 'http://silos.darchive.flca.edu/007'
silo007.save or raise "Can't save silo"

package  = DM::Package.create

package.name      = 'E20100921_AAAAAA'
package.md5       = 'd3b07384d113edec49eaa6238ad5ff00'
package.sha1      = 'f1d2d2f924e986ac86fdf7b36c94bcdf32beec15'
package.size      = 10000

# puts (package.methods - Object.methods).sort.join(', ')

copy = DM::Copy.create
copy.silo    = silo001
copy.package = package
copy.foo     = 'quux'
package.copies.push copy

package.silos.push silo003
package.silos.push silo007

unless package.save 
  puts "Errors saving package"
  package.errors.each { |e| puts e }
end

package.copies.each { |c| puts c.inspect }


# package = Package.create
#
# package.name  = 
# package.md5   = ''
# package.sha1  = ''
#
# package.silos << silo
# package.save
