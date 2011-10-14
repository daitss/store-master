require 'daitss/model'
require 'store-master/exceptions'

module Daitss

  class Agent

    @@store_master = nil

    def self.store_master
      return @@store_master if @@store_master
      sys = Account.first(:id => 'SYSTEM') or
        raise StoreMaster::ConfigurationError, "Can't find the SYSTEM account - this is a database setup issue - so can neither find nor create the #{StoreMaster.version.uri} Software Agent"
      @@store_master = Program.first_or_create(:id => StoreMaster.version.uri, :account => sys)
    end

  end

  ## TODO: there are smarter (faster?) ways to do some of these with datamapper-joins and slices, maybe
  #
  # get all the copy URL
  #
  # Copy.all(Copy.aip.package.id.not => nil, :timestamp.lt => DateTime.now, :order => :url).slice(0,1000).map { |elt| elt.url.path.split('/').pop } 
  #
  # Package.all(Package.aip.copy.timestamp.lt => DateTime, :order => :id).slice...


  class Package


    # provide a list of data mapper records for selected IEIDs  ordered by the copy URL

    def self.package_copies  before
      sql = "SELECT packages.id AS ieid, copies.url, copies.md5, copies.sha1, copies.size " +
              "FROM packages, aips, copies "                                                +
             "WHERE packages.id = aips.package_id "                                         +
               "AND copies.timestamp < '#{before}' "                                        +
               "AND aips.id = copies.aip_id "                                               +
          "ORDER BY copies.url"

      repository(:daitss).adapter.select(sql)
    end

    # get a package object via a URL
    # TODO: might be better to rework our algorithms to get a collection of packages...

    def self.lookup_from_url url

      sql = "SELECT package_id "               +
              "FROM copies, aips "             +
             "WHERE copies.aip_id = aips.id "  +
               "AND copies.url = '#{url}' "    +
             "LIMIT 1"

      id = repository(:daitss).adapter.select(sql)
      Package.get(id)
    end

    # event recording: return true if saved, false on error, and, in the case of success events, nil if unchanged

    def integrity_failure_event note
      e = Event.new :name => 'integrity failure', :package => self
      e.agent = Agent.store_master
      e.notes = note
      return e.save
    end

    def fixity_failure_event note
      e = Event.new :name => 'fixity failure', :package => self
      e.agent = Agent.store_master
      e.notes = note
      return e.save
    end

    ### TODO - there may be a better way to do these en masse, something like?
    #
    #   collection = Event.first(0)      
    #   event = Event.first_or_new 
    #   collection.push event if some-condition
    # ...
    #   collection.save      


    def fixity_success_event datetime
      event = Event.first_or_new :name => 'fixity success', :package => self
      return nil if event.timestamp == datetime
      event.agent     = Agent.store_master
      event.timestamp = datetime
      return event.save
    end


  end # of class Package
end # of module Daitss
