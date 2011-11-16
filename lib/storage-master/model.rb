require 'data_mapper'
require 'digest/sha1'
require 'net/http'
require 'storage-master/disk-store'
require 'storage-master/exceptions'
require 'storage-master/model/copies'
require 'storage-master/model/packages'
require 'storage-master/model/pools'
require 'storage-master/model/reservations'
require 'storage-master/model/authentications'
require 'storage-master/utils'
require 'time'
require 'uri'
require 'libxml'

# URI#to_s method prints basic credentials if they exist.  This provides an sanitized print method.
# We use URIs throughout our models.

module URI

  class HTTP
    alias :to_s_with_userinfo :to_s
    def to_s
      userinfo ? to_s_with_userinfo.sub(userinfo + '@', '') : to_s_with_userinfo
    end
  end

end

## TODO: returned etag is missing quotes

module StorageMasterModel

  OPEN_TIMEOUT = 60 * 60
  READ_TIMEOUT = 60 * 60 * 6

  include StorageMaster

  # StorageMasterModel.setup_db initializes the DataMapper database connection.
  #
  # We support two different styles of configuration; either a
  # yaml_file and a key into that file that yields a hash of
  # database information, or the direct connection string itself.
  # The two-argument version is deprecated.
  #
  # @param [String] connection_string, a database connection string, e.g. postgres://storemaster:topsecret@localhost/storemaster_db
  # @return [DataMapper::Adapter] the DataMapper repository object
  
  def self.setup_db *args

    connection_string = (args.length == 2 ? StoreUtils.connection_string(args[0], args[1]) : args[0])

    dm = DataMapper.setup(:default, connection_string)
    dm.resource_naming_convention = DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
    return dm

  rescue => e
    raise ConfigurationError,
    "Failure setting up the storage-master database: #{e.message}"
  end
  
  # StorageMasterModel.tables lists all of our tables.
  #
  # @return [Array] a list of DataMapper table classes

  def self.tables
    [ Copy, Package, Pool, Reservation, Authentication ]
  end

  # StorageMasterModel.tables (Re)creates tables for test or setup.  
  # Careful - it drops all data!

  def self.create_tables                # drops and recreates as well
    self.tables.map &:auto_migrate!
    self.patch_tables
  end

  # StorageMasterModel.tables updates tables from changes made to
  # the DataMapper classes.

  def self.update_tables
    self.tables.map &:auto_upgrade!
  end

  # StorageMasterModel.patch_tables makes ad-hoc modifications to
  # our postgress databases.

  def self.patch_tables                 # special purpose setup
    # db = repository(:store_master).adapter
    db = repository(:default).adapter
    postgres_commands = [ 'alter table copies alter datetime type timestamp with time zone', ]

    if db.methods.include? 'postgres_version'
      postgres_commands.each { |sql| db.execute sql } 
    end
  end

end # of Module StorageMasterModel
