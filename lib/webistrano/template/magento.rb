module Webistrano
  module Template
    module Magento
      
      CONFIG = Webistrano::Template::Base::CONFIG.dup.merge({
        :application => 'your_app_name',
        :copy_exclude => '.git',
        :scm => ':git',
        :deploy_via => ':remote_cache',
        :user => '[NEED CHANGE]deployment_user(SSH login)',
        :password => '[NEED CHANGE]deployment_user(SSH user) password',
        :use_sudo => 'false',
        :deploy_to => '[NEED CHANGE]/path/to/deployment_base',
        :repository => '[NEED CHANGE]git@git.smartosc.com:yourproject.git'        
      })
      CONFIG.delete(:scm_username)
      CONFIG.delete(:scm_password)
      CONFIG.delete(:runner)
      CONFIG.freeze
      
      DESC = <<-'EOS'
        Template for use with Magento projects in SmartOSC.
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