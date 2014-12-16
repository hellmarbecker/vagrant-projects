# -*- mode: ruby -*-

$script_slave = <<SCRIPT
echo Starting provisioning script for slave
echo Finished provisioning script for slave
SCRIPT

$script_master = <<SCRIPT
echo Starting provisioning script for master
test -f /root/.ssh/id_rsa || ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
echo Finished provisioning script for master
SCRIPT

Vagrant.configure(2) do |config|
  
  config.vm.define "slave1" do |slave1|
    slave1.vm.provision "shell", inline: $script_slave
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
    master1.vm.provision "shell", inline: $script_master
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
