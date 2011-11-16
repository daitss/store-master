# TODO: this class should take on more responsibilities, including constructing
# a URL and, once used, marking it as unavailable.  Right now those functions are
# spread around in an ad-hoc manner,

require 'storage-master/exceptions'
require 'storage-master/model'

module  StorageMasterModel

  # StorageMasterModel::Reservation is used for reserving names for URLs based on IEIDs.
  #
  # The client protocol for interacting with the Storage Master service requires the
  # client POST an IEID to a specific URL, /reserve/.  This class takes care to create
  # a new unique name for the IEID, which is used elsewhere for constructing the URL.
  #
  # If given an IEID, say, of E20120101_AAAZZZ, say, we'll construct a name like
  # E20120101_AAAZZZ.000.

  class Reservation
    include DataMapper::Resource
    include StorageMaster

    # def self.default_repository_name
    #   :store_master
    # end

    property   :id,         Serial
    property   :ieid,       String,   :required => true, :index => true, :length => (16..16)
    property   :name,       String,   :required => true, :index => true, :length => (20..20) # unique name, used as part of a url

    validates_uniqueness_of :name

    # Reservations.find_ieid - given a reserved name, find its associated ieid.
    #
    # @param [String] name, a previously constructed string for an IEID
    # @return [Strng] the associated IEID.
    
    def self.find_ieid name
      res = first(:name => name)
      raise NoReservation, "Can't find a reservation for #{name}: make a reservation using an IEID first"  unless res
      res.ieid
    end

    # Reservations.make - given an IEID, construct a new unique name for it
    #
    # @param [String] ieid, an IEID for which we'll construct a new name

    def self.make ieid

      raise NoIEID, "Missing expected parameter 'ieid'."               unless ieid
      raise BadName, "IEID #{ieid} doesn't meet our naming convention" unless StoreUtils.valid_ieid_name? ieid

      last = all(:ieid => ieid).map { |rec| rec.name.sub(/^#{ieid}/, '') }.sort.pop
      vers = last ? last.succ! : '.000'

      while vers <= '.999' do
        res  = create(:name => ieid + vers, :ieid => ieid)
        return res.name if res.saved?
        vers.succ!
      end
      raise DataBaseError, "Can't create a new name for IEID '#{ieid}'."
    end
  end

end
