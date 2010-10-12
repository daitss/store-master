# -*- mode:ruby; -*-

require 'rubygems'
require 'railsless-deploy'
require 'bundler/capistrano'

set :application,  "storemaster"
set :repository,   "ssh://retsina.fcla.edu/home/fischer/repos/store-master.git"
set :use_sudo,     false
set :deploy_to,    "/opt/web-services/sites/#{application}"
set :scm,          "git"
set :user,         "silo"
set :group,        "daitss" 


set :bundle_flags,       "--deployment"
set :bundle_without,      []


def usage(*messages)
  STDERR.puts "Usage: cap deploy -S domain=<target domain>"  
  STDERR.puts messages.join("\n")
  STDERR.puts "You may set the remote user and group similarly (defaults to #{user} and #{group}, respectively)."
  STDERR.puts "If you set the user, you must be able to ssh to the domain as that user."
  STDERR.puts "You may set the branch in a similar manner: -S branch=<branch name> (defaults to #{variables[:branch]})."
  exit
end

usage('The domain was not set (e.g., domain=ripple.fcla.edu).') unless variables[:domain]


role :app, domain

after "deploy:update", "deploy:layout", "deploy:doc", "deploy:restart"

namespace :deploy do

  desc "Touch the tmp/restart.txt file on the target host, which signals passenger phusion to reload the app"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path, 'tmp', 'restart.txt')}"
  end
  
  desc "Create the directory hierarchy, as necessary, on the target host"
  task :layout, :roles => :app do

    # shared directory creation, if necessary:

    pathname = File.join(shared_path, 'diskstore')
    run "mkdir -p #{pathname}"
    run "chmod 2775 #{pathname}"

    # documentation directories

    pathname = File.join(current_path, 'public', 'internals')
    run "mkdir -p #{pathname}"       
    run "chmod -R ug+rwX #{pathname}" 

    # make everything group ownership daitss, for easy maintenance.
   
    run "find #{shared_path} #{release_path} -print0 | xargs -0 chgrp #{group}"
  end
  
  desc "Create documentation in public/internals via a rake task - tries yard, hanna, and rdoc"
  task :doc, :roles => :app do
    run "cd #{current_path}; rake docs"
    run "chmod -R ug+rwX #{File.join(current_path, 'public', 'internals')}"
  end
end
