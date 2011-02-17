module DaitssModel

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
