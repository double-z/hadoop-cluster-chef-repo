# Copyright 2011, Outbrain, Inc.
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

# Install the Cloudera repository.
case node[:platform]
  when "ubuntu","debian"
    apt_repository "cloudera-cdh3" do
      uri "http://archive.cloudera.com/debian"
      components ["maverick-cdh3", "contrib"]
      deb_src "true"
      key "http://archive.cloudera.com/debian/archive.key"
	  notifies :run, resources(:execute => "apt-get update"), :immediately
    end
  when "redhat","centos","fedora","scientific"
    cookbook_file "/etc/yum.repos.d/cloudera-cdh3.repo" do
      owner "root"
      group "root"
      mode "0644"
      source "cloudera-cdh3.repo"
    end
  end

# Install the hadoop core package.  All other recipes rely on this.
package "hadoop-0.20" do
  action :install
  version node[:Hadoop][:Version]
  options "--force-yes"
end

# Install the slave processes on every node
package "hadoop-0.20-datanode" do
  action :install
  version node[:Hadoop][:Version]
  options "--force-yes"
end
package "hadoop-0.20-tasktracker" do
  action :install
  version node[:Hadoop][:Version]
  options "--force-yes"
end

# Ensure the hadoop disks have been built
cookbook_file "/tmp/buildHadoopDisks.sh" do
  source "buildHadoopDisks.sh"
  owner "root"
  group "root"
  backup false
  mode "0755"
end
execute "buildHadoopDisks" do
  command "/tmp/buildHadoopDisks.sh"
  action :run
end


# The only services we ever want to automatically restart upon a config change
# are these two so we define them up here, but don't start them.
service "hadoop-0.20-datanode" do
  supports :status => true, :start => true, :stop => true, :restart => true
end
service "hadoop-0.20-tasktracker" do
  supports :status => true, :start => true, :stop => true, :restart => true
end


# Drop the Hadoop configuration on the target host.  Even if we don't install
# Hadoop daemons clients that need the libraries and config can just get this
# recipe.
template "/etc/hadoop/conf/core-site.xml" do
  owner "root"
  group "hadoop"
  mode "0644"
  source "core-site.xml.erb"
  notifies :restart, resources(:service => "hadoop-0.20-datanode")
  notifies :restart, resources(:service => "hadoop-0.20-tasktracker")
end

template "/etc/hadoop/conf/hdfs-site.xml" do
  owner "root"
  group "hadoop"
  mode "0644"
  source "hdfs-site.xml.erb"
  notifies :restart, resources(:service => "hadoop-0.20-datanode")
end

template "/etc/hadoop/conf/mapred-site.xml" do
  owner "root"
  group "hadoop"
  mode "0644"
  source "mapred-site.xml.erb"
  notifies :restart, resources(:service => "hadoop-0.20-tasktracker")
end

template "/etc/hadoop/conf/hadoop-env.sh" do
  owner "root"
  group "hadoop"
  mode "0644"
  source "hadoop-env.sh.erb"
  notifies :restart, resources(:service => "hadoop-0.20-datanode")
  notifies :restart, resources(:service => "hadoop-0.20-tasktracker")
end

template "/etc/hadoop/conf/hadoop-metrics.properties" do
  owner "root"
  group "hadoop"
  mode "0644"
  source "hadoop-metrics.properties.erb"
end

# Create the logging directory with proper permissions. 
directory node[:Hadoop][:Env][:HADOOP_LOG_DIR] do
  owner "root"
  group "hadoop"
  mode "0775"
  recursive true
  action :create
end


