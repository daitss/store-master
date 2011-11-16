require 'data_mapper'
require 'daitss/model/account'
require 'daitss/model/agent'
require 'daitss/model/aip'
require 'daitss/model/copy'
require 'daitss/model/eggheadkey'
require 'daitss/model/event'
require 'daitss/model/package'
require 'daitss/model/project'
require 'daitss/model/request'
require 'daitss/model/sip'
require 'libxml'
require 'net/http'
require 'storage-master/exceptions'
require 'storage-master/utils'

# This module is a stripped-down copy of the DAITSS model from the
# DAITSS core project.  Core's model has a problem currently with
# sprawling dependencies, and ends up pulling in a tremendous amount
# of unnecessary code if used directly.

module Daitss

  # We support two different styles of configuration; either a
  # yaml_file and a key into that file that yields a hash of
  # information, or the direct connection string itself.
  # The two-argument version is deprecated.
  #
  # @return [DataMapper::Adapter] an initialized (but not finalized) adapter object
  # @param [String] arg, A connection string

  def self.setup_db *args

    connection_string = (args.length == 2 ? StoreUtils.connection_string(args[0], args[1]) : args[0])
    adapter = DataMapper.setup(:daitss, connection_string)
    adapter.resource_naming_convention = DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
    return adapter

  rescue => e
    raise StorageMaster::ConfigurationError, "Failure setting up the daitss database: #{e.message}"
  end

  def self.tables
    [ Account, Agent, Aip, Copy, Event, Package, Project, Request, Sip ]
  end

  # (Re)creates the DAITSS table we use - don't use this on a live system.

  def self.create_tables
    self.tables.map { |tbl|  tbl.send :auto_migrate! }
  end

  # Updates existing tables, will add new (though uninitialized) columns.

  def self.update_tables
    self.tables.map { |tbl|  tbl.send :auto_update! }
  end

end
