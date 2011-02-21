require 'datyl/streams'
require 'daitss/model'

module DaitssModel

  class Package

    # Provide a list of all of the package ids sorted by the copy URL.
    # There will be on the order of 10^6 of these

    def self.package_copies_ids  before = DateTime.now

      sql = "SELECT packages.id "                   +
              "FROM packages, aips, copies "        +
             "WHERE packages.id = aips.package_id " +
               "AND aips.id = copies.aip_id "       +
        "AND copies.timestamp < '#{before}' "       +
          "ORDER BY copies.url"

      repository(:daitss).adapter.select(sql)
    end

    # provide a list of data mapper records for selected IEIDs  ordered by the copy URL

    def self.package_copies  ieids
      return [] unless ieids and not ieids.empty?
      sql = "SELECT packages.id AS ieid, copies.url, copies.md5, copies.sha1, copies.size " +
              "FROM packages, aips, copies " +
             "WHERE packages.id = aips.package_id " +
               "AND aips.id = copies.aip_id " +
               "AND packages.id in ('" + ieids.join("', '")  + "') " +
          "ORDER BY copies.url"

      repository(:daitss).adapter.select(sql)
    end

  end # of class Package
end # of module Daitss


module Streams

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
      @ieids  = DaitssModel::Package.package_copies_ids @before
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
         @buff = DaitssModel::Package.package_copies @ieids.shift(CHUNK_SIZE)
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
