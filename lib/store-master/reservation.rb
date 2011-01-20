require 'store-master/dm'
require 'store-master/exceptions'
require 'store-master/utils'

# First step in storing a new package is to recieve a post for an IEID.

module StoreMaster
  class Reservation

    # Given an IEID, create a new name based on it.  We'll use the name as part of a URL

    attr_reader :ieid, :name


    # Given a name created as a side effect by new, return the associated ieid.
    # Otherwise, return nil.

    def self.lookup_ieid name
      DM::Reservation.lookup_ieid name
    end

    private

    # TODO: this is horribly, horribly slow.

    def self.make ieid
      DM::Reservation.make ieid
    end


  end # class Reservation
end # module StoreMaster
