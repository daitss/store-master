module DaitssModel

  class Batch
    include DataMapper::Resource

    def self.default_repository_name
      :daitss
    end

    property :id,       String, :key => true
    has n,   :packages
  end

end
