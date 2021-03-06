maintainer       "Rackspace US, Inc."
license          "Apache 2.0"
description      "Installs/Configures ceilometer"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.0.1"
recipe           "ceilometer-infra", ""

%w{ ubuntu }.each do |os|
  supports os
end

%w{ apt database monitoring mysql osops-utils }.each do |dep|
  depends dep
end

depends "keystone", ">= 1.0.17"
