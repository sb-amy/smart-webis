after   'deploy:update_code', 'magento:clearcache'

_cset(:web_dir)     { File.join(deploy_to, "web") }
_cset(:upload_dir)     { File.join(deploy_to, "private", "upload") }
_cset(:config_dir)     { File.join(deploy_to, "private", "config") }

def remote_file_exists?(full_path)
  'true' ==  capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
end

namespace :deploy do
  desc "Override default"
  task :finalize_update, :roles => [:app] do
    logger.trace "finalize_update: Do nothing"
  end

  desc "Process symlink"
  task :symlink, :roles => [:app] do
    run "rm -rf #{web_dir}/media"
    run "ln -nfs #{config_dir}/media #{web_dir}/media"    
    
    run "ln -nfs #{config_dir}/local.xml #{web_dir}/app/etc/local.xml"
    
    run "rm -rf #{web_dir}/var"
    run "ln -nfs #{config_dir}/var #{web_dir}/var"
  end

  desc "Create ssh key and neccessary folders"
  task :init, :roles => [:app] do
    run "mkdir -p #{upload_dir} #{config_dir}"
    magento.getsshpublickey
  end

  desc "Checkout code from Git, do DB import and prepare environment for Magento"
  task :setup, :roles => [:app] do
    logger.trace "Initializing Git..."
    run "cd #{web_dir} && git init && git remote add origin #{repository} && git fetch -q"
    deploy.update_code
    magento.init_files
    magento.restore_db
    magento.update_config
  end
end

namespace :magento do
  desc 'Displays the builder public key for this machine and generates a new one if not found'
  task :getsshpublickey, :roles => [:app] do
    if !remote_file_exists?("~/.ssh/id_rsa.pub")
      run "ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa"
    end

    if remote_file_exists?("~/.ssh/id_rsa.pub")
      run "cat ~/.ssh/id_rsa.pub"
    end
  end
  
  desc 'Init Magento config file, folder'
  task :init_files, :roles => [:app] do
    # Backup config.xml
    if remote_file_exists?("#{web_dir}/app/etc/local.xml")
      run "cp -n #{web_dir}/app/etc/local.xml #{config_dir}"
    end

    if remote_file_exists?("#{web_dir}/var")
      run "cp -Rn #{web_dir}/var #{config_dir}/"
    else
      run "mkdir -m 0777 #{config_dir}/var"
    end
    
    if remote_file_exists?("#{upload_dir}/media.tgz")
      run "tar -C #{config_dir} -xzf #{upload_dir}/media.tgz"
    elsif remote_file_exists?("#{web_dir}/media")
      run "cp -Rn #{web_dir}/media #{config_dir}/"
    else
      run "mkdir #{config_dir}/media"
    end
    run "chmod -R a+w #{config_dir}/media"
  end
  
  desc 'Restore DB dump'
  task :restore_db, :roles => [:app] do
    if remote_file_exists?("#{upload_dir}/dump.sql.gz")
      run "gunzip < #{upload_dir}/dump.sql.gz | mysql -h#{mysql_host} -u#{mysql_user} -p#{mysql_pass} #{mysql_db}"
    end
  end
  
  desc 'Update Magento configurations'
  task :update_config, :roles => [:app] do
    #Update local.xml with staging db info
    localxml = "#{config_dir}/local.xml"
    if remote_file_exists?(localxml)
      run "sed -i -e 's@<host>.*<\/host>@<host><![CDATA[#{mysql_host}]]><\/host>@g' #{localxml}"
      run "sed -i -e 's@<username>.*<\/username>@<username><![CDATA[#{mysql_user}]]><\/username>@g' #{localxml}"
      run "sed -i -e 's@<password>.*<\/password>@<password><![CDATA[#{mysql_pass}]]><\/password>@g' #{localxml}"
      run "sed -i -e 's@<dbname>.*<\/dbname>@<dbname><![CDATA[#{mysql_db}]]><\/dbname>@g' #{localxml}"
    end    

    #Update base_url in db with staging domain
    domain = fetch(:domain, '')
    if !domain.start_with?("http://")
      domain = "http://#{domain}"
    end
    if !domain.end_with?("/")
      domain = "#{domain}/"
    end
    run "mysql -h#{mysql_host} -u#{mysql_user} -p#{mysql_pass} #{mysql_db} -e\"UPDATE core_config_data SET value='#{domain}' WHERE path IN ('web/secure/base_url', 'web/unsecure/base_url')\""
  end
  
  desc 'Clear Magento cache.'
  task :clearcache, :roles => :app do
    if remote_file_exists?("#{config_dir}/var/cache")
      run "rm -rf #{config_dir}/var/cache/*"
    else
      logger.trace "var/cache/ does not exist. Magento clearcache aborted."
    end
  end
  
end

