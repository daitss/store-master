require 'store-master/model'

module  StoreMasterModel

  include StoreMaster

  # For reserving names for URLs based on IEIDs.

  class Reservation
    include DataMapper::Resource

    def self.default_repository_name
      StoreMasterModel::REPOSITORY_NAME
    end

    property   :id,         Serial
    property   :ieid,       String,   :required => true, :index => true, :length => (16..16)
    property   :name,       String,   :required => true, :index => true, :length => (20..20) # unique name, used as part of a url

    validates_uniqueness_of :name

    def self.find_ieid name
      res = first(:name => name)
      raise NoReservation, "Can't find a reservation for #{name}: make a reservation using an IEID first"  unless res
      res.ieid
    end

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
