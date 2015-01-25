#!/bin/bash
#-------------------------------------------------------------------------------
# Provisioning script for cluster nodes
# Parameters:
# $1 - public key for root
# $2 - private key for root (only on master)
# $3 - number of slave nodes
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
echo "192.168.17.11 master-1 master-1.localdomain" >> /etc/hosts
for i in `seq 1 .. $3`
do
  echo "192.168.17.2$i slave-$i slave-$i.localdomain" >> /etc/hosts
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
  ssh -oStrictHostKeyChecking=no master-1 "echo Logging in to master-1 for host key"
  for i in `seq 1 .. $3`
  do
    ssh -oStrictHostKeyChecking=no slave-$i "echo Logging in to slave-$i for host key"
  done
fi

echo "Setting ulimit for open files"
echo '* hard nofile 10240' >> /etc/security/limits.conf
echo '* soft nofile 10240' >> /etc/security/limits.conf
ulimit -Hn 10240
ulimit -Sn 10240

echo "Creating gridXX directories"
for i in 0 1 2
do
  mkdir -p /hadoop/grid$i
  chmod 777 /hadoop/grid$i
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

# BUILD_AMBARI=1

if [[ `hostname` =~ 'master' ]]
then

  if [ -n "$BUILD_AMBARI" ]
  then
    #-------------------------------------------------------------------------------
    # Build Ambari from newest Github.
    # See: https://cwiki.apache.org/confluence/display/AMBARI/Ambari+Development
    #-------------------------------------------------------------------------------

    # Get Ambari latest (trunk)
    git clone https://github.com/apache/ambari.git

    # Install Maven
    wget -nv http://apache.mirror1.spango.com/maven/maven-3/3.0.5/binaries/apache-maven-3.0.5-bin.tar.gz
    mkdir -p /usr/local/apache-maven
    tar -C /usr/local/apache-maven -xzf ~/apache-maven-3.0.5-bin.tar.gz
    read -r -d '' SETENV <<-'EOF'
	export M2_HOME=/usr/local/apache-maven/apache-maven-3.0.5
	export M2=$M2_HOME/bin
	export JAVA_HOME=/usr/lib/jvm/jre-1.7.0-openjdk.x86_64
	export PATH=$JAVA_HOME:$M2:$PATH
	EOF
    echo "$SETENV" >> ~/.bashrc
    eval "$SETENV"

    # Install Python setup tools
    wget -nv --no-check-certificate http://pypi.python.org/packages/2.6/s/setuptools/setuptools-0.6c11-py2.6.egg#md5=bfa92100bd772d5a213eedd356d64086
    sh setuptools-0.6c11-py2.6.egg

    # rpmbuild, g++
    yum -y install rpm-build
    yum -y install gcc-c++

    # node.js
    wget -nv http://nodejs.org/dist/v0.10.35/node-v0.10.35-linux-x64.tar.gz
    mkdir -p /usr/local/node
    tar -C /usr/local/node -xzf ~/node-v0.10.35-linux-x64.tar.gz
    read -r -d '' SETENV <<-'EOF'
	export PATH=/usr/local/node/node-v0.10.35-linux-x64/bin:$PATH
	EOF
    echo "$SETENV" >> ~/.bashrc
    eval "$SETENV"

    # brunch
    npm install -g brunch@1.7.17
  fi  

#-------------------------------------------------------------------------------
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

