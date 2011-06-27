# -*- mode: ruby; -*-

require 'bundler/setup'
require 'socket'

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

ENV['LOG_FACILITY']           ||= nil                   # Logger sets up syslog using the facility code if set, stderr otherwise.

ENV['DATABASE_LOGGING']       ||= nil                   # Log DataMapper queries

ENV['DATABASE_CONFIG_FILE']   ||= '/opt/fda/etc/db.yml' # YAML file that only our group can read, has database information in it.
ENV['DATABASE_CONFIG_KEY']    ||= 'store_master'        # Key into a hash provided by the above file.
			      			        # is potentially a silo.
ENV['BASIC_AUTH_USERNAME']    ||= nil                   # Credentials required to connect to the store-master
ENV['BASIC_AUTH_PASSWORD']    ||= nil                   # service using basic authentication

ENV['VIRTUAL_HOSTNAME']       ||= Socket.gethostname    # Used for logging; wish there was a better way of getting this automatically

ENV['MINIMUM_REQUIRED_POOLS'] ||= '2'                   # Required number of pools to store to.  0 turns us into a stub server

require 'sinatra'
require 'app'

run Sinatra::Application
