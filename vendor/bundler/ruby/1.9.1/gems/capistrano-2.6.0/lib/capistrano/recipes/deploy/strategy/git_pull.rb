require 'capistrano/recipes/deploy/strategy/remote'

module Capistrano
  module Deploy
    module Strategy

      # Implements the deployment strategy that keeps a cached checkout of
      # the source code on each remote server. Each deploy simply updates the
      # cached checkout, and then does a copy from the cached copy to the
      # final deployment location.
      class RemoteCache < Remote
        # Executes the SCM command for this strategy and writes the REVISION
        # mark file to each host.
        def deploy!
          update_deploy_dir
        end

        def check!
          super.check do |d|
            d.remote.writable(deploy_dir())
          end
        end

        private
          def deploy_dir
            File.join(configuration[:deploy_to], "web")
          end

          def update_deploy_dir
            logger.trace "Updating deploy dir via git pull"
            command = "#{source.sync(revision, deploy_dir)}; "
            scm_run(command)
          end
      end
    end
  end
end
