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

mkdir -p /root/.ssh
echo 'Copying public root SSH Key to VM for provisioning...'
echo "$1" > /root/.ssh/id_rsa.pub
chmod 600 /root/.ssh/id_rsa.pub
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
chmod 0400 /root/.ssh/authorized_keys
# Note: After this, use something like
#   ssh -oStrictHostKeyChecking=no 192.168.17.21 'echo Logging in for host key'
# to automatically accept the host key for each slave.

echo "hostname: `hostname`"

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

# Check if this is the master node - that one gets the root private key and the
# Ambari server package.
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

echo "Creating /gridXX directories"
for i in 0 1 2
do
  mkdir -p /grid$i
done

echo "Setting up Ambari repository"
cd /etc/yum.repos.d
wget -nc http://public-repo-1.hortonworks.com/ambari/centos6/1.x/updates/1.7.0/ambari.repo
yum -y install ambari-agent
if [[ `hostname` =~ 'master' ]]
then
  echo "Installing Ambari server"
  yum -y install ambari-server
fi

