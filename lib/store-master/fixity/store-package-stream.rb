require 'datyl/streams'
require 'store-master/model.rb'
# This file sets up data streams that lists the packages and copies that store-master thinks the silos have.
# See pool-stream for data streams that list what the silos report as present.

module StoreMasterModel

  class Package

    def self.package_copies_ids  before = DateTime.now
      sql = "SELECT packages.id " +
              "FROM packages, copies " +
             "WHERE packages.extant " +
               "AND packages.id = copies.package_id " +
               "AND copies.datetime < '#{before}' " +
          "ORDER BY packages.name"

      repository(:store_master).adapter.select(sql)
    end

    def self.package_copies ids
      return [] if not ids or ids.empty?
      sql = "SELECT packages.name, copies.store_location, packages.ieid " +
              "FROM packages, copies " +
             "WHERE packages.id = copies.package_id " +
               "AND packages.id in ('" + ids.join("', '")  + "') " 
          "ORDER BY packages.name"

      repository(:store_master).adapter.select(sql)
    end

  end # of class Package
end # of module StoreMasterModel

module Streams
  
  class StoreMasterPackageStream

    CHUNK_SIZE = 1000  # TODO: try large size, real small size, then compare output
    
    # TODO: we might be better off maintaining an index into @ieids and keeping it around, rather than shifting
    # materials off and having to re-create it.  We'll see after how it's used in practice.

    def initialize before = DateTime.now
      @before = before
      setup
    end

    def rewind
      setup
      self
    end

    def setup
      @ids    = StoreMasterModel::Package.package_copies_ids @before
      @last   = nil
      @buff   = []      
      @closed = false
      @ungot  = false
    end

    def to_s
      "#<#{self.class}##{self.object_id} IEIDs prior to #{@before}>"
    end

    def eos?
      @ids.empty? and @buff.empty? and not @ungot
    end

    def get
      return if eos?

      if @ungot
        @ungot = false
        return @last.name, @last
      end

      if @buff.empty? 
        @buff = StoreMasterModel::Package.package_copies @ids.shift(CHUNK_SIZE) 
      end

      @last = @buff.shift
      return @last.name, @last
    end

    def unget
      if @ungot
        raise "The unget method only supports one level of unget; unfortunately, two consecutitve ungets have been called on #{self.to_s}"
      end
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

  end # of class StoreMasterPackageStream
end # of module Streams
