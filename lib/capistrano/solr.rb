require "capistrano/solr/version"
load File.expand_path("../tasks/solr.rake", __FILE__)
load File.expand_path("../tasks/zookeeper.rake", __FILE__)

module Capistrano
  module Solr
    def self.gem_root
      File.expand_path("../../../", __FILE__)
    end

    def self.templates_dir
      File.join(gem_root, "templates")
    end
  end
end
