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


  class Package

    # provide a list of data mapper records for selected IEIDs  ordered by the copy URL

    def self.package_copies before

      ### TODO:  if we do this, we won't have top get individual package.new in fixity reconciliation,  it'll speed things tremendously
      ### We do the package.new there to get package objects so we can check for events; it's usually a waste of resources, though.

      sql = "SELECT package_copies.id AS ieid, " +
                   "package_copies.url, " +
                   "REPLACE(TO_CHAR(fixity_success_events.timestamp AT TIME ZONE 'GMT', 'YYYY-MM-DD HH24:MI:SSZ'), ' ', 'T') AS last_successful_fixity_time, " +
                   "REPLACE(TO_CHAR(package_copies.timestamp AT TIME ZONE 'GMT', 'YYYY-MM-DD HH24:MI:SSZ'), ' ', 'T') AS package_store_time, " +
                   "package_copies.md5, " +
                   "package_copies.sha1, " +
                   "package_copies.size " +

            "FROM (SELECT packages.id, copies.url as url, copies.md5, copies.sha1, copies.size, copies.timestamp " +
                    "FROM packages, aips, copies " +
                   "WHERE packages.id = aips.package_id " +
                     "AND copies.timestamp < '#{before}' " +
                     "AND aips.id = copies.aip_id) " +
            "AS package_copies " +

            "LEFT JOIN (SELECT package_id, timestamp FROM events WHERE name = 'fixity success') " +
            "AS fixity_success_events " +

            "ON package_copies.id = fixity_success_events.package_id " +
            "ORDER BY package_copies.url"

      # sql = "SELECT packages.id AS ieid, copies.url, copies.md5, copies.sha1, copies.size " +
      #         "FROM packages, aips, copies "                                                +
      #        "WHERE packages.id = aips.package_id "                                         +
      #          "AND copies.timestamp < '#{before}' "                                        +
      #          "AND aips.id = copies.aip_id "                                               +
      #     "ORDER BY copies.url"

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

      return true ###### 

      e = Event.new :name => 'integrity failure', :package => self
      e.agent = Agent.store_master
      e.notes = note
      return e.save
    end

    def fixity_failure_event note

      return true ###### 

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

      return true   ###### 

      event.agent     = Agent.store_master
      event.timestamp = datetime
      return event.save
    end


  end # of class Package
end # of module Daitss
