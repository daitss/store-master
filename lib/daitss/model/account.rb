module Daitss

  # This is part of a stripped-down version of the DAITSS core project's model.
  # Accounts are important to the Storage Master as groupings of agents.

  class Account
    include DataMapper::Resource

    def self.default_repository_name
      :daitss
    end

    property  :id,           String, :key => true
    property  :description,  Text
    property  :report_email, String

    has 1..n, :projects, :constraint => :destroy
    has n,    :agents
  end
end
