require 'data_mapper'
require 'daitss/model/account'
require 'daitss/model/agent'
require 'daitss/model/aip'
require 'daitss/model/copy'
require 'daitss/model/eggheadkey'
require 'daitss/model/entry'       # do we need this one?
require 'daitss/model/event'
require 'daitss/model/package'
require 'daitss/model/project'
require 'daitss/model/request'
require 'daitss/model/sip'
require 'libxml'
require 'net/http'
require 'storage-master/exceptions'
require 'storage-master/utils'

module Daitss

  # We support two different styles of configuration; either a
  # yaml_file and a key into that file that yields a hash of
  # information, or the direct connection string itself.
  # The two-argument version is deprecated.

  def self.setup_db *args

    connection_string = (args.length == 2 ? StoreUtils.connection_string(args[0], args[1]) : args[0])
    adapter = DataMapper.setup(:daitss, connection_string)
    adapter.resource_naming_convention = DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
    return adapter

  rescue => e
    raise StorageMaster::ConfigurationError, "Failure setting up the daitss database: #{e.message}"
  end

  def self.tables
    [ Account, Agent, Aip, Batch, Copy, Entry, Event, Package, Project, ReportDelivery, Request, Sip ]
  end

  def self.create_tables
    self.tables.map { |tbl|  tbl.send :auto_migrate! }
  end

  def self.update_tables
    self.tables.map { |tbl|  tbl.send :auto_update! }
  end

end
