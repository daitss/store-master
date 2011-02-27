require 'datyl/streams'
require 'daitss/model'
require 'store-master'

module Daitss

  class Agent

    @@store_master = nil

    def self.store_master
      return @@store_master if @@store_master
      sys = Account.first(:id => 'SYSTEM') or 
        raise StoreMaster::ConfigurationError, "Can't find the SYSTEM account, so cannot find/create the #{StoreMaster.version.uri} Software Agent"
      @@store_master = Program.first_or_create(:id => StoreMaster.version.uri, :account => sys)
    end

  end

  class Package

    # Provide a list of all of the package ids sorted by the copy URL.
    # There will be on the order of 10^6 of these

    def self.package_copies_ids  before = DateTime.now
      sql = "SELECT packages.id "                    +
              "FROM packages, aips, copies "         +
             "WHERE packages.id = aips.package_id "  +
               "AND aips.id = copies.aip_id "        +
               "AND copies.timestamp < '#{before}' " +               # TODO: make sure all variations of timestamps work
          "ORDER BY copies.url"

      repository(:daitss).adapter.select(sql)
    end

    # provide a list of data mapper records for selected IEIDs  ordered by the copy URL

    def self.package_copies  ieids
      return [] if ieids.empty?
      sql = "SELECT packages.id AS ieid, copies.url, copies.md5, copies.sha1, copies.size " +
              "FROM packages, aips, copies "                                                +
             "WHERE packages.id = aips.package_id "                                         +
               "AND aips.id = copies.aip_id "                                               +
               "AND packages.id in ('#{ieids.join("', '")}') "                              +
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

    def integrity_failure_event note
      e = Event.new :name => 'integrity failure', :package => self
      e.agent = Agent.store_master
      e.notes = note
      e.save
    end

    def fixity_failure_event note
      e = Event.new :name => 'fixity failure', :package => self
      e.agent = Agent.store_master
      e.notes = note      
      e.save
    end

    def fixity_success_event datetime
      event = Event.first_or_new :name => 'fixity success', :package => self
      return true if event.timestamp === datetime

      event.agent     = Agent.store_master
      event.timestamp = datetime
      event.save
    end


  end # of class Package
end # of module Daitss


module Streams

  # This data stream returns key/value pairs of fixity information as
  # known by DAITSS.  The keys are sorted, unique URLs (strings)
  # showing the store-master provided location.  The values are a
  # datamapper-provided struct giving the expected MD5, SHA1 and Size
  # of the package, as well as its IEID.
  #
  # 'http://betastore.tarchive.fcla.edu/packages/EZQQYQMC2_6PYZMQ.000' #<Struct::DataMapper ieid="EZQQYQMC2_6PYZMQ", url="http://betastore.tarchive.fcla.edu/packages/EZQQYQMC2_6PYZMQ.000", md5="7e45d204d270da0f8aab2a65f59a2429", sha1="e541c693e56edd9a7e04cab94de5740092ae3953", size=4761600>
  # 'http://betastore.tarchive.fcla.edu/packages/EZYNH5CZC_ZP2B9Y.000' #<Struct::DataMapper ieid="EZYNH5CZC_ZP2B9Y", url="http://betastore.tarchive.fcla.edu/packages/EZYNH5CZC_ZP2B9Y.000", md5="52076e3d8a9196d365c8381e135b6812", sha1="b046c58503f570ea090b8c5e46cc5f4e0c27f003", size=1962598400>
  # 'http://betastore.tarchive.fcla.edu/packages/EZYVXE2TV_J9MW69.000' #<Struct::DataMapper ieid="EZYVXE2TV_J9MW69", url="http://betastore.tarchive.fcla.edu/packages/EZYVXE2TV_J9MW69.000", md5="0959a55d2b6b46c4080bc85b10b87947", sha1="05fc20aaebad2708b91ad4c0d372ca733da7417a", size=2763468800>
  #  ...
  #

  class DaitssPackageStream

    # TODO: we might be better off maintaining an index into @ieids and keeping it around, rather than shifting
    # materials off and having to re-create it with another database hit.  We'll see after how it's used in practice.

    CHUNK_SIZE = 2000

    def initialize before = DateTime.now
      @before = before
      setup
    end

    def rewind
      setup
      self
    end

    def setup
      @ieids  = Daitss::Package.package_copies_ids @before
      @last   = nil
      @buff   = []
      @closed = false
      @ungot  = false
    end

    def to_s
      "#<#{self.class}##{self.object_id} IEIDs prior to #{@before}>"
    end

    def eos?
      @ieids.empty? and @buff.empty? and not @ungot
    end

    def get
      return if eos?

      if @ungot
        @ungot = false
        return @last.url, @last
      end

      if @buff.empty?
        @buff = Daitss::Package.package_copies @ieids.shift(CHUNK_SIZE)
      end

      @last = @buff.shift

      return @last.url, @last
    end

    def unget
      raise "The unget method only supports one level of unget; unfortunately, two consecutitve ungets have been called on #{self.to_s}" if @ungot
      @ungot = true
    end

    def each
      while not eos?
        yield get
      end
    end

    # closing is just for consistency; really a no-op

    def close
      @closed = true
    end

    def closed?
      @closed
    end

  end # of class DaitssPackageStream

end # of module Streams
