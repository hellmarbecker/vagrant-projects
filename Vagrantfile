# -*- mode: ruby -*-

# The centos65 box comes with a dynamic 40G disk that is allocated to
# one volume group.

$script_mkdirs = <<EOF
echo "Creating /gridXX directories"
for i in 0 1 2
do
  mkdir -p /grid$i
done
<<EOF
$script_setup = <<EOF
echo "Setting up hosts file"
echo "192.168.17.11 master-1" >> /etc/hosts
for i in 1 2
do
  echo "192.168.17.2$i slave-$i" >> /etc/hosts
done
cd /etc/yum.repos.d
wget http://public-repo-1.hortonworks.com/ambari/centos6/1.x/updates/1.7.0/ambari.repo
yum -y install ambari-agent
EOF

Vagrant.configure(2) do |config|

  config.vm.box = "chef/centos-6.5"

  # Configure VM Ram usage
  config.vm.provider "virtualbox" do |v|
    v.memory = 1536
  end

  ssh_key_pub = File.read(File.join(Dir.pwd, ".ssh", "id_rsa.pub"))
  config.vm.provision :shell, :inline => "echo 'Copying public root SSH Key to master VM for provisioning...' && mkdir -p /root/.ssh && echo '#{ssh_key_pub}' > /root/.ssh/id_rsa.pub && chmod 600 /root/.ssh/id_rsa.pub && cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && chmod 0400 /root/.ssh/authorized_keys"
  config.vm.provision :shell, inline: $script_mkdirs
  config.vm.provision :shell, inline: $script_setup

  (1..2).each do |i|
    config.vm.define "slave-#{i}" do |slave|
      slave.vm.hostname = "slave-#{i}"
      slave.vm.network "private_network", ip: "192.168.17.2#{i}"
      slave.vm.network :forwarded_port,
        guest: 22, 
        host: "221#{i}",
        id: "ssh",
        auto_correct: true
    end
  end

  config.vm.define "master-1", primary: true do |master|
    # This guy is the only one that will have the private key. Read the private key from previously filled location.
    ssh_key = File.read(File.join(Dir.pwd, ".ssh", "id_rsa"))
    # Store the private key in root's .ssh directory.
    master.vm.provision :shell, :inline => "echo 'Copying private root SSH Key to master VM for provisioning...' && mkdir -p /root/.ssh && echo '#{ssh_key}' > /root/.ssh/id_rsa && chmod 600 /root/.ssh/id_rsa"
    # Note: After this, use something like
    #   ssh -oStrictHostKeyChecking=no 192.168.17.21 'echo Logging in for host key'
    # to automatically accept the host key for each slave.
    # master.vm.box = "chef/centos-6.5"
    master.vm.hostname = "master-1"
    master.vm.network "private_network", ip: "192.168.17.11"
    master.vm.network :forwarded_port,
      guest: 22, 
      host: 2201,
      id: "ssh",
      auto_correct: true
  end

end
