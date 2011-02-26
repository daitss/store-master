require 'data_mapper'
require 'daitss/model/account'
require 'daitss/model/agent'
require 'daitss/model/aip'
require 'daitss/model/batch'
require 'daitss/model/copy'
require 'daitss/model/eggheadkey'
require 'daitss/model/entry'
require 'daitss/model/event'
require 'daitss/model/package'
require 'daitss/model/project'
require 'daitss/model/report_delivery'
require 'daitss/model/request'
require 'daitss/model/sip'
require 'libxml'
require 'net/http'
require 'store-master/exceptions'
require 'store-master/utils'

module Daitss

  def self.setup_db yaml_file, key
    adapter = DataMapper.setup(:daitss, StoreUtils.connection_string(yaml_file, key))
    adapter.resource_naming_convention = DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
    DataMapper.finalize
    adapter.select('select 1 + 1')
    return adapter
  rescue => e
    raise StoreMaster::ConfigurationError, "Failure setting up the daitss database: #{e.message}"
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
