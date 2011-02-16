require 'dm-aggregates'
require 'dm-core'
require 'dm-migrations'
require 'dm-transactions'
require 'dm-types'
require 'dm-validations'
require 'net/http'
require 'store-master/data-model/copies'
require 'store-master/data-model/packages'
require 'store-master/data-model/pools'
require 'store-master/data-model/reservations'
require 'store-master/disk-store'
require 'store-master/exceptions'
require 'store-master/utils'
require 'time'
require 'uri'
require 'xml'

# URI#to_s method prints basic credentials if they exist.  This provides an sanitized print method.

module URI
  class HTTP
    alias :old_to_s :to_s
    def to_s
      userinfo ? old_to_s.sub(userinfo + '@', '') : old_to_s
    end
  end
end

## TODO: returned etag is missing quotes

# DataModel service routines DataModel.setup(config-file, key)  and DataModel.recreate_tables().

module DataModel

include StoreMaster

  def self.setup yaml_file, key

    begin
      dm = DataMapper.setup(:store_master, StoreUtils.connection_string(yaml_file, key))
      dm.resource_naming_convention = DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
      DataMapper.finalize
      dm.select('select 1 + 1')  # if we're going to fail (with, say, a non-existant database), let's fail now - thanks Franco for the SQL idea.
      return dm

    rescue => e
      raise ConfigurationError,
      "Failure setting up the #{dbinfo['vendor']} #{dbinfo['database']} database for #{dbinfo['username']} on #{dbinfo['hostname']} (#{dbinfo['password'] ? 'password supplied' : 'no password'}) - used the configuration file #{yaml_file}: #{e.message}"
    end
  end

  # (Re)create tables for test or setup.  We'll also keep mysql.ddl and psql.ddl for creating
  # the tables, which can gives us a bit more flexibility (e.g., cascading deletes)

  def self.create_tables
    Reservation.auto_migrate!
    Pool.auto_migrate!
    Package.auto_migrate!
    Copy.auto_migrate!
  end

  def self.update_tables
    Reservation.auto_upgrade!
    Pool.auto_upgrade!
    Package.auto_upgrade!
    Copy.auto_upgrade!
  end

end # of Module DataModel
