#!/bin/bash
#-------------------------------------------------------------------------------
# Provisioning script for cluster nodes
# Parameters:
# $1 - public key for root
# $2 - private key for root (only on master)
#-------------------------------------------------------------------------------

# If the provisioner ran already, do nothing.
tagfile=/root/.provisioned

if [ -f $tagfile ]
then
  echo "$tagfile already present, exiting"
  exit
fi
touch $tagfile

# Distribute root's public ssh key to all nodes.
mkdir -p /root/.ssh
echo 'Copying public root SSH Key to VM for provisioning...'
echo "$1" > /root/.ssh/id_rsa.pub
chmod 600 /root/.ssh/id_rsa.pub
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
chmod 0400 /root/.ssh/authorized_keys

echo "Installing perl"
yum -y install perl

# Enter all the cluster hostnames to the hosts file. Make sure own hostname
# resolves to the external IP (not localhost).
echo "Setting up hosts file"
perl -pi -e 's/(127\.0\.0\.1\s+)\S+/$1/' /etc/hosts
echo "192.168.17.11 master-1" >> /etc/hosts
for i in 1 2
do
  echo "192.168.17.2$i slave-$i" >> /etc/hosts
done

# If this is the master node, copy the root private key to ~/.ssh.
# Also connect once to all nodes without host checking, in order to
# automatically accept the host key for each node.
if [[ `hostname` =~ 'master' ]]
then
  echo 'Copying private root SSH Key to VM for provisioning...'
  echo "$2" > /root/.ssh/id_rsa
  chmod 600 /root/.ssh/id_rsa
  echo "Setting up host key cache"
  for node in "master-1" "slave-1" "slave-2"
  do
    ssh -oStrictHostKeyChecking=no $node "echo Logging in to $node for host key"
  done
fi

echo "Setting ulimit for open files"
echo '* hard nofile 10240' >> /etc/security/limits.conf
echo '* soft nofile 10240' >> /etc/security/limits.conf
ulimit -Hn 10240
ulimit -Sn 10240

echo "Creating /gridXX directories"
for i in 0 1 2
do
  mkdir -p /grid$i
done

echo "Setting up Ambari repository"
cd /etc/yum.repos.d
wget -nv -nc http://public-repo-1.hortonworks.com/ambari/centos6/1.x/updates/1.7.0/ambari.repo
echo "Installing Ambari agent"
yum -y install ambari-agent

if [[ `hostname` =~ 'master' ]]
then
  echo "Installing Ambari server"
  yum -y install ambari-server
  echo "Setting up Ambari server"
  ambari-server setup -s
  echo "Starting Ambari server"
  ambari-server start
fi

echo "Waiting for Ambari server to come up"
nohup sudo ~vagrant/start_ambari.sh &
echo "Provisioner: done"

