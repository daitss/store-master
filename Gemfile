# -*- mode:ruby; -*-

source "http://rubygems.org"

gem 'i18n'
gem 'libxml-ruby', :require => 'libxml'
gem 'data_mapper',         '>= 1.0.0'
gem 'dm-mysql-adapter',    '>= 1.0.0'
gem 'dm-postgres-adapter', '>= 1.0.0'
gem 'builder',             '>= 2.1.0'
gem 'log4r',               '>= 1.1.5'
gem 'sinatra',             '>= 1.0.0'
gem 'sys-filesystem',      '>= 0.3.2'

# dependencies required by daitss2 - way more than store-master ever
# uses; no idea what's actually required, and what could be
# reorganized

gem 'ruby-prof'
gem 'dm-is-list'
gem 'haml'
gem 'nokogiri'
gem 'rake'
gem 'semver',		   '>= 1.0.0'
gem 'rack-ssl-enforcer'
gem 'thor'
gem 'uuid'
gem 'rjb'
gem 'curb'

case RUBY_PLATFORM
when /linux/i
  gem 'sys-proctable', :path => '/opt/ruby-1.8.7/lib/ruby/gems/1.8/gems/sys-proctable-0.9.0-x86-linux/'     # utter bullshit
when /darwin/i
  gem 'sys-proctable', :path => '/Library/Ruby/Gems/1.8/gems/sys-proctable-0.9.0-x86-darwin-8'
else
  gem 'sys-proctable'
end

# development

gem 'rcov',             '>= 0.9.8'    
gem 'ci_reporter',      '>= 1.6.2'
gem 'cucumber',		'>= 0.8.5'
gem 'rspec',		'>= 1.3.0'

