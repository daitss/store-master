module Daitss

  # This is part of a stripped-down version of the DAITSS core
  # project's model.  Project is not directly used by the Storage
  # Master service.

  class Project
    include DataMapper::Resource

    def self.default_repository_name
      :daitss
    end

    property :id, String, :key => true
    property :description, Text

    property :account_id, String, :key => true

    has 0..n, :packages

    belongs_to :account, :key => true
  end

end
