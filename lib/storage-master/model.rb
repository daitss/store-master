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

  # We support two different styles of configuration; either a
  # yaml_file and a key into that file that yields a hash of
  # database information, or the direct connection string itself.
  # The two-argument version is deprecated.

  def self.setup_db *args

    connection_string = (args.length == 2 ? StoreUtils.connection_string(args[0], args[1]) : args[0])

    dm = DataMapper.setup(:default, connection_string)
    dm.resource_naming_convention = DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
    return dm

  rescue => e
    raise ConfigurationError,
    "Failure setting up the storage-master database: #{e.message}"
  end

  # (Re)create tables for test or setup.  We'll also provide a mysql.ddl and psql.ddl for creating
  # the tables, which can give us a bit more flexibility (e.g., specialized indcies for some of the
  # sql we do)

  def self.tables
    [ Copy, Package, Pool, Reservation, Authentication ]
  end

  def self.create_tables                # drops and recreates as well
    self.tables.map &:auto_migrate!
    self.patch_tables
  end

  def self.update_tables                # will make minor schema changes
    self.tables.map &:auto_upgrade!
  end

  def self.patch_tables                 # special purpose setup
    # db = repository(:store_master).adapter
    db = repository(:default).adapter
    postgres_commands = [ 'alter table copies alter datetime type timestamp with time zone', ]

    if db.methods.include? 'postgres_version'
      postgres_commands.each { |sql| db.execute sql } 
    end
  end

end # of Module StorageMasterModel
