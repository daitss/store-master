require 'datyl/streams'
require 'storage-master/model.rb'

# This file sets up data streams that lists the packages and copies
# that storage-master thinks the silos have.  See pool-stream for data
# streams that list what the silos report as present.

module StorageMasterModel


  class Package

    #    copies table
    #  
    #        column     |            type          |                      modifiers
    #   ----------------+--------------------------+-----------------------------------------------------
    #    id             | integer                  | not null default nextval('copies_id_seq'::regclass)
    #    datetime       | timestamp with time zone |
    #    store_location | character varying(255)   | not null
    #    package_id     | integer                  | not null
    #    pool_id        | integer                  | not null
    #  
    #  
    #    packages table
    #  
    #    column |         type          |                       modifiers
    #   --------+-----------------------+-------------------------------------------------------
    #    id     | integer               | not null default nextval('packages_id_seq'::regclass)
    #    extant | boolean               | default true
    #    ieid   | character varying(50) | not null
    #    name   | character varying(50) | not null


    # package_copies opens the Package class to add one function to help getting a stream of package info.
    #
    # @param [DateTime] before, optional, restricts the returned list to packages stored before the supplied date.
    # @return [Array] list of DataMapper structs of:  package's name  (ordered alphabetically), store_location, ieid

    def self.package_copies  before = nil
      before ||= DateTime.now
      sql = "SELECT packages.name, copies.store_location, packages.ieid " +
              "FROM packages, copies "                                    +
             "WHERE packages.id = copies.package_id "                     +
               "AND copies.datetime < '#{before}' "                       +
          "ORDER BY packages.name"

      repository(:default).adapter.select(sql)
    end

  end # of class Package
end # of module StorageMasterModel

module Streams

  # StorageMasterPackageStream returns information about what the StorageMaster thinks should be on the silos:
  #
  # E20110210_ROGMBP.000   #<struct name="E20110210_ROGMBP.000", store_location="http://one.example.com/.../E20110210_ROGMBP.000", ieid="E20110210_ROGMBP">
  # E20110210_ROGMBP.000   #<struct name="E20110210_ROGMBP.000", store_location="http://two.example.com/.../E20110210_ROGMBP.000", ieid="E20110210_ROGMBP">
  # E20110210_ROIUIC.000   #<struct name="E20110210_ROIUIC.000", store_location="http://one.example.com/.../E20110210_ROIUIC.000", ieid="E20110210_ROIUIC">
  # E20110210_ROIUIC.000   #<struct name="E20110210_ROIUIC.000", store_location="http://two.example.com/.../E20110210_ROIUIC.000", ieid="E20110210_ROIUIC">
  # ...

  class StorageMasterPackageStream

    include CommonStreamMethods

    def initialize before = nil
      @before = before || DateTime.now
      setup
    end

    def rewind
      setup
      self
    end

    def setup
      @buff  = StorageMasterModel::Package.package_copies @before
    end

    def to_s
      "#<#{self.class} IEIDs prior to #{@before}>"
    end

    def eos?
      return false if ungetting?
      return @buff.empty?
    end

    def read
      return if eos?
      return if @buff.empty?
      
      datum = @buff.shift
      return datum.name, datum
    end

  end # of class StorageMasterPackageStream

end # of module Streams
