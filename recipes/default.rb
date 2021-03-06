#
# Cookbook Name:: jira
# Recipe:: default
#
# Copyright 2008-2009, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# Manual Steps!
#
# MySQL:
#
#   create database jiradb character set utf8;
#   grant all privileges on jiradb.* to '$jira_user'@'localhost' identified by '$jira_password';
#   flush privileges;

if node['jira']['include_apache']
  include_recipe "runit"
  include_recipe "apache2"
  include_recipe "apache2::mod_rewrite"
  include_recipe "apache2::mod_proxy"
  include_recipe "apache2::mod_proxy_http"
  include_recipe "apache2::mod_ssl"
end

include_recipe "java"

unless FileTest.exists?(node['jira']['install_path'])
  directory Chef::Config[:file_cache_path] do
    recursive true
  end

  directory node['jira']['home'] do
    recursive true
    owner node['jira']['run_user']
  end

  remote_file "jira" do
    path "#{Chef::Config[:file_cache_path]}/jira.tar.gz"
    source "http://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-#{node['jira']['version']}.tar.gz"
  end
  
  execute "untar-jira" do
    cwd Chef::Config[:file_cache_path]
    command "tar zxvf jira.tar.gz"
  end
  
  execute "install-jira" do
    command "mv #{Chef::Config[:file_cache_path]}/atlassian-jira-#{node['jira']['version']}-standalone #{node['jira']['install_path']}"
  end
  
  if node['jira']['database'] == "mysql"
    remote_file "mysql-connector" do
      path "#{Chef::Config[:file_cache_path]}/mysql-connector.tar.gz"
      source "http://downloads.mysql.com/archives/mysql-connector-java-5.1/mysql-connector-java-5.1.6.tar.gz"
    end
  
    execute "untar-mysql-connector" do
      cwd Chef::Config[:file_cache_path]
      command "tar zxvf mysql-connector.tar.gz"
    end
  
    execute "install-mysql-connector" do
      command "cp #{Chef::Config[:file_cache_path]}/mysql-connector-java-5.1.6/mysql-connector-java-5.1.6-bin.jar #{node['jira']['install_path']}/lib"
    end
  end
end

template "#{node[:jira][:install_path]}/atlassian-jira/WEB-INF/classes/jira-application.properties" do
  source "jira-application.properties.erb"
  mode 0644
end

template "#{node[:jira][:install_path]}/dbconfig.xml" do
  source "dbconfig.xml.erb"
  mode 0600
  variables node[:jira]
end

execute "untar-jira" do
  command "chown -R #{node['jira']['run_user']} #{node['jira']['install_path']}"
end

if node['jira']['include_apache']
  template "#{node['apache']['dir']}/sites-available/jira.conf" do
    source "apache.conf.erb"
    mode 0644
    owner "www-data"
  end

  apache_site "jira.conf"
end
