require 'storage-master/model'

module StorageMaster
  

  # For returning an XML document listing all of the packages; ordered alphabetically by package name (IEID)
  #
  # <packages location="http://storage-master.fda.fcla.edu:70/packages" time="2011-11-15T18:01:59-05:00">
  #    <package name="E101W4TQQ_VGD9QW.000" location="http://storage-master.fda.fcla.edu:70/packages/E101W4TQQ_VGD9QW.000" ieid="E101W4TQQ_VGD9QW"/>
  #    <package name="E1028UPQR_TDDG2R.000" location="http://storage-master.fda.fcla.edu:70/packages/E1028UPQR_TDDG2R.000" ieid="E1028UPQR_TDDG2R"/>
  #    ...
  # </packages>

  class PackageXmlReport

    # Initialize a StorageMaster::PackageXmlReport object by using the URI prefix that will specify a package location
    #
    # @param [String] url_prefix, the prefix used to construct the URL locations of the packages.
    # @return [String] the report object

    def initialize url_prefix
      @url_prefix = url_prefix
    end

    # yield each line of the XML document in turn

    def each
      yield "<packages location=\"#{StoreUtils.xml_escape(@url_prefix)}\" time=\"#{DateTime.now.to_s}\">\n"
      StorageMasterModel::Package.list do |pkg|
        yield  '  <package name="'  + StoreUtils.xml_escape(pkg.name)                          + '" '  +
                      'location="'  + StoreUtils.xml_escape([@url_prefix, pkg.name].join('/')) + '" '  +
                          'ieid="'  + StoreUtils.xml_escape(pkg.ieid)                          + '"/>' + "\n"
      end
      yield "</packages>\n"
    end

  end # of PackageXmlReport


  # For returning a CSV document that lists all of the packages managed by this service; ordered alphabetically by package name (IEID)
  #
  #  "name","location","ieid"
  #  "E101W4TQQ_VGD9QW.000","http://storage-master.fda.fcla.edu:70/packages/E101W4TQQ_VGD9QW.000","E101W4TQQ_VGD9QW"
  #  "E1028UPQR_TDDG2R.000","http://storage-master.fda.fcla.edu:70/packages/E1028UPQR_TDDG2R.000","E1028UPQR_TDDG2R"
  #  "E104GJTXL_KZQB6L.000","http://storage-master.fda.fcla.edu:70/packages/E104GJTXL_KZQB6L.000","E104GJTXL_KZQB6L"
  #  "E1095RV78_SZTIN2.000","http://storage-master.fda.fcla.edu:70/packages/E1095RV78_SZTIN2.000","E1095RV78_SZTIN2"
  # ...

  class PackageCsvReport

    # Initialize a StorageMaster::PackageCsvReport object by using the url prefix that will specify a package location
    #
    # @param [String] url_prefix, the prefix used to construct the URL locations of the packages.
    # @return [String] the report object

    def initialize url_prefix
      @url_prefix = url_prefix
    end


    # yield each line of the CSV document in turn

    def each
      yield '"name","location","ieid"' + "\n"
      StorageMasterModel::Package.list do |pkg|
        yield [ pkg.name, [@url_prefix, pkg.name].join('/'), pkg.ieid ].map { |e| StoreUtils.csv_escape(e) }.join(',') + "\n"
      end
    end

  end # of PackageCsvReport

end
