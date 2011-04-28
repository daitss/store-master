require 'datyl/streams'
require 'store-master/model.rb'

# This file sets up data streams that lists the packages and copies
# that store-master thinks the silos have.  See pool-stream for data
# streams that list what the silos report as present.

module StoreMasterModel

  class Package

    #  copies table
    #
    #      column     |            type          |                      modifiers
    # ----------------+--------------------------+-----------------------------------------------------
    #  id             | integer                  | not null default nextval('copies_id_seq'::regclass)
    #  datetime       | timestamp with time zone |
    #  store_location | character varying(255)   | not null
    #  package_id     | integer                  | not null
    #  pool_id        | integer                  | not null
    #
    #
    #  packages table
    #
    #  column |         type          |                       modifiers
    # --------+-----------------------+-------------------------------------------------------
    #  id     | integer               | not null default nextval('packages_id_seq'::regclass)
    #  extant | boolean               | default true
    #  ieid   | character varying(50) | not null
    #  name   | character varying(50) | not null


    def self.package_copies_ids before = nil
      before ||= DateTime.now
      sql = "SELECT packages.id "                     +
              "FROM packages, copies "                +
             "WHERE packages.extant "                 +
               "AND packages.id = copies.package_id " +
               "AND copies.datetime < '#{before}' "   +
          "ORDER BY packages.name"

      repository(:store_master).adapter.select(sql)
    end

    def self.package_copies ids
      return [] if not ids or ids.empty?
      sql = "SELECT packages.name, copies.store_location, packages.ieid " +
              "FROM packages, copies "                                    +
             "WHERE packages.id = copies.package_id "                     +
               "AND packages.id in ('" + ids.join("', '")  + "') "        +
          "ORDER BY packages.name"

      repository(:store_master).adapter.select(sql)
    end

  end # of class Package
end # of module StoreMasterModel

module Streams

  # StoreMasterPackageStream returns information about what the StoreMaster thinks should be on the silos:
  #
  # E20110210_ROGMBP.000   #<struct name="E20110210_ROGMBP.000", store_location="http://one.example.com/.../E20110210_ROGMBP.000", ieid="E20110210_ROGMBP">
  # E20110210_ROGMBP.000   #<struct name="E20110210_ROGMBP.000", store_location="http://two.example.com/.../E20110210_ROGMBP.000", ieid="E20110210_ROGMBP">
  # E20110210_ROIUIC.000   #<struct name="E20110210_ROIUIC.000", store_location="http://one.example.com/.../E20110210_ROIUIC.000", ieid="E20110210_ROIUIC">
  # E20110210_ROIUIC.000   #<struct name="E20110210_ROIUIC.000", store_location="http://two.example.com/.../E20110210_ROIUIC.000", ieid="E20110210_ROIUIC">
  # ...

  # TODO: keep the @ids as an array without shifting, keeping an offset, so we can reset it to zero on rewind.

  class StoreMasterPackageStream

    include CommonStreamMethods


    CHUNK_SIZE = 5000

    def initialize before = nil
      @before = before || DateTime.now
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

    # closing is just for consistency; really a no-op

    def close
      @closed = true
    end

    def closed?
      @closed
    end

  end # of class StoreMasterPackageStream

end # of module Streams
