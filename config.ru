# -*- mode: ruby; -*-

require 'rubygems'
require 'bundler/setup'
p "ruby version=#{RUBY_VERSION}"
require 'debugger'
#$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
#$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), './'))
#$LOAD_PATH.unshift File.expand_path(File.join('../'))
$LOAD_PATH.unshift File.join(File.dirname(__FILE__))
$LOAD_PATH.each_with_index {|z,i| p "i=#{i}  z=#{z}"}

require 'sinatra'
require 'app'

run Sinatra::Application
