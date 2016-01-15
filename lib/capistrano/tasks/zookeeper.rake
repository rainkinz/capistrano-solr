require 'capistrano/dsl/solr_paths'

include Capistrano::DSL::SolrPaths

# By default only deploy to servers with the solr role
set :zookeeper_roles, :zookeeper

namespace :zookeeper do

  task :prepare_download_dir do
    on roles(fetch(:zookeeper_roles)) do |host|
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
  task :start do
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
  task :stop do
    on roles(fetch(:zookeeper_roles)) do |host|
      execute :sudo, "service #{zookeeper_service_name} stop"
    end
  end

  task :restart do
    invoke 'zookeeper:stop'
    invoke 'zookeeper:start'
  end

  desc 'Sets up a solr instance'
  task :install do
    on roles(fetch(:solr_roles)) do |host|
      info "Deploying solr on #{host} to #{download_dir}"

      invoke 'solr:prepare_download_dir'
      invoke 'solr:upload_java_install_script'
      invoke 'solr:install_java'

      invoke 'solr:create_install_dir'

      invoke 'zookeeper:download_zookeeper'
      invoke 'zookeeper:extract_zookeeper'
      invoke 'zookeeper:configure_zookeeper'
      invoke 'zookeeper:upstart_zookeeper'
      invoke 'zookeeper:start'

      invoke 'solr:download_solr'
      invoke 'solr:extract_solr'
      invoke 'solr:configure_solr_service'
      invoke 'solr:update_solr_service_config'
      invoke 'solr:create_solr_chroot'
    end
  end
end

