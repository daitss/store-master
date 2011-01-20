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

# URI#to_s method includes basic credentials.  This provides an alternative print method.

module URI
  class HTTP
    def sanitized
      userinfo ? to_s.sub(userinfo + '@', '') : to_s
    end
  end
end

## TODO: returned etag is missing quotes

# DataModel service routines DataModel.setup(config-file, key)  and DataModel.recreate_tables().

module DataModel

include StoreMaster

  # Purpose here is to provide connections for datamapper using our yaml configuration file + key technique;

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
      raise ConfigurationError,
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


end # of Module DataModel
