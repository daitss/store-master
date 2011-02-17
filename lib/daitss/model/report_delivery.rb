module DaitssModel

  class ReportDelivery
    include DataMapper::Resource

    def self.default_repository_name
      :daitss
    end

    property :id, Serial, :key => true
    property :mechanism, Enum[:email, :ftp], :default => :email

    belongs_to :package
  end
end
