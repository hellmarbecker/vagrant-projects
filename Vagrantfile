# -*- mode: ruby -*-

Vagrant.configure(2) do |config|

  # Configure VM Ram usage
  config.vm.provider "virtualbox" do |v|
    v.memory = 1536
  end

  config.vm.define "slave1" do |slave1|
    ssh_key_pub = File.read(File.join(Dir.pwd, ".ssh", "id_rsa.pub"))
    slave1.vm.provision :shell, :inline => "echo 'Copying public root SSH Key to slave VM for provisioning...' && mkdir -p /root/.ssh && echo '#{ssh_key_pub}' > /root/.ssh/id_rsa.pub && chmod 600 /root/.ssh/id_rsa.pub && cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && chmod 0400 /root/.ssh/authorized_keys"
    slave1.vm.box = "chef/centos-6.5"
    slave1.vm.hostname = "slave1"
    slave1.vm.network "private_network", ip: "192.168.17.21"
    slave1.vm.network :forwarded_port,
      guest: 22, 
      host: 2211,
      id: "ssh",
      auto_correct: true
  end

  config.vm.define "master1" do |master1|
    # This guy is the only one that will have the private key. Read the private key from previously filled location.
    ssh_key = File.read(File.join(Dir.pwd, ".ssh", "id_rsa"))
    ssh_key_pub = File.read(File.join(Dir.pwd, ".ssh", "id_rsa.pub"))
    # Store the private key in root's .ssh directory.
    master1.vm.provision :shell, :inline => "echo 'Copying private root SSH Key to master VM for provisioning...' && mkdir -p /root/.ssh && echo '#{ssh_key}' > /root/.ssh/id_rsa && chmod 600 /root/.ssh/id_rsa"
    master1.vm.provision :shell, :inline => "echo 'Copying public root SSH Key to master VM for provisioning...' && mkdir -p /root/.ssh && echo '#{ssh_key_pub}' > /root/.ssh/id_rsa.pub && chmod 600 /root/.ssh/id_rsa.pub && cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && chmod 0400 /root/.ssh/authorized_keys"
    # Note: After this, use something like
    #   ssh -oStrictHostKeyChecking=no 192.168.17.21 'echo Logging in for host key'
    # to automatically accept the host key for each slave.
    master1.vm.box = "chef/centos-6.5"
    master1.vm.hostname = "master1"
    master1.vm.network "private_network", ip: "192.168.17.11"
    master1.vm.network :forwarded_port,
      guest: 22, 
      host: 2201,
      id: "ssh",
      auto_correct: true
  end

#  config.vm.define "node2" do |node2|
#    node2.vm.box = "chef/centos-6.5"
#  end

#  config.vm.define "node3" do |node3|
#    node3.vm.box = "chef/centos-6.5"
#  end

end
