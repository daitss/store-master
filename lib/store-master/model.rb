require 'data_mapper'
require 'digest/sha1'
require 'net/http'
require 'store-master/disk-store'
require 'store-master/exceptions'
require 'store-master/model/copies'
require 'store-master/model/packages'
require 'store-master/model/pools'
require 'store-master/model/reservations'
require 'store-master/model/authentications'
require 'store-master/utils'
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

module StoreMasterModel

  OPEN_TIMEOUT = 60 * 60
  READ_TIMEOUT = 60 * 60 * 6

  include StoreMaster

  # We support two different styles of configuration; either a
  # yaml_file and a key into that file that yields a hash of
  # information, or the direct connection string itself.

  def self.setup_db *args

    connection_string = (args.length == 2 ? StoreUtils.connection_string(args[0], args[1]) : args[0])

    dm = DataMapper.setup(:store_master, connection_string)
    dm.resource_naming_convention = DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
    DataMapper.finalize
    dm.select('select 1')  # make sure we can connect
    return dm

  rescue => e
    raise ConfigurationError,
    "Failure setting up the store-master database: #{e.message}"
  end

  # Because we are using a non-default repository, we have to set up a faked 
  # default one, unless we are alreading using one.
  #
  #    From: http://datamapper.org/getting-started.html
  #
  #    Note: that currently you must setup a :default repository to work
  #    with DataMapper (and to be able to use additional differently
  #    named repositories). This might change in the future.
  #
  #

  def self.setup_unnecessary_default
    dm = DataMapper.setup(:default, 'sqlite:memory')
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
    db = repository(:store_master).adapter
    postgres_commands = [ 'alter table copies alter datetime type timestamp with time zone', ]

    if db.methods.include? 'postgres_version'
      postgres_commands.each { |sql| db.execute sql } 
    end
  end

end # of Module StoreMasterModel
