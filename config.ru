# -*- mode: ruby; -*-

require 'bundler/setup'

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

ENV['LOG_FACILITY']         ||= nil                   # Logger sets up syslog using the facility code if set, stderr otherwise.

ENV['DATABASE_CONFIG_FILE'] ||= '/opt/fda/etc/db.yml' # YAML file that only our group can read, has database information in it.
ENV['DATABASE_CONFIG_KEY']  ||= 'store_master'        # Key into a hash provided by the above file.
			    			      # is potentially a silo.

require 'sinatra'
require 'app'

run Sinatra::Application
