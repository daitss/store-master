require 'store-master/model'

module StoreMaster
  
  class PackageXmlReport

    def initialize url_prefix
      @url_prefix = url_prefix
    end

    def each
      yield "<packages location=\"#{StoreUtils.xml_escape(@url_prefix)}\" time=\"#{DateTime.now.to_s}\">\n"
      StoreMasterModel::Package.list do |pkg|
        yield  '  <package name="'  + StoreUtils.xml_escape(pkg.name)                          + '" '  +
                      'location="'  + StoreUtils.xml_escape([@url_prefix, pkg.name].join('/')) + '" '  +
                          'ieid="'  + StoreUtils.xml_escape(pkg.ieid)                          + '"/>' + "\n"
      end
      yield "</packages>\n"
    end

  end # of PackageXmlReport


  class PackageCsvReport

    def initialize url_prefix
      @url_prefix = url_prefix
    end
    
    def each
      yield '"name","location","ieid"' + "\n"
      StoreMasterModel::Package.list do |pkg|
        yield [ pkg.name, [@url_prefix, pkg.name].join('/'), pkg.ieid ].map { |e| StoreUtils.csv_escape(e) }.join(',') + "\n"
      end
    end

  end # of PackageCsvReport

end
