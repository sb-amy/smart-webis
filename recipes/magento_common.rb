after   'deploy:update_code', 'magento:setpermissions'
after   'deploy:update_code', 'magento:setconfiguration'
after   'deploy:update_code', 'magento:symlink'
after   'deploy:symlink', 'magento:clearcache'
after   'deploy', 'deploy:cleanup'

def remote_file_exists?(full_path)
  'true' ==  capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
end

namespace :deploy do

  desc "Set up the expected application directory structure on all boxes"
  task :setup, :roles => [:app] do
    run "mkdir -p #{releases_path} #{shared_path} #{shared_path}/config/app/etc #{shared_path}/media #{shared_path}/var"
    run "chmod 755 #{releases_path} #{shared_path} #{shared_path}/config"
    run "chmod -R a+w #{shared_path}/media #{shared_path}/var"
    
    # Protect var directory with .htaccess
    run "echo 'Order deny,allow' > #{shared_path}/var/.htaccess"
    run "echo 'Deny from all'   >> #{shared_path}/var/.htaccess"
    
    #setup custom shared assets.  
    fetch(:custom_shared_dirs, "").split(",").each do |link|
      run "mkdir -p #{shared_path}/#{link}"
    end  
    fetch(:custom_shared_files, "").split(",").each do |link|
      run "touch #{shared_path}/#{link}"
    end

    if remote_file_exists?("#{deploy_to}/web")
        run "mv web web_old"
        run "ln -nfs web_old current"
        run "ln -nfs current web"
        run "mkdir #{shared_path}/stats"
        run "chmod 777 #{shared_path}/stats"

        #Check if already have Magento installed (-> migrate from old Magento)
        if remote_file_exists?("#{current_path}/app/etc/local.xml")
          magento.save_existing_magento
        end
    end

  end

end


namespace :magento do
  desc "Copy media, local.xml, .htaccess from existing Magento installation to shared directory."   
  task :save_existing_magento, :roles => [:app] do
    run "cp -Rfp #{current_path}/media #{shared_path}/"
    run "chmod -R a+w #{shared_path}/media"
    run "cp #{current_path}/app/etc/local.xml #{shared_path}/config/app/etc/local.xml"
	run "cp #{current_path}/.htaccess #{shared_path}/config/htaccess"

    fetch(:custom_shared_dirs, "").split(",").each do |link|
		if remote_file_exists?("#{current_path}/#{link}")
      		run "cp -rT #{current_path}/#{link} #{shared_path}/#{link}"
		end
    end  
    fetch(:custom_shared_files, "").split(",").each do |link|
		if remote_file_exists?("#{current_path}/#{link}")
      		run "cp -T #{current_path}/#{link} #{shared_path}/#{link}"
		end
    end
  end

  desc "Deletes the /app/etc/local.xml file." 
  task :delete_local_xml, :roles => [:app] do 
          run "rm #{current_path}/app/etc/local.xml"
  end 

  desc "Saves the local /app/etc/local.xml file to shared directory. Do not run this unless you have first deleted and ran the install wizard." 
  task :save_local_xml, :roles => [:app] do 
          run "cp #{current_path}/app/etc/local.xml #{shared_path}/config/app/etc/local.xml"
  end 

  desc "Saves the local /app/etc/use_cache.ser file to shared directory. The builder must have privilege to the shared directory." 
  task :save_use_cache_ser, :roles => [:app] do 
          run "cp #{current_path}/app/etc/use_cache.ser #{shared_path}/config/app/etc/"
  end 

  desc "Change rights on folders" 
  task :setpermissions, :roles => [:app] do 
      if fetch(:file_permissions, 'permissive') == "strict" then
        run "chmod -R 0754 #{release_path}"      
        run "chmod -R 0755 #{release_path}/cron.sh"      
        run "chmod -R 0775 #{release_path}/app/etc"        
      else
        run "chmod -R 0755 #{release_path}"      
        run "chmod -R 0755 #{release_path}/cron.sh"      
        run "chmod -R 0775 #{release_path}/app/etc"
      end
  end 
  
  desc 'Set all files and directories in the media directory to writable'
  task :mediapermissions, :roles => [:app] do
    run "find #{shared_path}/media -type d | xargs chmod 777"
    run "find #{shared_path}/media -type f | xargs chmod 666"
  end
  
  desc 'Symlink the shared magento folders'
  task :symlink, :roles => :app do
    #media.
    run "rm -Rf #{release_path}/media"
    run "ln -nfs #{shared_path}/media #{release_path}/media"

    #var.
    run "rm -Rf #{release_path}/var"
    run "ln -nfs #{shared_path}/var  #{release_path}/var"
    
    fetch(:custom_shared_dirs, "").split(",").each do |link|
      run "rm -rf #{latest_release}/#{link}"
      run "ln -nfs #{shared_path}/#{link} #{latest_release}/#{link}"
    end  
    fetch(:custom_shared_files, "").split(",").each do |link|
      run "rm -rf #{latest_release}/#{link}"
      run "ln -s #{shared_path}/#{link} #{latest_release}/#{link}"
    end

    if remote_file_exists?("#{shared_path}/stats")
        run "ln -nfs #{shared_path}/stats  #{release_path}/stats"    
    end
    
  end

  desc 'Copies stages configurations.'
  task :setconfiguration, :roles => :app do
    
     if remote_file_exists?("#{shared_path}/config/app/etc/local.xml")
          run "ln -nfs #{shared_path}/config/app/etc/local.xml #{release_path}/app/etc/local.xml"
    end

    #Copy the SER file for caching. This prevents the deploy from disabling caching.
    if !remote_file_exists?("#{release_path}/app/etc/use_cache.ser")
          run "ln -nfs #{shared_path}/config/app/etc/use_cache.ser #{release_path}/app/etc/"
    end

    #Copy htaccess config.
    if remote_file_exists?("#{shared_path}/config/htaccess")
        run "ln -nfs #{shared_path}/config/htaccess #{release_path}/.htaccess"
    end
    # htaccess backup plan.
    if (!remote_file_exists?("#{release_path}/.htaccess") && remote_file_exists?("#{release_path}/.htaccess.sample"))
        run "mv #{release_path}/.htaccess.sample #{release_path}/.htaccess"
        run "rm -f #{release_path}/.htaccess.*"
    end
    
    #Copy htpasswd config.
    if remote_file_exists?("#{shared_path}/config/htpasswd")
        run "ln -nfs #{shared_path}/config/htpasswd #{release_path}/.htpasswd"
    end
    
    # Robots.txt
    if remote_file_exists?("#{shared_path}/config/robots.txt")
        run "ln -nfs #{shared_path}/config/robots.txt #{release_path}/robots.txt"
    end
  end

  desc 'Displays the builder public key for this machine and generates a new one if not found'
  task :getsshpublickey, :roles => :app do
    
     if !remote_file_exists?("~/.ssh/id_rsa.pub")
          run "ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa"
    end

     if remote_file_exists?("~/.ssh/id_rsa.pub")
          run "cat ~/.ssh/id_rsa.pub"
    end

  end

  desc 'Clear Magento cache.'
  task :clearcache, :roles => :app do
    
    if remote_file_exists?("#{current_path}/var/cache")
      run "rm -rf #{current_path}/var/cache/*"
    else
      run "echo 'var/cache/ does not exist. Magento clearcache aborted.'"
    end

  end

end