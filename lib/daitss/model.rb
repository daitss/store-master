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
require 'store-master/utils'

module Daitss

  def self.setup_db yaml_file, key
    adapter = DataMapper.setup(:daitss, StoreUtils.connection_string(yaml_file, key))
    adapter.resource_naming_convention = DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
    DataMapper.finalize
    adapter
  end

  def self.create_tables
    Account.auto_migrate!
    Agent.auto_migrate!
    Aip.auto_migrate!
    Batch.auto_migrate!
    Copy.auto_migrate!
    Entry.auto_migrate!
    Event.auto_migrate!
    Package.auto_migrate!
    Project.auto_migrate!
    ReportDelivery.auto_migrate!
    Request.auto_migrate!
    Sip.auto_migrate!
  end

  def self.update_tables
    Account.auto_upgrade!
    Agent.auto_upgrade!
    Aip.auto_upgrade!
    Batch.auto_upgrade!
    Copy.auto_upgrade!
    Entry.auto_upgrade!
    Event.auto_upgrade!
    Package.auto_upgrade!
    Project.auto_upgrade!
    ReportDelivery.auto_upgrade!
    Request.auto_upgrade!
    Sip.auto_upgrade!
  end

end
