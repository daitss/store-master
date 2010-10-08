require 'store/dm'
require 'store/exceptions'
require 'store/utils'

# First step in storing a new package is to recieve a post for an IEID.

module Store
  class Reservation

    # Given an IEID, create a new name based on it.  We'll use the name as part of a URL

    attr_reader :ieid, :name

    def initialize ieid
      raise Store::BadName, "IEID #{ieid} doesn't meet our naming convention" unless StoreUtils.valid_ieid_name? ieid
      @ieid = ieid
      @name = create_new_name(ieid)
    end

    # Given a name created as a side effect by new, return the associated ieid.
    # Otherwise, return nil.

    def self.lookup_ieid name
      res = DM::Reservation.first(:name => name)
      res.nil? ? nil : res.ieid
    end

    private

    # TODO: this is horribly, horribly slow.

    def create_new_name ieid
      vers = '.000'
      while vers <= '.999' do
        res  = DM::Reservation.create(:name => ieid + vers, :ieid => ieid)
        return res.name if res.saved?
        vers.succ!
      end
      raise Store::DatabaseError, "Can't create a new name for IEID '#{ieid}'."
    end


  end # class Reservation
end # module Store
