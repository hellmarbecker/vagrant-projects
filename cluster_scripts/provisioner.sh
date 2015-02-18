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

if [ -f $tagfile ] ; then
  echo "$tagfile already present, exiting"
  exit
fi
touch $tagfile

# Try to find out if we are running inside ING, if so set proxy
if curl -s www.retail.intranet >/dev/null ; then
  echo "Detected ING network. Setting proxy for ING"
  export http_proxy=http://m05h306:Kurtie13@proxynldcv.europe.intranet:8080/
  export https_proxy=${http_proxy}
fi

# Distribute root's public ssh key to all nodes.
mkdir -p /root/.ssh
echo 'Copying public root SSH Key to VM for provisioning...'
echo "$1" > /root/.ssh/id_rsa.pub
chmod 0600 /root/.ssh/id_rsa.pub
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
chmod 0400 /root/.ssh/authorized_keys

# Enter all the cluster hostnames to the hosts file. Make sure own hostname
# resolves to the external IP (not localhost).
echo "Setting up hosts file"
sed -ie 's/\(127\.0\.0\.1\)[[:space:]]*[^[:space:]]*[[:space:]]*/\1 /g' /etc/hosts
echo "192.168.17.11 master-1 master-1.localdomain" >> /etc/hosts
for i in `seq 1 $3`
do
  echo "192.168.17.2$i slave-$i slave-$i.localdomain" >> /etc/hosts
done

# If this is the master node, copy the root private key to ~/.ssh.
# Also connect once to all nodes without host checking, in order to
# automatically accept the host key for each node.
if [[ `hostname` =~ 'master' ]] ; then
  echo 'Copying private root SSH Key to VM for provisioning...'
  echo "$2" > /root/.ssh/id_rsa
  chmod 600 /root/.ssh/id_rsa
  echo "Setting up host key cache"
  ssh -oStrictHostKeyChecking=no master-1 "echo Logging in to master-1 for host key"
  for i in `seq 1 $3`
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
for i in 0 1 2 ; do
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

echo "Setting up repository mirrors"
export HDP_REPO_BASEPATH=/vagrant/hdp-repo
export HDP_REPO_PATH=${HDP_REPO_BASEPATH}/hdp
mkdir -p ${HDP_REPO_PATH}
if [ ! -d "${HDP_REPO_PATH}/HDP" ] ; then
  echo "Untarring HDP"
  tar -C ${HDP_REPO_PATH} -xzf /root/hadoop-sw/HDP-2.2.0.0-centos6-rpm.tar.gz
else
  echo "HDP already present"
fi
if [ ! -d "${HDP_REPO_PATH}/HDP-UTILS-1.1.0.20" ] ; then
  echo "Untarring HDP-UTILS"
  tar -C ${HDP_REPO_PATH} -xzf /root/hadoop-sw/HDP-UTILS-1.1.0.20-centos6.tar.gz
else
  echo "HDP-UTILS already present"
fi
if [ ! -d "${HDP_REPO_BASEPATH}/ambari" ] ; then
  echo "Untarring Ambari"
  tar -C ${HDP_REPO_BASEPATH} -xzf /root/hadoop-sw/ambari-1.7.0-centos6.tar.gz
else
  echo "Ambari already present"
fi

echo "Setting up Ambari and HDP repository files"
# expecting these in the shared project dir on the host
cp /vagrant/cluster_scripts/ambari.repo /vagrant/cluster_scripts/hdp.repo /etc/yum.repos.d/

# Ambari cannot use file:// repositories, so give it a web server
# echo "Installing Apache web server"
# yum -y install httpd
# chkconfig httpd on
# ln -sf $HDP_REPO_BASEPATH/* /var/www/html/
# service httpd start

echo "Setting up repository mirrors"
# BUILD_AMBARI=1

# This environment variable governs whether the Ambari agents are installed by Ambari or by this script.
# PUSH_AGENTS=1

if [[ `hostname` =~ 'master' ]] ; then

  echo "Installing Ambari server"
  # for standard released version:
  yum -y -v install ambari-server
  # bleeding edge version:
  # yum -y install /vagrant/ambari-rpm/ambari-server-*.noarch.rpm
  echo "Setting up Ambari server"
  # use the previously downloaded JDK so we don't need to download again
  ambari-server setup -s -j /usr/lib/jvm/jre-1.7.0-openjdk.x86_64

  # Increase install timeout because otherwise the hadoop_2_2_* will bust. See AMBARI-8220
  echo "Setting install timeout"
  sed -i "s/agent.task.timeout=.*/agent.task.timeout=3600/" /etc/ambari-server/conf/ambari.properties

  echo "Starting Ambari server"
  ambari-server start

  # echo "Installing Ambari shell"
  # curl -Ls https://raw.githubusercontent.com/sequenceiq/ambari-shell/master/latest-snap.sh | bash >&/dev/null
  # this leaves the ambari shell to be invoked as java -jar /tmp/ambari-shell.jar

  echo "Waiting for Ambari server to answer on port 8080"
  while true ; do
    curl "http://master-1:8080" >&/dev/null && break
  done

  if [ -n "$PUSH_AGENTS" ] ; then
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
          \"slave-1\"
        ],
        \"user\":\"root\"
      }" 'http://master-1:8080/api/v1/bootstrap'
    # use something like
    #   curl -i -uadmin:admin http://localhost:8080/api/v1/bootstrap/1 | perl -pe 's/\\n/\n/g'
    # to check status
  fi
fi

if [ -z "$PUSH_AGENTS" ] ; then
  # agents to be installed on all nodes
  echo "Installing Ambari agent"
  # yum -y install /vagrant/ambari-rpm/ambari-agent-*.rpm
  yum -y -v install ambari-agent
  echo "Configuring Ambari agent"
  sed -i "s/localhost/master-1/" /etc/ambari-agent/conf/ambari-agent.ini
  echo "Starting Ambari agent"
  ambari-agent start
fi

# Install and configure basic Kerberos components

# On CentOS, all the dependent files live in /var/kerberos/krb5kdc
export KRB5_CONFIGDIR=/var/kerberos/krb5kdc
export KRB5_KDC=master-1.localdomain
export KRB5_REALM=LOCAL_REALM

echo "Installing Kerberos 5 client"
yum -y install krb5-workstation krb5-libs
echo "Configuring Kerberos"
sed -i -e "s/kerberos\\.example\\.com/${KRB5_KDC}/g" -e "s/EXAMPLE\\.COM/${KRB5_REALM}/g" /etc/krb5.conf

if [[ `hostname` =~ 'master' ]] ; then
  # Install KDC
  echo "Installing Kerberos 5 server package"
  yum -y install krb5-server
  echo "Configuring Kerberos 5 services"
  /usr/sbin/kdb5_util create -r ${KRB5_REALM} -s -P SECRET
  sed -i -e "s/EXAMPLE\\.COM/${KRB5_REALM}/g" ${KRB5_CONFIGDIR}/kadm5.acl
  kadmin.local -q "addprinc -pw admin admin/admin@${KRB5_REALM}"
  kadmin.local -q "ktadd -k ${KRB5_CONFIGDIR}/kadm5.keytab kadmin/admin kadmin/changepw" 
  echo "Starting Kerberos 5 KDC"
  chkconfig krb5kdc on
  service krb5kdc start
  echo "Starting Kerberos 5 admin service"
  chkconfig kadmin on
  service kadmin start

fi

echo "Provisioner: done"

