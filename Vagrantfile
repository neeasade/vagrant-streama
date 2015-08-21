Vagrant.configure(2) do |config|
  config.vm.box = "chef/centos-7.0"

  config.vm.provider :virtualbox do |v|
    v.name = "streama"
    v.memory = 4096
    v.cpus = 2
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--ioapic", "on"]
  end

  config.vm.hostname = "streamabox"

  config.vm.network "forwarded_port", guest: 8080, host: 8080

  config.vm.provision :shell, :path => "provision.sh"
end
