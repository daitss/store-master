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

    [ 'diskstore', 'vendor' ].each do |subdir|
      pathname = File.join(shared_path, subdir)
      run "mkdir -p #{pathname}"
      run "chmod 2775 #{pathname}"
    end

    # make sample silos

    [ '001', '002', '003' ].each do |silo|
      pathname = File.join(shared_path, 'daitssfs', silo)
      run "mkdir -p #{pathname}"       
      run "chmod 2755 #{pathname}" 
    end

    # documentation directories

    pathname = File.join(current_path, 'public', 'internals')
    run "mkdir -p #{pathname}"       
    run "chmod -R ug+rwX #{pathname}" 

    # make everything group ownership daitss, for easy maintenance.
   
    run "find #{shared_path} #{release_path} -print0 | xargs -0 chgrp #{group}"

    # install local gems

    # run "cd #{current_path}; bundle install #{File.join(shared_path, "vendor/bundle")}"   # extract gems if necessary
    # run "cd #{current_path}; bundle --deployment"   # extract gems as necessary


    # This speeds things up considerably having most everything in the
    # shared directory. We cd to where the Gemfile and Gemfile.lock
    # files are, but they DO NOT use our cached stuff under
    # #{current_path}/vendor/bundle/.../cache/
    # 
    #  run "cd #{current_path}; bundle --deployment --path #{File.join(shared_path, "vendor/bundle")}"


    # This at least uses our gems included from repository, but does reinstall them.  
    # Quicker than getting from the net, at least.

    # run "cd #{current_path}; bundle --local --path vendor/bundle"


    # Here's a nasty method - make a link tree into a shared set of directories,
    # so all of the vendor/bundle stuff is in the shared directory, except for
    # the cached gems:

    # shared_target = File.join(shared_path, 'vendor', 'bundle', 'ruby', '1.8')
    # link_dir      = File.join(current_path,'vendor', 'bundle', 'ruby', '1.8')   # this will exist, since we maintain only the cache subdirectory of this in the git repository

    # [ 'bin', 'doc', 'gems', 'specifications'  ].each do |subdir|  # not cache!
    #   realdir = File.join(shared_target, subdir)
    #   symlink = File.join(link_dir, subdir)
    #   run "mkdir -p #{realdir}"
    #   run "chmod 2775 #{realdir}"
    #   run "ln -s #{realdir} #{symlink}"
    # end

    # run "cd #{current_path}; bundle --local --path vendor/bundle"

  end
  
  desc "Create documentation in public/internals via a rake task - tries yard, hanna, and rdoc"
  task :doc, :roles => :app do
    run "cd #{current_path}; rake docs"
    run "chmod -R ug+rwX #{File.join(current_path, 'public', 'internals')}"
  end
end
