# -*- mode:ruby; -*-

require 'rubygems'
require 'railsless-deploy'
require 'bundler/capistrano'

set :repository,   "http://github.com/daitss/store-master.git"
set :scm,          "git"
set :branch,       "master"

set :use_sudo,     false
set :user,         "daitss"
set :group,        "daitss" 

set :bundle_flags,       "--deployment"   # --deployment is one of the defaults, we explicitly set it to remove --quiet
set :bundle_without,      []


def usage(*messages)
  STDERR.puts "Usage: cap deploy -S target=<host:filesystem>"  
  STDERR.puts messages.join("\n")
  STDERR.puts "You may set the remote user and group similarly (defaults to #{user} and #{group}, respectively)."
  STDERR.puts "If you set the user, you must be able to ssh to the domain as that user."
  STDERR.puts "You may set the branch in a similar manner: -S branch=<branch name> (defaults to #{variables[:branch]})."
  exit
end

usage('The deployment target was not set (e.g., target=ripple.fcla.edu:/opt/web-services/sites/silos).') unless (variables[:target] and variables[:target] =~ %r{.*:.*})

_domain, _filesystem = variables[:target].split(':', 2)

set :deploy_to,  _filesystem
set :domain,     _domain


role :app, domain

# currently I'm building the docs and checking them into git;  bundling yard with 
# the other stuff may make this unecessary.

# after "deploy:update", "deploy:layout", "deploy:doc", "deploy:restart"

after "deploy:update", "deploy:layout", "deploy:restart"

namespace :deploy do

  desc "Touch the tmp/restart.txt file on the target host, which signals passenger phusion to reload the app"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path, 'tmp', 'restart.txt')}"
  end
  
  desc "Create the directory hierarchy, as necessary, on the target host"
  task :layout, :roles => :app do


    # documentation directories now kept in repository
    #
    # pathname = File.join(current_path, 'public', 'internals')
    # run "mkdir -p #{pathname}"       
    # run "chmod -R ug+rwX #{pathname}" 

    # make everything group ownership daitss, for easy maintenance.
   
    run "find #{shared_path} #{release_path} -print0 | xargs -0 chgrp #{group}"
  end
  
  # We're going to try including the docs in the repostitory for now..
  
  # desc "Create documentation in public/internals via a rake task - tries yard, hanna, and rdoc"
  # task :doc, :roles => :app do
  #   run "cd #{current_path}; rake docs"
  #   run "chmod -R ug+rwX #{File.join(current_path, 'public', 'internals')}"
  # end
end
