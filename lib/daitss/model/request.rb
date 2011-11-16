module Daitss

  # This is part of a stripped-down version of the DAITSS core
  # project's model.  Request is not directly used by the Storage
  # Master service.

  class Request
    include DataMapper::Resource

    def self.default_repository_name
      :daitss
    end

    property :id, Serial, :key => true
    property :note, Text

    property :timestamp, DateTime, :required => true, :default => proc { DateTime.now }
    property :is_authorized, Boolean, :required => true, :default => true
    property :status, Enum[:enqueued, :released_to_workspace, :cancelled], :default => :enqueued
    property :type, Enum[:disseminate, :withdraw, :peek, :d1refresh]

    belongs_to :agent
    belongs_to :package

    def cancel
      self.status = :cancelled
      self.save
    end
  end
end
