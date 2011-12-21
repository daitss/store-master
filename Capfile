# -*- mode:ruby; -*-
#
#  Set deploy target host/filesystem 
#
#  cap deploy -S target=ripple.fcla.edu:/opt/web-services/sites/storemaster 
#
#  Defaults to install as daitss:daitss, you can over-ride user and group settings using -S who=user:group

require 'rubygems'
require 'railsless-deploy'
require 'bundler/capistrano'

set :repository,   "git@github.com:daitss/store-master.git"
set :scm,          "git"
set :branch,       "master"

set :use_sudo,     false
set :user,         "daitss"
set :group,        "daitss" 

set :keep_releases, 5   # default is 5

set :bundle_flags,        "--deployment"   # --deployment is one of the defaults, we explicitly set it to remove the default --quiet
set :bundle_without,      []

# set :branch do
#   default_tag = `git tag`.split("\n").last
#   tag = Capistrano::CLI.ui.ask "Tag to deploy (make sure to push the tag first): [#{default_tag}] "
#   tag = default_tag if tag.empty?
#   tag
# end


def usage(*messages)
  STDERR.puts "Usage: cap deploy -S target=<host:filesystem>"  
  STDERR.puts messages.join("\n")
  STDERR.puts "You may set the remote user and group by using -S who=<user:group>. Defaults to #{user}:#{group}."
  STDERR.puts "If you set the user, you must be able to ssh to the target host as that user."
  STDERR.puts "You may set the branch in a similar manner: -S branch=<branch name> (defaults to #{variables[:branch]})."
  exit
end

usage('The deployment target was not set (e.g., target=ripple.fcla.edu:/opt/web-services/sites/silos).') unless (variables[:target] and variables[:target] =~ %r{.*:.*})

_domain, _filesystem = variables[:target].split(':', 2)

set :deploy_to,  _filesystem
set :domain,     _domain

if (variables[:who] and variables[:who] =~ %r{.*:.*})
  _user, _group = variables[:who].split(':', 2)
  set :user,  _user
  set :group, _group
end

role :app, domain

after "deploy:update", "deploy:layout", "deploy:cleanup"

namespace :deploy do

  desc "Update files and directories target host, granting broad privleges to members of the group"
  task :layout, :roles => :app do
    run "find #{shared_path} #{release_path} -print0 | xargs -0 chgrp #{group}"
    run "find #{shared_path} #{release_path} -type d -print0 | xargs -0 chmod g+swrx"
  end
  
end
