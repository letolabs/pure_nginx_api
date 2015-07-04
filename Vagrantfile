# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.box = 'ubuntu/trusty64'
    config.vm.define "local" do |local|
        local.vm.hostname = "openresty.virtual"

        local.vm.provider "virtualbox" do |vbox, override|
            override.vm.synced_folder ".", "/vagrant"
            override.vm.provision :shell, :path => "scripts/vagrant_provision.sh"
            override.vm.network "private_network", ip: "192.168.56.66"
            vbox.memory = 2048
        end
    end

    config.vm.define "dev" do |dev|
        #TODO
    end

    config.push.define "local-exec" do |push|
        #TODO
    end
end
