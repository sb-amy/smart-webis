module Webistrano
  module Template
    module MagentoQuick
      
      CONFIG = Webistrano::Template::Base::CONFIG.dup.merge({
        :application => 'your_app_name',
        :scm => ':git',
        :deploy_via => ':git_pull',
        :branch => 'master',
        :user => '=====[EDIT ME]=====',
        :password => '=====[EDIT ME]=====',
        :use_sudo => 'false',
        :deploy_to => '=====[EDIT ME]=====',
        :repository => '=====[EDIT ME]=====',
        :domain => '=====[EDIT ME]=====',        
        :mysql_user => '=====[EDIT ME]=====',
        :mysql_pass => '=====[EDIT ME]=====',
        :mysql_host => 'localhost',
        :mysql_db => '=====[EDIT ME]=====',
      })
      CONFIG.delete(:scm_username)
      CONFIG.delete(:scm_password)
      CONFIG.delete(:runner)
      CONFIG.freeze
      
      DESC = <<-'EOS'
        Template for use with Magento projects in SmartOSC.
        This template use git pull strategy for quick deployment, so there will be NO rollback.
      EOS
      
      TASKS = Webistrano::Template::Base::TASKS + <<-'EOS'
      
         namespace :deploy do
           task :restart, :roles => :app, :except => { :no_release => true } do
             # do nothing
           end

           task :start, :roles => :app, :except => { :no_release => true } do
             # do nothing
           end

           task :stop, :roles => :app, :except => { :no_release => true } do
             # do nothing
           end
         end
      EOS
    
    end
  end
end