require 'capistrano/dsl/solr_paths'

include Capistrano::DSL::SolrPaths

namespace :load do
  task :defaults do
    puts "Loading defaults"
  end
end

# By default only deploy to servers with the solr role
set :solr_roles, :solr
set :zookeeper_roles, :zookeeper
set :solr_num_shards, 2

namespace :solr do

  task :setup_sudoers do
  end

  task :prepare_download_dir do
    on roles(fetch(:solr_roles)) do |host|
      if test "[ -d #{download_dir} ]"
        info "#{download_dir} already exist"
      else
        execute :mkdir, download_dir
      end
    end
  end

  task :upload_java_install_script do
    on roles(fetch(:solr_roles)) do |host|
      upload! template('java_install.sh'), download_dir
      execute "chmod u+x #{java_install_script_path}"
    end
  end

  task :install_java do
    on roles(fetch(:solr_roles)) do |host|
      execute :sudo, java_install_script_path
    end
  end

  task :download_solr do
    on roles(fetch(:solr_roles)) do |host|
      if test "[ -f #{solr_path} ]"
        info "Already downloaded solr to #{solr_path}"
      else
        within download_dir do
          execute "cd #{download_dir}; wget --no-verbose #{solr_url}"
        end
      end
    end
  end

  task :download_zookeeper do
    on roles(fetch(:zookeeper_roles)) do |host|
      if test "[ -f #{zookeeper_tgz} ]"
        info "Already downloaded zookeeper to #{zookeeper_tgz}"
      else
        within download_dir do
          execute "cd #{download_dir}; wget --no-verbose #{zookeeper_url}"
        end
      end
    end
  end

  task :extract_zookeeper do
    on roles(fetch(:zookeeper_roles)) do |host|
      execute "cd #{install_home}; tar xf #{zookeeper_tgz}"
    end
  end

  task :create_install_dir do
    on roles(fetch(:solr_roles)) do |host|
      execute :sudo, "sudo mkdir -p #{install_home}"
      execute :sudo, "sudo chown -R #{fetch(:user)} #{install_home}"
    end

    on roles(fetch(:zookeeper_roles)) do |host|
      execute :sudo, "sudo mkdir -p #{install_home}"
      execute :sudo, "sudo chown -R #{fetch(:user)} #{install_home}"
    end
  end

  task :configure_zookeeper do
    zk_id = 0
    on roles(fetch(:zookeeper_roles)) do |host|
      # Write the zookeeper node id to the my_id file
      within zookeeper_install_dir do
        execute("cd #{zookeeper_install_dir}; mkdir -p data")
        execute "cd #{zookeeper_install_dir}; echo #{zk_id} > data/myid"
        context = { hosts: zookeeper_hosts, path: zookeeper_install_dir }
        upload_template(template('zoo.cfg.erb'),
                        File.join(zookeeper_install_dir, 'conf', 'zoo.cfg'),
                        context)
        zk_id = zk_id + 1
      end
    end
  end

  desc "Write an Upstart script for ZooKeeper"
  task :upstart_zookeeper do

    on roles(fetch(:zookeeper_roles)) do |host|
      context = {
        user: solr_user,
        group: solr_user,
        path: zookeeper_install_dir
      }

      tmp_path  = "/tmp/#{zookeeper_service_name}.conf"
      upstart_path = "/etc/init/#{zookeeper_service_name}.conf"
      upload_template(template('zookeeper_upstart.conf.erb'),
                      tmp_path,
                      context)
      execute :sudo, "mv #{tmp_path} #{upstart_path}"
    end
  end

  desc "Start up zookeeper"
  task :start_zookeeper do
    on roles(fetch(:zookeeper_roles)) do |host|
      status = capture("service #{zookeeper_service_name} status")
      if status =~ /running/
        info "Zookeeper already running"
      else
        execute :sudo, "service #{zookeeper_service_name} start"
      end
    end
  end

  desc "Stop up zookeeper on all nodes"
  task :stop_zookeeper do
    on roles(fetch(:zookeeper_roles)) do |host|
      execute :sudo, "service #{zookeeper_service_name} stop"
    end
  end


  task :extract_solr do
    on roles(fetch(:solr_roles)) do |host|
      execute "cd #{install_home}; tar xf #{solr_tgz}"
    end
  end

  # Effectively install solr as a service on the node
  task :configure_solr_service do
    on roles(fetch(:solr_roles)) do |host|
      within download_dir do
        if test "[ -f #{solr_service_script} ]"
          info "#{solr_service_name} already installed at #{solr_service_script}"
        else
          solr_install_script = "#{File.basename(solr_tgz, '.tgz')}/bin/install_solr_service.sh"
          execute("cd #{download_dir}; tar xzf #{solr_tgz} #{solr_install_script} --strip-components=2")

          # Usage: install_solr_service.sh path_to_solr_distribution_archive OPTIONS
          # The first argument to the script must be a path to a Solr distribution archive, such as solr-5.0.0.tgz
          # (only .tgz or .zip are supported formats for the archive)
          # Supported OPTIONS include:
          # -d     Directory for live / writable Solr files, such as logs, pid files, and index data; defaults to /var/solr
          # -i     Directory to extract the Solr installation archive; defaults to /opt/
          #      The specified path must exist prior to using this script.
          # -p     Port Solr should bind to; default is 8983
          # -s     Service name; defaults to solr
          # -u     User to own the Solr files and run the Solr process as; defaults to solr
          #      This script will create the specified user account if it does not exist.
          # -f     Upgrade Solr. Overwrite symlink and init script of previous installation.
          execute :sudo, "cd #{download_dir}; sudo ./install_solr_service.sh #{solr_tgz} -f -s #{solr_service_name} -u #{solr_user}"

          # Stop the service
          execute :sudo, solr_service_script, "stop"
        end
      end
    end
  end

  task :update_solr_service_config do
    on roles(fetch(:solr_roles)) do |host|
      # Update the config
      zk_host = zookeeper_hosts.map {|ip| "#{ip}:2181" }.join(',')
      zk_host = "#{zk_host}/solr"
      config = {
        :heap_size => "512m",
        :zk_host => "ZK_HOST=#{zk_host}",
        :zk_client_timeout => 'ZK_CLIENT_TIMEOUT="15000"',
        :solr_home_dir => solr_home_dir,
        :solr_pid_dir => solr_pid_dir,
        :solr_logs_dir => solr_logs_dir,
        :solr_port => solr_port
      }

      tmp_path = "/tmp/#{solr_service_name}.in.sh"
      upload_template(
        template('solr.in.sh.erb'),
        tmp_path,
        config
      )
      solr_servce_config = "/etc/default/#{solr_service_name}.in.sh"
      execute :sudo, "mv", tmp_path, solr_servce_config
      execute :sudo, "chown", solr_user, solr_servce_config
      execute :sudo, "chmod u+x #{solr_servce_config}"
    end
  end

  task :create_solr_chroot do
    on roles(fetch(:solr_roles))[0] do |host|
      zkcli = File.join(solr_install_dir, "server/scripts/cloud-scripts/zkcli.sh")
      if capture("#{zkcli} -zkhost #{zookeeper_hosts.join(',')} -cmd list") =~ /\/solr/
        info "Already create /solr in zookeeper"
      else
        info "Creating /solr node in zookeeper"
        execute "#{zkcli} -zkhost #{zookeeper_hosts.join(',')} -cmd makepath /solr"
      end
    end
  end

  desc "Gets the status of the solr service"
  task :solr_status do
    on roles(fetch(:solr_roles)) do
      puts capture(:sudo, "/etc/init.d/#{solr_service_name} status; true")
    end
  end

  desc "Stops solr on all configured nodes"
  task :stop_solr do
    on roles(fetch(:solr_roles)) do |host|
      execute :sudo, solr_service_script, "stop", raise_on_non_zero_exit: false
    end
  end

  desc "Stops solr on all configured nodes"
  task :start_solr do
    on roles(fetch(:solr_roles)) do |host|
      execute :sudo, solr_service_script, "start"
    end
  end

  task :restart_solr do
    invoke "solr:stop_solr"
    invoke "solr:start_solr"
  end

  desc 'Sets up a solr instance'
  task :install do
    on roles(fetch(:solr_roles)) do |host|
      info "Deploying solr on #{host} to #{download_dir}"

      invoke 'solr:prepare_download_dir'
      invoke 'solr:upload_java_install_script'
      invoke 'solr:install_java'

      invoke 'solr:create_install_dir'

      invoke 'solr:download_zookeeper'
      invoke 'solr:extract_zookeeper'
      invoke 'solr:configure_zookeeper'
      invoke 'solr:upstart_zookeeper'
      invoke 'solr:start_zookeeper'

      invoke 'solr:download_solr'
      invoke 'solr:extract_solr'
      invoke 'solr:configure_solr_service'
      invoke 'solr:update_solr_service_config'
      invoke 'solr:create_solr_chroot'
      invoke 'solr:restart_solr'
    end
  end
end

