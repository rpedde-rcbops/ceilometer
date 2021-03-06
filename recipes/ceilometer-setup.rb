#
# Cookbook Name:: ceilometer
# Recipe:: ceilometer-setup
#
# Copyright 2013, Rackspace US, Inc.
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

# this not only does setup, but lays down the infra components,
# too -- api, collector, etc.
#

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

platform_options = node["ceilometer"]["platform"]

if node["developer_mode"]
  node.set_unless["ceilometer"]["db"]["password"] = "ceilometer"
else
  node.set_unless["ceilometer"]["db"]["password"] = secure_password
end

# set a secure ceilometer metering secret
node.set_unless["ceilometer"]["metering_secret"] = secure_password

# set a secure ceilometer service password
node.set_unless["ceilometer"]["service_pass"] = secure_password

include_recipe "mysql::client"
include_recipe "mysql::ruby"

ks_admin_endpoint = get_access_endpoint("keystone-api", "keystone", "admin-api")

keystone = get_settings_by_role("keystone", "keystone")
keystone_admin_user = keystone["admin_user"]
keystone_admin_password = keystone["users"][keystone_admin_user]["password"]
keystone_admin_tenant = keystone["users"][keystone_admin_user]["default_tenant"]

ceilometer_api = get_bind_endpoint("ceilometer", "api")

mysql_info = create_db_and_user("mysql",
                                node["ceilometer"]["db"]["name"],
                                node["ceilometer"]["db"]["username"],
                                node["ceilometer"]["db"]["password"])

# register the service
keystone_service "Register Ceilometer Service" do
  auth_host ks_admin_endpoint["host"]
  auth_port ks_admin_endpoint["port"]
  auth_protocol ks_admin_endpoint["scheme"]
  api_ver ks_admin_endpoint["path"]
  auth_token keystone["admin_token"]
  service_name "ceilometer"
  service_type "metering"
  service_description "Ceilometer Service"
  action :create
end

# register the endpoint
keystone_endpoint "Register Ceilometer Endpoint" do
  auth_host ks_admin_endpoint["host"]
  auth_port ks_admin_endpoint["port"]
  auth_protocol ks_admin_endpoint["scheme"]
  api_ver ks_admin_endpoint["path"]
  auth_token keystone["admin_token"]
  service_type "metering"
  endpoint_region "RegionOne"
  endpoint_adminurl ceilometer_api["uri"]
  endpoint_internalurl ceilometer_api["uri"]
  endpoint_publicurl ceilometer_api["uri"]
  action :create
end

# register the service user
keystone_user "Register Service User" do
  auth_host ks_admin_endpoint["host"]
  auth_port ks_admin_endpoint["port"]
  auth_protocol ks_admin_endpoint["scheme"]
  api_ver ks_admin_endpoint["path"]
  auth_token keystone["admin_token"]
  tenant_name node["ceilometer"]["service_tenant_name"]
  user_name node["ceilometer"]["service_user"]
  user_pass node["ceilometer"]["service_pass"]
  user_enabled "1"
  action :create
end

# grant the role
keystone_role "Grant Ceilometer service role" do
  auth_host ks_admin_endpoint["host"]
  auth_port ks_admin_endpoint["port"]
  auth_protocol ks_admin_endpoint["scheme"]
  api_ver ks_admin_endpoint["path"]
  auth_token keystone["admin_token"]
  tenant_name node["ceilometer"]["service_tenant_name"]
  user_name node["ceilometer"]["service_user"]
  role_name node["ceilometer"]["service_role"]
  action :grant
end


# service and package list probably needs to be split
platform_options["infra_package_list"].each do |pkg|
  package pkg do
    action :install
    options platform_options["package_overrides"]
  end
end

include_recipe "ceilometer::ceilometer-common"

execute "ceilometer db sync" do
  command "ceilometer-dbsync"
  user "ceilometer"
  group "ceilometer"
  action :run
end

platform_options["infra_service_list"].each do |svc|
  service svc do
    supports :status => true, :restart => true
    action [ :enable, :start ]
    subscribes :restart, resources(:template => "/etc/ceilometer/ceilometer.conf"), :delayed
  end
end
