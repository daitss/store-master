require 'data_mapper'
require 'net/http'
require 'store-master/model/copies'
require 'store-master/model/packages'
require 'store-master/model/pools'
require 'store-master/model/reservations'
require 'store-master/disk-store'
require 'store-master/exceptions'
require 'store-master/utils'
require 'time'
require 'uri'
require 'xml'

# URI#to_s method prints basic credentials if they exist.  This provides an sanitized print method.
# We use URIs throughout our models.

module URI

  class HTTP
    alias :old_to_s :to_s
    def to_s
      userinfo ? old_to_s.sub(userinfo + '@', '') : old_to_s
    end
  end

end

## TODO: returned etag is missing quotes

module StoreMasterModel

include StoreMaster

  def self.setup_db yaml_file, key
    dm = DataMapper.setup(:store_master, StoreUtils.connection_string(yaml_file, key))
    dm.resource_naming_convention = DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
    DataMapper.finalize
    dm.select('select 1 + 1')
    return dm

  rescue => e
    raise ConfigurationError,
    "Failure setting up the store-master database: #{e.message}"
  end

  # (Re)create tables for test or setup.  We'll also provide a mysql.ddl and psql.ddl for creating
  # the tables, which can give us a bit more flexibility (e.g., specialized indcies for some of the
  # sql we do)

  def self.tables
    [ Copy, Package, Pool, Reservation ]
  end

  def self.create_tables
    self.tables.map &:auto_migrate!
  end

  def self.update_tables
    self.tables.map &:auto_upgrade!
  end

end # of Module StoreMasterModel
