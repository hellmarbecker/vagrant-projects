# -*- mode: ruby -*-

# The centos65 box comes with a dynamic 40G disk that is allocated to
# one volume group.

Vagrant.configure(2) do |config|

  config.vm.box = "chef/centos-6.5"

  # Configure VM Ram usage
  config.vm.provider "virtualbox" do |v|
    v.memory = 1536
  end

  ssh_key_pub = File.read(File.join(Dir.pwd, ".ssh", "id_rsa.pub"))
  ssh_key = File.read(File.join(Dir.pwd, ".ssh", "id_rsa"))

  config.vm.provision :shell do |s|
    s.path = File.join(Dir.pwd, "provisioner.sh")
    s.args = [ ssh_key_pub, ssh_key ]
  end

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
    master.vm.hostname = "master-1"
    master.vm.network "private_network", ip: "192.168.17.11"
    master.vm.network :forwarded_port,
      guest: 22, 
      host: 2201,
      id: "ssh",
      auto_correct: true
  end

end
