module Daitss

  # This is part of a stripped-down version of the DAITSS core
  # project's model. The Storage Master service creates time-stamped events
  # with the following names:
  # 
  #  * fixity failure - one or more of the recent fixity checks computed by a Silo Pool doesn't match what DAITSS has recorded
  #  * fixity success - all of the recent fixity checks for package copies matches what was initially recorded by DAITSS
  #  * integrity failure - one or more copies of a package was missing.


  class Event
    include DataMapper::Resource

    def self.default_repository_name
      :daitss
    end

    property :id,        Serial,   :key => true
    property :name,      String,   :required => true
    property :timestamp, DateTime, :required => true, :default => proc { DateTime.now }
    property :notes,     Text,     :length => 2**32-1
    property :outcome,   String,   :default => "N/A"

    belongs_to :agent
    belongs_to :package
  end

end
