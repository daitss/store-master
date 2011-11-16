module Daitss

  # This is part of a stripped-down version of the DAITSS core
  # project's model.  Aip is used by the Storage Master service to
  # determine whether a package has a copy: package => aip => copy.
  # Lack of an aip means the package was not ingested.

  class Aip
    include DataMapper::Resource

    def self.default_repository_name
      :daitss
    end

    XML_SIZE = 2**32-1

    property :id,             Serial
    property :xml,            Text,    :required => true, :length => XML_SIZE
    property :xml_errata,     Text,    :required => false
    property :datafile_count, Integer, :min => 1 # uncomment after all d1 packages are migrated, :required => true

    belongs_to :package
    has 0..1,  :copy          # 0 if package has been withdrawn, otherwise, 1

  end

end
