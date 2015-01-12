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
for i in 1 2 3
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
  for node in "master-1" "slave-1" "slave-2" "slave-3"
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

# cd /etc/yum.repos.d
# wget -nv -nc http://public-repo-1.hortonworks.com/ambari/centos6/1.x/updates/1.7.0/ambari.repo
# echo "Installing Ambari agent"
# yum -y install ambari-agent

# Workaround for SSL bug in CentOS 6.5, see http://hortonworks.com/community/forums/topic/ambari-agent-registration-failure-on-rhel-6-5-due-to-openssl-2/
echo "Upgrading openssl"
yum -y upgrade openssl

echo "Downloading and installing Java"
# if we want oracle java:
# see http://tecadmin.net/steps-to-install-java-on-centos-5-6-or-rhel-5-6/
# but for now try:
yum -y install java-1.7.0-openjdk java-1.7.0-openjdk-devel

if [[ `hostname` =~ 'master' ]]
then
  echo "Installing Apache web server"
  yum -y install httpd
  chkconfig httpd on

  echo "Setting up repository mirrors"
  mkdir -p /var/www/html/hdp
  tar -C /var/www/html/hdp -xzf /root/hadoop-sw/HDP-2.2.0.0-centos6-rpm.tar.gz
  tar -C /var/www/html/hdp -xzf /root/hadoop-sw/HDP-UTILS-1.1.0.20-centos6.tar.gz
  tar -C /var/www/html -xzf /root/hadoop-sw/ambari-1.7.0-centos6.tar.gz

  echo "Starting web server on port 80"
  service httpd start
fi

echo "Setting up Ambari and HDP repository files"
# expecting these in the schared project dir on the host
cp /vagrant/cluster_scripts/ambari.repo /vagrant/cluster_scripts/hdp.repo /etc/yum.repos.d/

if [[ `hostname` =~ 'master' ]]
then
  echo "Installing Ambari server"
  yum -y install ambari-server
  echo "Setting up Ambari server"
  # use the previously downloaded JDK so we don't need to download again
  ambari-server setup -s -j /usr/lib/jvm/jre-1.7.0-openjdk.x86_64

  # Increase install timeout because otherwise the hadoop_2_2_* will bust. See AMBARI-8220
  echo "Setting install timeout"
  sed -i "s/agent.task.timeout=.*/agent.task.timeout=3600/" /etc/ambari-server/conf/ambari.properties

  echo "Starting Ambari server"
  ambari-server start

  echo "Installing Ambari shell"
  curl -Ls https://raw.githubusercontent.com/sequenceiq/ambari-shell/master/latest-snap.sh | bash
  # this leaves the ambari shell to be invoked as java -jar /tmp/ambari-shell.jar

  echo "Waiting for Ambari server to answer on port 8080"
  while true
  do
    curl "http://master-1:8080" >&/dev/null && break
  done


  echo "Distributing Ambari agents"
  # Need to convert the newlines in private key to \n escape sequence for JSON transmission
  # jkey=`echo "$2" | perl -e 'my $a = join "", <>; $a =~ s/\n/\\\\n/g; print $a'`
  jkey="${2//
/\n}"
  curl -i -uadmin:admin \
    -H 'X-Requested-By: ambari' \
    -H 'Content-Type: application/json' \
    -X POST \
    -d"{
      \"verbose\":true,
      \"sshKey\":\"$jkey\",
      \"hosts\":[
        \"master-1\",
        \"slave-1\",
        \"slave-2\",
        \"slave-3\"
      ],
      \"user\":\"root\"
    }" 'http://master-1:8080/api/v1/bootstrap'
  # use something like
  #   curl -i -uadmin:admin http://localhost:8080/api/v1/bootstrap/1 | perl -pe 's/\\n/\n/g'
  # to check status
fi

echo "Provisioner: done"

