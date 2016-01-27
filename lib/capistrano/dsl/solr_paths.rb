require 'pry'
require 'erb'
require 'tilt'

module Capistrano

  module DSL

    module SolrPaths

      # Name of the directory on the nodes where we install our components,
      # relative to the deploy user directory
      def install_home
        fetch(:install_home, "/opt")
      end

      def solr_install_root
        "#{install_home}/solr"
      end

      def user_home
        File.join("/home", fetch(:user))
      end

      def solr_user
        fetch(:user)
      end

      # The path to download the solr distribution to
      def download_dir
        fetch(:solr_download_path, default_download_dir)
      end

      def default_download_dir
        File.join(user_home, "solr_downloads")
      end

      def zkcli
        File.join(solr_install_dir, "server/scripts/cloud-scripts/zkcli.sh")
      end

      ##
      # Java
      #
      def java_install_script_path
        File.join(download_dir, 'java_install.sh')
      end

      ##
      # Solr Components
      #

      def solr_url
        'http://www.mirrorservice.org/sites/ftp.apache.org/lucene/solr/5.4.0/solr-5.4.0.tgz'
      end

      def solr_path
        File.join(download_dir, File.basename(solr_url))
      end

      def solr_tgz
        File.join(download_dir, File.basename(solr_url))
      end

      def solr_install_dir
        File.join(install_home, File.basename(solr_tgz, '.tgz'))
      end

      def solr_service_name
        fetch(:solr_service_name, "solr")
      end

      def solr_service_script
        File.join("/etc/init.d", solr_service_name)
      end

      ##
      # Zookeeper Components
      #

      def zookeeper_url
        'http://www.mirrorservice.org/sites/ftp.apache.org/zookeeper/zookeeper-3.4.6/zookeeper-3.4.6.tar.gz'
      end

      def zookeeper_tgz
        File.join(download_dir, File.basename(zookeeper_url))
      end

      def zookeeper_install_dir
        File.join(install_home, File.basename(zookeeper_tgz, '.tar.gz'))
      end

      def zookeeper_hosts
        roles(fetch(:zookeeper_roles)).map(&:hostname)
      end

      def zookeeper_service_name
        fetch(:zookeeper_service_name, "zookeeper")
      end

      ##
      # Utilities
      #

      def template(name)
        File.join(Capistrano::Solr.templates_dir, name)
      end

      def upload_template(template_path, remote_path, opts = {})
        template = Tilt.new(template_path)
        io = StringIO.new(template.render(nil, opts))
        upload! io, remote_path
      end

    end

  end
end
