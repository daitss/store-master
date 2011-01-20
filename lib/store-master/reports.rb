require 'store-master/data-model'

module StoreMaster
  
  class PackageXmlReport
    include Enumerable

    @url_prefix = nil

    def initialize url_prefix
      @url_prefix = url_prefix
    end

    def each
      yield "<packages location=\"#{StoreUtils.xml_escape(@url_prefix)}\" time=\"#{DateTime.now.to_s}\">\n"
      DataModel::Package.all(:order => [ :name.asc ], :extant => true).each do |rec|
        yield  '  <package name="'  + StoreUtils.xml_escape(rec.name)                          + '" '  +
                      'location="'  + StoreUtils.xml_escape([@url_prefix, rec.name].join('/')) + '" '  +
                          'ieid="'  + StoreUtils.xml_escape(rec.ieid)                          + '"/>' + "\n"
      end
      yield "</packages>\n"
    end
  end # of PackageXmlReport


  class PackageCsvReport
    include Enumerable

    @url_prefix  = nil
    
    def initialize url_prefix
      @url_prefix = url_prefix
    end
    
    def each
      yield '"name","location","ieid"' + "\n"
      DataModel::Package.all(:order => [ :name.asc ], :extant => true).each do |rec|
        yield [rec.name, [@url_prefix, rec.name].join('/'), rec.ieid].map { |e| StoreUtils.csv_escape(e) }.join(',') + "\n"
      end
    end
  end # of PackageCsvReport

end
