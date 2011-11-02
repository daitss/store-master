require 'daitss/model'
require 'storage-master/exceptions'

module Daitss

  class Agent

    @@storage_master = nil

    def self.storage_master
      return @@storage_master if @@storage_master
      sys = Account.first(:id => 'SYSTEM') or
        raise StorageMaster::ConfigurationError, "Can't find the SYSTEM account - this is a database setup issue - so can neither find nor create the #{StorageMaster.version.uri} Software Agent"
      @@storage_master = Program.first_or_create(:id => StorageMaster.version.uri, :account => sys)
    end

  end


  class Package

    # provide a list of data mapper records for selected IEIDs  ordered by the copy URL

    def self.package_copies before


      # The following sql is meant to provide information from the
      # DAITSS DB in the following form:
      #
      #        ieid       |                                  url                                | last_successful_fixity_time |  package_store_time  |               md5                |                   sha1                   |    size     
      #  E13LVY77R_4VP1BD | http://storage-master.fda.fcla.edu:70/packages/E13LVY77R_4VP1BD.000 |                             | 2011-10-29T23:04:04Z | 4108b06e33b4b742f66d2106aa58adbe | de78cfd8e8444c56b6e519cbec21d9f9c8b249e0 |   179752960
      #  E1ADTX4PV_WPV7W3 | http://storage-master.fda.fcla.edu:70/packages/E1ADTX4PV_WPV7W3.000 | 2011-09-25T02:22:16Z        | 2011-07-14T01:41:29Z | 97E8E907719AA620B94D19AD5EB0838F | 4D9FEAB61C20AB1C20558BB11A49F72EF9F6F505 |   370350080
      #  E1AFGE6DV_P6P6FK | http://storage-master.fda.fcla.edu:70/packages/E1AFGE6DV_P6P6FK.000 |                             | 2011-10-30T00:15:47Z | ba41f44d02fc1957085bb394f1953ff8 | 2944aeba54a190551865e5b23579ab39ed25b67f |    85872640
      #  E1AK86W44_W77Z0G | http://storage-master.fda.fcla.edu:70/packages/E1AK86W44_W77Z0G.000 | 2011-09-06T05:02:13Z        | 2011-07-09T20:25:56Z | 241F5E2996B16C2F6E47781912ADDCBA | 73A66EA5BB5BADFDF0BA3441D18C29C71478F379 |   977510400
      # 

      # The important bit is that last_successful_fixity time can be
      # null for the case of a new ieid, so that we can check if a
      # succesful fixity check has been repeated, and not attempt to
      # update the daitss database.  It has a bug that doesn't affect
      # our use, however: the last_successful_fixity time may refer to
      # an old version of the ieid on a recently refreshed package.


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

      repository(:daitss).adapter.select(sql)
    end

    # get a package object via a URL

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

      #### return true ###### 

      e = Event.new :name => 'integrity failure', :package => self
      e.agent = Agent.storage_master
      e.notes = note
      return e.save
    end

    def fixity_failure_event note

      #### return true ###### 

      e = Event.new :name => 'fixity failure', :package => self
      e.agent = Agent.storage_master
      e.notes = note
      return e.save
    end


    # We're never supposed to have more than one success_fixity event at all, and this
    # very expensive operation should not be called at all if the timestamps are the
    # same - that's checked beforehand


    def fixity_success_event datetime
      timestamp = DateTime.parse(datetime)

      event = Event.first_or_new :name => 'fixity success', :package => self
      return false if event.timestamp == timestamp

      #### return true   ###### 

      event.agent     = Agent.storage_master
      event.timestamp = timestamp
      return event.save
    end


  end # of class Package
end # of module Daitss
