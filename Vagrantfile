# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"

  # ==========================================
  # 1. API Gateway VM
  # ==========================================
  config.vm.define "gateway-vm" do |gateway|
    gateway.vm.hostname = "gateway-vm"
    gateway.vm.network "private_network", ip: "192.168.56.10"
    gateway.vm.network "forwarded_port", guest: 5002, host: 5002

    gateway.vm.provider "virtualbox" do |v|
      v.cpus = 1
      v.memory = 1024
    end

    gateway.vm.provision "shell", path: "scripts/install_gateway.sh"
  end

  # ==========================================
  # 2. Inventory VM
  # ==========================================
  config.vm.define "inventory-vm" do |inventory|
    inventory.vm.hostname = "inventory-vm"
    inventory.vm.network "private_network", ip: "192.168.56.11"
    inventory.vm.network "forwarded_port", guest: 8080, host: 8080

    inventory.vm.provider "virtualbox" do |v|
      v.cpus = 1
      v.memory = 1024
    end

    inventory.vm.provision "shell", path: "scripts/install_inventory.sh"
  end

# ==========================================
  # 3. Billing & Message Broker VM
  # ==========================================
  config.vm.define "billing-vm" do |billing|
    billing.vm.hostname = "billing-vm"
    billing.vm.network "private_network", ip: "192.168.56.12"
    
    # Avoid host collisions by using alternate host ports
    billing.vm.network "forwarded_port", guest: 5432, host: 5433
    billing.vm.network "forwarded_port", guest: 5672, host: 5673
    billing.vm.network "forwarded_port", guest: 15672, host: 15673

    billing.vm.provider "virtualbox" do |v|
      v.cpus = 2
      v.memory = 2048
    end

    billing.vm.provision "shell", path: "scripts/install_billing.sh"
  end
end