module DaitssModel

  # represents an admin log entry

  class Entry
    include DataMapper::Resource

    def self.default_repository_name
      :daitss
    end

    property :id,        Serial
    property :timestamp, DateTime, :required => true, :default => proc { DateTime.now }
    property :message,   Text,     :required => true
  end

end
