# -*- mode: ruby; -*-

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'daitss/model'            # Daitss
require 'store-master'      # StoreMasterModel

DataMapper::Logger.new(STDERR, :debug)

# testing db:
#
# Daitss.setup_db('/opt/fda/etc/db.yml', 'store_daitss_postgres') 
# Daitss.create_tables

Daitss.setup_db('/opt/fda/etc/db.yml', 'tarchive_daitss')
StoreMasterModel.setup_db('/opt/fda/etc/db.yml', 'store_master_dual_pool')

@sm = Streams::StoreMasterPackageStream.new


