#
# Cookbook Name:: ceilometer
# Recipe:: ceilometer-compute
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

# this sets up ceilometer on compute nodes (runs the compute agent)

platform_options = node["ceilometer"]["platform"]

platform_options["compute_package_list"].each do |pkg|
  package pkg do
    action :install
    options platform_options["package_overrides"]
  end
end

include_recipe "ceilometer::ceilometer-common"

platform_options["compute_service_list"].each do |svc|
  service svc do
    supports :status => true, :restart => true
    action [ :enable, :start ]
    subscribes :restart, resources(:template => "/etc/ceilometer/ceilometer.conf"), :delayed
  end
end
