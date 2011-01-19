# -*- mode: ruby; -*-

require 'bundler/setup'

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

ENV['LOG_FACILITY']         ||= nil                   # Logger sets up syslog using the facility code if set, stderr otherwise.

ENV['DATABASE_LOGGING']     ||= nil                   # Log DataMapper queries
ENV['DATABASE_CONFIG_FILE'] ||= '/opt/fda/etc/db.yml' # YAML file that only our group can read, has database information in it.
ENV['DATABASE_CONFIG_KEY']  ||= 'store_master'        # Key into a hash provided by the above file.
			    			      # is potentially a silo.

ENV['BASIC_AUTH_USERNAME']  ||= nil                   # Credentials required to connect to the store-master
ENV['BASIC_AUTH_PASSWORD']  ||= nil                   # service using basic authentication

if ENV['BASIC_AUTH_USERNAME'] or ENV['BASIC_AUTH_PASSWORD']
  use Rack::Auth::Basic, "DAITSS 2.0 Silo" do |username, password|
    username == ENV['BASIC_AUTH_USERNAME'] 
    password == ENV['BASIC_AUTH_PASSWORD']
  end
end

require 'sinatra'
require 'app'

run Sinatra::Application
