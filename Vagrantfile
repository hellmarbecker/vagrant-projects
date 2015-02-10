# -*- mode: ruby -*-

# The centos65 box comes with a dynamic 40G disk that is allocated to
# one volume group.

# Set the number of slave nodes.
$NSLAVES=1

Vagrant.configure(2) do |config|

  config.vm.box = "chef/centos-6.5"

  # Configure VM Ram usage
  config.vm.provider "virtualbox" do |v|
    v.memory = 1280
    # Fix DNS, see http://askubuntu.com/questions/238040/how-do-i-fix-name-service-for-vagrant-client
    v.customize [ "modifyvm", :id, "--natdnshostresolver1", "on" ]
  end

  # Share the software tarball to a directory - this will only be used on master
  config.vm.synced_folder "D:\\Downloads\\Hortonworks", "/root/hadoop-sw"

  ssh_key_pub = File.read(File.join(Dir.pwd, ".ssh", "id_rsa.pub"))
  ssh_key = File.read(File.join(Dir.pwd, ".ssh", "id_rsa"))

  config.vm.provision :shell do |s|
    s.path = File.join(Dir.pwd, "cluster_scripts", "provisioner.sh")
    s.args = [ ssh_key_pub, ssh_key, $NSLAVES ]
  end

  (1..$NSLAVES).each do |i|
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
