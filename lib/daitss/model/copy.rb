module Daitss

  class Copy

    include DataMapper::Resource

    def self.default_repository_name
      :daitss
    end

    property :id,        Serial
    property :url,       URI,     :required => true # uncomment after all d1 packages are migrated, , :writer => :private #, :default => proc { self.make_url }
    property :sha1,      String,  :length => 40, :format => %r([a-f0-9]{40}) # uncomment after all d1 packages are migrated, :required => true
    property :md5,       String,  :length => 40, :format => %r([a-f0-9]{32}), :required => true
    property :size,      Integer, :min => 1, :max => (2**63)-1 # uncomment after all d1 packages are migrated,:required => true
    property :timestamp, Time

    belongs_to :aip
  end
end
