namespace :java do
  task :upload_java_install_script do
    on roles(fetch(:java_roles)) do |host|
      upload! template('java_install.sh'), download_dir
      execute "chmod u+x #{java_install_script_path}"
    end
  end

  task :install_java do
    on roles(fetch(:java_roles)) do |host|
      execute :sudo, java_install_script_path
    end
  end
end
