# Created by Topology-Converter v4.6.9
#    Template Revision: v4.6.9
#    https://github.com/cumulusnetworks/topology_converter
#    using topology data from: ./topology.dot
#    built with the following args: ./topology_converter.py ./topology.dot
#
#    NOTE: in order to use this Vagrantfile you will need:
#       -Vagrant(v2.0.2+) installed: http://www.vagrantup.com/downloads
#       -the "helper_scripts" directory that comes packaged with topology-converter.py
#       -Virtualbox installed: https://www.virtualbox.org/wiki/Downloads



Vagrant.require_version ">= 2.0.2"

# Fix for Older versions of Vagrant to Grab Images from the Correct Location
unless Vagrant::DEFAULT_SERVER_URL.frozen?
  Vagrant::DEFAULT_SERVER_URL.replace('https://vagrantcloud.com')
end

$script = <<-SCRIPT
if grep -q -i 'cumulus' /etc/lsb-release &> /dev/null; then
    echo "### RUNNING CUMULUS EXTRA CONFIG ###"
    source /etc/lsb-release
    if [ -z /etc/app-release ]; then
        echo "  INFO: Detected NetQ TS Server"
        source /etc/app-release
        echo "  INFO: Running NetQ TS Appliance Version $APPLIANCE_VERSION"
    else
        if [[ $DISTRIB_RELEASE =~ ^2.* ]]; then
            echo "  INFO: Detected a 2.5.x Based Release"

            echo "  adding fake cl-acltool..."
            echo -e "#!/bin/bash\nexit 0" > /usr/bin/cl-acltool
            chmod 755 /usr/bin/cl-acltool

            echo "  adding fake cl-license..."
            echo -e "#!/bin/bash\nexit 0" > /usr/bin/cl-license
            chmod 755 /usr/bin/cl-license

            echo "  Disabling default remap on Cumulus VX..."
            mv -v /etc/init.d/rename_eth_swp /etc/init.d/rename_eth_swp.backup

            echo "### Rebooting to Apply Remap..."
        elif [[ $DISTRIB_RELEASE =~ ^3.* ]]; then
            echo "  INFO: Detected a 3.x Based Release ($DISTRIB_RELEASE)"
            echo "### Disabling default remap on Cumulus VX..."
            mv -v /etc/hw_init.d/S10rename_eth_swp.sh /etc/S10rename_eth_swp.sh.backup &> /dev/null
            echo "  INFO: Detected Cumulus Linux v$DISTRIB_RELEASE Release"
            if [[ $DISTRIB_RELEASE =~ ^3.[1-9].* ]]; then
                echo "### Fixing ONIE DHCP to avoid Vagrant Interface ###"
                echo "     Note: Installing from ONIE will undo these changes."
                mkdir /tmp/foo
                mount LABEL=ONIE-BOOT /tmp/foo
                sed -i 's/eth0/eth1/g' /tmp/foo/grub/grub.cfg
                sed -i 's/eth0/eth1/g' /tmp/foo/onie/grub/grub-extra.cfg
                umount /tmp/foo
            fi
            if [[ $DISTRIB_RELEASE =~ ^3.2.* ]]; then
                if [[ $(grep "vagrant" /etc/netd.conf | wc -l ) == 0 ]]; then
                    echo "### Giving Vagrant User Ability to Run NCLU Commands ###"
                    sed -i 's/users_with_edit = root, cumulus/users_with_edit = root, cumulus, vagrant/g' /etc/netd.conf
                    sed -i 's/users_with_show = root, cumulus/users_with_show = root, cumulus, vagrant/g' /etc/netd.conf
                fi
            elif [[ $DISTRIB_RELEASE =~ ^3.[3-9].* ]]; then
                echo "### Giving Vagrant User Ability to Run NCLU Commands ###"
                adduser vagrant netedit
                adduser vagrant netshow
            fi
            echo "### Disabling ZTP service..."
            systemctl stop ztp.service
            ztp -d 2>&1
            echo "### Resetting ZTP to work next boot..."
            ztp -R 2>&1
            ztp -i 2>&1
        fi
    fi
fi
echo "### DONE ###"
echo "### Rebooting Device to Apply Remap..."
nohup bash -c 'sleep 10; shutdown now -r "Rebooting to Remap Interfaces"' &
SCRIPT

Vagrant.configure("2") do |config|

  simid = 1548626793

  config.vm.provider "virtualbox" do |v|
    v.gui=false

  end




  ##### DEFINE VM for oob-mgmt-server #####
  config.vm.define "oob-mgmt-server" do |device|
    
    device.vm.hostname = "oob-mgmt-server" 
    
    device.vm.box = "CumulusCommunity/vx_oob_server"
    device.vm.box_version = "1.0.4"
    device.vm.provider "virtualbox" do |v|
      v.name = "#{simid}_oob-mgmt-server"
      v.customize ["modifyvm", :id, '--audiocontroller', 'AC97', '--audio', 'Null']
      v.memory = 1024
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth1 --> oob-mgmt-switch:swp1
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net23", auto_config: false , :mac => "443839000025"
      

    device.vm.provider "virtualbox" do |vbox|
      vbox.customize ['modifyvm', :id, '--nicpromisc2', 'allow-all', "--nictype2", "virtio"]
      vbox.customize ["modifyvm", :id, "--nictype1", "virtio"]
    end

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/config_oob_server.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:25 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:25", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for oob-mgmt-switch #####
  config.vm.define "oob-mgmt-switch" do |device|
    
    device.vm.hostname = "oob-mgmt-switch" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = "3.7.2"
    device.vm.provider "virtualbox" do |v|
      v.name = "#{simid}_oob-mgmt-switch"
      v.customize ["modifyvm", :id, '--audiocontroller', 'AC97', '--audio', 'Null']
      v.memory = 768
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for swp1 --> oob-mgmt-server:eth1
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net23", auto_config: false , :mac => "a00000000061"
      
      # link for swp2 --> server01:eth0
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net24", auto_config: false , :mac => "443839000026"
      
      # link for swp3 --> server02:eth0
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net25", auto_config: false , :mac => "443839000027"
      
      # link for swp4 --> server03:eth0
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net26", auto_config: false , :mac => "443839000028"
      
      # link for swp5 --> server04:eth0
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net27", auto_config: false , :mac => "443839000029"
      
      # link for swp6 --> leaf01:eth0
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net28", auto_config: false , :mac => "44383900002a"
      
      # link for swp7 --> leaf02:eth0
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net29", auto_config: false , :mac => "44383900002b"
      
      # link for swp10 --> spine01:eth0
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net30", auto_config: false , :mac => "44383900002c"
      
      # link for swp11 --> spine02:eth0
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net31", auto_config: false , :mac => "44383900002d"
      
      # link for swp12 --> exit01:eth0
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net32", auto_config: false , :mac => "44383900002e"
      
      # link for swp13 --> exit02:eth0
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net33", auto_config: false , :mac => "44383900002f"
      
      # link for swp14 --> edge01:eth0
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net34", auto_config: false , :mac => "443839000030"
      
      # link for swp15 --> internet:eth0
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net35", auto_config: false , :mac => "443839000031"
      

    device.vm.provider "virtualbox" do |vbox|
      vbox.customize ['modifyvm', :id, '--nicpromisc2', 'allow-all', "--nictype2", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc3', 'allow-all', "--nictype3", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc4', 'allow-all', "--nictype4", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc5', 'allow-all', "--nictype5", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc6', 'allow-all', "--nictype6", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc7', 'allow-all', "--nictype7", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc8', 'allow-all', "--nictype8", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc9', 'allow-all', "--nictype9", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc10', 'allow-all', "--nictype10", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc11', 'allow-all', "--nictype11", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc12', 'allow-all', "--nictype12", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc13', 'allow-all', "--nictype13", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc14', 'allow-all', "--nictype14", "virtio"]
      vbox.customize ["modifyvm", :id, "--nictype1", "virtio"]
    end

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/config_oob_switch.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: a0:00:00:00:00:61 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="a0:00:00:00:00:61", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:26 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:26", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:27 --> swp3"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:27", NAME="swp3", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:28 --> swp4"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:28", NAME="swp4", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:29 --> swp5"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:29", NAME="swp5", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2a --> swp6"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2a", NAME="swp6", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2b --> swp7"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2b", NAME="swp7", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2c --> swp10"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2c", NAME="swp10", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2d --> swp11"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2d", NAME="swp11", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2e --> swp12"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2e", NAME="swp12", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:2f --> swp13"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:2f", NAME="swp13", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:30 --> swp14"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:30", NAME="swp14", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:31 --> swp15"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:31", NAME="swp15", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for exit01 #####
  config.vm.define "exit01" do |device|
    
    device.vm.hostname = "exit01" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = "3.7.2"
    device.vm.provider "virtualbox" do |v|
      v.name = "#{simid}_exit01"
      v.customize ["modifyvm", :id, '--audiocontroller', 'AC97', '--audio', 'Null']
      v.memory = 768
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp12
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net32", auto_config: false , :mac => "a00000000041"
      
      # link for swp1 --> internet:swp1
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net19", auto_config: false , :mac => "44383900001e"
      
      # link for swp4 --> edge01:eth1
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net21", auto_config: false , :mac => "443839000022"
      
      # link for swp5 --> server03:eth1
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net11", auto_config: false , :mac => "443839000011"
      
      # link for swp6 --> server04:eth1
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net13", auto_config: false , :mac => "443839000013"
      
      # link for swp54 --> exit02:swp54
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net6", auto_config: false , :mac => "44383900000b"
      
      # link for swp55 --> spine02:swp30
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net16", auto_config: false , :mac => "443839000017"
      
      # link for swp56 --> spine01:swp30
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net15", auto_config: false , :mac => "443839000015"
      

    device.vm.provider "virtualbox" do |vbox|
      vbox.customize ['modifyvm', :id, '--nicpromisc2', 'allow-all', "--nictype2", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc3', 'allow-all', "--nictype3", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc4', 'allow-all', "--nictype4", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc5', 'allow-all', "--nictype5", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc6', 'allow-all', "--nictype6", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc7', 'allow-all', "--nictype7", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc8', 'allow-all', "--nictype8", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc9', 'allow-all', "--nictype9", "virtio"]
      vbox.customize ["modifyvm", :id, "--nictype1", "virtio"]
    end

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/config_switch.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: a0:00:00:00:00:41 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="a0:00:00:00:00:41", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1e --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1e", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:22 --> swp4"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:22", NAME="swp4", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:11 --> swp5"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:11", NAME="swp5", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:13 --> swp6"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:13", NAME="swp6", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0b --> swp54"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0b", NAME="swp54", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:17 --> swp55"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:17", NAME="swp55", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:15 --> swp56"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:15", NAME="swp56", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for exit02 #####
  config.vm.define "exit02" do |device|
    
    device.vm.hostname = "exit02" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = "3.7.2"
    device.vm.provider "virtualbox" do |v|
      v.name = "#{simid}_exit02"
      v.customize ["modifyvm", :id, '--audiocontroller', 'AC97', '--audio', 'Null']
      v.memory = 768
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp13
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net33", auto_config: false , :mac => "a00000000042"
      
      # link for swp1 --> internet:swp2
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net20", auto_config: false , :mac => "443839000020"
      
      # link for swp4 --> edge01:eth2
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net22", auto_config: false , :mac => "443839000024"
      
      # link for swp5 --> server03:eth2
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net12", auto_config: false , :mac => "443839000012"
      
      # link for swp6 --> server04:eth2
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net14", auto_config: false , :mac => "443839000014"
      
      # link for swp54 --> exit01:swp54
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net6", auto_config: false , :mac => "44383900000c"
      
      # link for swp55 --> spine02:swp29
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net18", auto_config: false , :mac => "44383900001b"
      
      # link for swp56 --> spine01:swp29
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net17", auto_config: false , :mac => "443839000019"
      

    device.vm.provider "virtualbox" do |vbox|
      vbox.customize ['modifyvm', :id, '--nicpromisc2', 'allow-all', "--nictype2", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc3', 'allow-all', "--nictype3", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc4', 'allow-all', "--nictype4", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc5', 'allow-all', "--nictype5", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc6', 'allow-all', "--nictype6", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc7', 'allow-all', "--nictype7", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc8', 'allow-all', "--nictype8", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc9', 'allow-all', "--nictype9", "virtio"]
      vbox.customize ["modifyvm", :id, "--nictype1", "virtio"]
    end

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/config_switch.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: a0:00:00:00:00:42 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="a0:00:00:00:00:42", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:20 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:20", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:24 --> swp4"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:24", NAME="swp4", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:12 --> swp5"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:12", NAME="swp5", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:14 --> swp6"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:14", NAME="swp6", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0c --> swp54"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0c", NAME="swp54", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1b --> swp55"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1b", NAME="swp55", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:19 --> swp56"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:19", NAME="swp56", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for spine01 #####
  config.vm.define "spine01" do |device|
    
    device.vm.hostname = "spine01" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = "3.7.2"
    device.vm.provider "virtualbox" do |v|
      v.name = "#{simid}_spine01"
      v.customize ["modifyvm", :id, '--audiocontroller', 'AC97', '--audio', 'Null']
      v.memory = 768
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp10
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net30", auto_config: false , :mac => "a00000000021"
      
      # link for swp1 --> leaf01:swp56
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net1", auto_config: false , :mac => "443839000002"
      
      # link for swp2 --> leaf02:swp56
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net2", auto_config: false , :mac => "443839000004"
      
      # link for swp29 --> exit02:swp56
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net17", auto_config: false , :mac => "44383900001a"
      
      # link for swp30 --> exit01:swp56
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net15", auto_config: false , :mac => "443839000016"
      

    device.vm.provider "virtualbox" do |vbox|
      vbox.customize ['modifyvm', :id, '--nicpromisc2', 'allow-all', "--nictype2", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc3', 'allow-all', "--nictype3", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc4', 'allow-all', "--nictype4", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc5', 'allow-all', "--nictype5", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc6', 'allow-all', "--nictype6", "virtio"]
      vbox.customize ["modifyvm", :id, "--nictype1", "virtio"]
    end

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/config_switch.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: a0:00:00:00:00:21 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="a0:00:00:00:00:21", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:02 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:02", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:04 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:04", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1a --> swp29"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1a", NAME="swp29", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:16 --> swp30"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:16", NAME="swp30", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for spine02 #####
  config.vm.define "spine02" do |device|
    
    device.vm.hostname = "spine02" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = "3.7.2"
    device.vm.provider "virtualbox" do |v|
      v.name = "#{simid}_spine02"
      v.customize ["modifyvm", :id, '--audiocontroller', 'AC97', '--audio', 'Null']
      v.memory = 768
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp11
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net31", auto_config: false , :mac => "a00000000022"
      
      # link for swp1 --> leaf01:swp55
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net3", auto_config: false , :mac => "443839000006"
      
      # link for swp2 --> leaf02:swp55
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net4", auto_config: false , :mac => "443839000008"
      
      # link for swp29 --> exit02:swp55
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net18", auto_config: false , :mac => "44383900001c"
      
      # link for swp30 --> exit01:swp55
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net16", auto_config: false , :mac => "443839000018"
      

    device.vm.provider "virtualbox" do |vbox|
      vbox.customize ['modifyvm', :id, '--nicpromisc2', 'allow-all', "--nictype2", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc3', 'allow-all', "--nictype3", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc4', 'allow-all', "--nictype4", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc5', 'allow-all', "--nictype5", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc6', 'allow-all', "--nictype6", "virtio"]
      vbox.customize ["modifyvm", :id, "--nictype1", "virtio"]
    end

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/config_switch.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: a0:00:00:00:00:22 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="a0:00:00:00:00:22", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:06 --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:06", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:08 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:08", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1c --> swp29"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1c", NAME="swp29", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:18 --> swp30"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:18", NAME="swp30", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for leaf01 #####
  config.vm.define "leaf01" do |device|
    
    device.vm.hostname = "leaf01" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = "3.7.2"
    device.vm.provider "virtualbox" do |v|
      v.name = "#{simid}_leaf01"
      v.customize ["modifyvm", :id, '--audiocontroller', 'AC97', '--audio', 'Null']
      v.memory = 768
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp6
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net28", auto_config: false , :mac => "a00000000011"
      
      # link for swp1 --> server01:eth1
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net7", auto_config: false , :mac => "44383900000d"
      
      # link for swp2 --> server02:eth1
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net9", auto_config: false , :mac => "44383900000f"
      
      # link for swp54 --> leaf02:swp54
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net5", auto_config: false , :mac => "443839000009"
      
      # link for swp55 --> spine02:swp1
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net3", auto_config: false , :mac => "443839000005"
      
      # link for swp56 --> spine01:swp1
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net1", auto_config: false , :mac => "443839000001"
      

    device.vm.provider "virtualbox" do |vbox|
      vbox.customize ['modifyvm', :id, '--nicpromisc2', 'allow-all', "--nictype2", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc3', 'allow-all', "--nictype3", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc4', 'allow-all', "--nictype4", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc5', 'allow-all', "--nictype5", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc6', 'allow-all', "--nictype6", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc7', 'allow-all', "--nictype7", "virtio"]
      vbox.customize ["modifyvm", :id, "--nictype1", "virtio"]
    end

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/config_switch.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: a0:00:00:00:00:11 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="a0:00:00:00:00:11", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0d --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0d", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0f --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0f", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:09 --> swp54"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:09", NAME="swp54", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:05 --> swp55"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:05", NAME="swp55", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:01 --> swp56"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:01", NAME="swp56", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for leaf02 #####
  config.vm.define "leaf02" do |device|
    
    device.vm.hostname = "leaf02" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = "3.7.2"
    device.vm.provider "virtualbox" do |v|
      v.name = "#{simid}_leaf02"
      v.customize ["modifyvm", :id, '--audiocontroller', 'AC97', '--audio', 'Null']
      v.memory = 768
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp7
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net29", auto_config: false , :mac => "a00000000012"
      
      # link for swp1 --> server01:eth2
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net8", auto_config: false , :mac => "44383900000e"
      
      # link for swp2 --> server02:eth2
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net10", auto_config: false , :mac => "443839000010"
      
      # link for swp54 --> leaf01:swp54
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net5", auto_config: false , :mac => "44383900000a"
      
      # link for swp55 --> spine02:swp2
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net4", auto_config: false , :mac => "443839000007"
      
      # link for swp56 --> spine01:swp2
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net2", auto_config: false , :mac => "443839000003"
      

    device.vm.provider "virtualbox" do |vbox|
      vbox.customize ['modifyvm', :id, '--nicpromisc2', 'allow-all', "--nictype2", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc3', 'allow-all', "--nictype3", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc4', 'allow-all', "--nictype4", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc5', 'allow-all', "--nictype5", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc6', 'allow-all', "--nictype6", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc7', 'allow-all', "--nictype7", "virtio"]
      vbox.customize ["modifyvm", :id, "--nictype1", "virtio"]
    end

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/config_switch.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: a0:00:00:00:00:12 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="a0:00:00:00:00:12", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0e --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0e", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:10 --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:10", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:0a --> swp54"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:0a", NAME="swp54", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:07 --> swp55"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:07", NAME="swp55", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:03 --> swp56"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:03", NAME="swp56", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for server01 #####
  config.vm.define "server01" do |device|
    
    device.vm.hostname = "server01" 
    
    device.vm.box = "yk0/ubuntu-xenial"
    device.vm.provider "virtualbox" do |v|
      v.name = "#{simid}_server01"
      v.customize ["modifyvm", :id, '--audiocontroller', 'AC97', '--audio', 'Null']
      v.memory = 512
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp2
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net24", auto_config: false , :mac => "a00000000031"
      
      # link for eth1 --> leaf01:swp1
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net7", auto_config: false , :mac => "000300111101"
      
      # link for eth2 --> leaf02:swp1
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net8", auto_config: false , :mac => "000300111102"
      

    device.vm.provider "virtualbox" do |vbox|
      vbox.customize ['modifyvm', :id, '--nicpromisc2', 'allow-all', "--nictype2", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc3', 'allow-all', "--nictype3", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc4', 'allow-all', "--nictype4", "virtio"]
      vbox.customize ["modifyvm", :id, "--nictype1", "virtio"]
    end

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/config_server.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: a0:00:00:00:00:31 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="a0:00:00:00:00:31", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:11:11:01 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:11:11:01", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:11:11:02 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:11:11:02", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for server02 #####
  config.vm.define "server02" do |device|
    
    device.vm.hostname = "server02" 
    
    device.vm.box = "yk0/ubuntu-xenial"
    device.vm.provider "virtualbox" do |v|
      v.name = "#{simid}_server02"
      v.customize ["modifyvm", :id, '--audiocontroller', 'AC97', '--audio', 'Null']
      v.memory = 512
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp3
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net25", auto_config: false , :mac => "a00000000032"
      
      # link for eth1 --> leaf01:swp2
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net9", auto_config: false , :mac => "000300222201"
      
      # link for eth2 --> leaf02:swp2
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net10", auto_config: false , :mac => "000300222202"
      

    device.vm.provider "virtualbox" do |vbox|
      vbox.customize ['modifyvm', :id, '--nicpromisc2', 'allow-all', "--nictype2", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc3', 'allow-all', "--nictype3", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc4', 'allow-all', "--nictype4", "virtio"]
      vbox.customize ["modifyvm", :id, "--nictype1", "virtio"]
    end

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/config_server.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: a0:00:00:00:00:32 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="a0:00:00:00:00:32", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:22:22:01 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:22:22:01", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:22:22:02 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:22:22:02", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for server03 #####
  config.vm.define "server03" do |device|
    
    device.vm.hostname = "server03" 
    
    device.vm.box = "yk0/ubuntu-xenial"
    device.vm.provider "virtualbox" do |v|
      v.name = "#{simid}_server03"
      v.customize ["modifyvm", :id, '--audiocontroller', 'AC97', '--audio', 'Null']
      v.memory = 512
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp4
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net26", auto_config: false , :mac => "a00000000033"
      
      # link for eth1 --> exit01:swp5
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net11", auto_config: false , :mac => "000300333301"
      
      # link for eth2 --> exit02:swp5
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net12", auto_config: false , :mac => "000300333302"
      

    device.vm.provider "virtualbox" do |vbox|
      vbox.customize ['modifyvm', :id, '--nicpromisc2', 'allow-all', "--nictype2", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc3', 'allow-all', "--nictype3", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc4', 'allow-all', "--nictype4", "virtio"]
      vbox.customize ["modifyvm", :id, "--nictype1", "virtio"]
    end

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/config_server.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: a0:00:00:00:00:33 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="a0:00:00:00:00:33", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:33:33:01 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:33:33:01", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:33:33:02 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:33:33:02", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for server04 #####
  config.vm.define "server04" do |device|
    
    device.vm.hostname = "server04" 
    
    device.vm.box = "yk0/ubuntu-xenial"
    device.vm.provider "virtualbox" do |v|
      v.name = "#{simid}_server04"
      v.customize ["modifyvm", :id, '--audiocontroller', 'AC97', '--audio', 'Null']
      v.memory = 512
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp5
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net27", auto_config: false , :mac => "a00000000034"
      
      # link for eth1 --> exit01:swp6
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net13", auto_config: false , :mac => "000300444401"
      
      # link for eth2 --> exit02:swp6
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net14", auto_config: false , :mac => "000300444402"
      

    device.vm.provider "virtualbox" do |vbox|
      vbox.customize ['modifyvm', :id, '--nicpromisc2', 'allow-all', "--nictype2", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc3', 'allow-all', "--nictype3", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc4', 'allow-all', "--nictype4", "virtio"]
      vbox.customize ["modifyvm", :id, "--nictype1", "virtio"]
    end

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/config_server.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: a0:00:00:00:00:34 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="a0:00:00:00:00:34", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:44:44:01 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:44:44:01", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 00:03:00:44:44:02 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="00:03:00:44:44:02", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for edge01 #####
  config.vm.define "edge01" do |device|
    
    device.vm.hostname = "edge01" 
    
    device.vm.box = "yk0/ubuntu-xenial"
    device.vm.provider "virtualbox" do |v|
      v.name = "#{simid}_edge01"
      v.customize ["modifyvm", :id, '--audiocontroller', 'AC97', '--audio', 'Null']
      v.memory = 768
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp14
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net34", auto_config: false , :mac => "a00000000051"
      
      # link for eth1 --> exit01:swp4
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net21", auto_config: false , :mac => "443839000021"
      
      # link for eth2 --> exit02:swp4
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net22", auto_config: false , :mac => "443839000023"
      

    device.vm.provider "virtualbox" do |vbox|
      vbox.customize ['modifyvm', :id, '--nicpromisc2', 'allow-all', "--nictype2", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc3', 'allow-all', "--nictype3", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc4', 'allow-all', "--nictype4", "virtio"]
      vbox.customize ["modifyvm", :id, "--nictype1", "virtio"]
    end

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf 2>/dev/null || true"

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/config_server.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: a0:00:00:00:00:51 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="a0:00:00:00:00:51", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:21 --> eth1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:21", NAME="eth1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:23 --> eth2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:23", NAME="eth2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = vagrant"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="vagrant", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end

  ##### DEFINE VM for internet #####
  config.vm.define "internet" do |device|
    
    device.vm.hostname = "internet" 
    
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = "3.7.2"
    device.vm.provider "virtualbox" do |v|
      v.name = "#{simid}_internet"
      v.customize ["modifyvm", :id, '--audiocontroller', 'AC97', '--audio', 'Null']
      v.memory = 768
    end
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder ".", "/vagrant", disabled: true



    # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp15
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net35", auto_config: false , :mac => "a00000000050"
      
      # link for swp1 --> exit01:swp1
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net19", auto_config: false , :mac => "44383900001d"
      
      # link for swp2 --> exit02:swp1
      device.vm.network "private_network", virtualbox__intnet: "#{simid}_net20", auto_config: false , :mac => "44383900001f"
      

    device.vm.provider "virtualbox" do |vbox|
      vbox.customize ['modifyvm', :id, '--nicpromisc2', 'allow-all', "--nictype2", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc3', 'allow-all', "--nictype3", "virtio"]
      vbox.customize ['modifyvm', :id, '--nicpromisc4', 'allow-all', "--nictype4", "virtio"]
      vbox.customize ["modifyvm", :id, "--nictype1", "virtio"]
    end

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(sudo grep -q 'mesg n' /root/.profile 2>/dev/null && sudo sed -i '/mesg n/d' /root/.profile  2>/dev/null) || true;", privileged: false

    
    # Run the Config specified in the Node Attributes
    device.vm.provision :shell , privileged: false, :inline => 'echo "$(whoami)" > /tmp/normal_user'
    device.vm.provision :shell , path: "./helper_scripts/config_internet.sh"


    # Install Rules for the interface re-map
    device.vm.provision :shell , :inline => <<-delete_udev_directory
if [ -d "/etc/udev/rules.d/70-persistent-net.rules" ]; then
    rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
fi
rm -rfv /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
delete_udev_directory

device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: a0:00:00:00:00:50 --> eth0"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="a0:00:00:00:00:50", NAME="eth0", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1d --> swp1"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1d", NAME="swp1", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     device.vm.provision :shell , :inline => <<-udev_rule
echo "  INFO: Adding UDEV Rule: 44:38:39:00:00:1f --> swp2"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="44:38:39:00:00:1f", NAME="swp2", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
udev_rule
     
      device.vm.provision :shell , :inline => <<-vagrant_interface_rule
echo "  INFO: Adding UDEV Rule: Vagrant interface = swp48"
echo 'ACTION=="add", SUBSYSTEM=="net", ATTR{ifindex}=="2", NAME="swp48", SUBSYSTEMS=="pci"' >> /etc/udev/rules.d/70-persistent-net.rules
echo "#### UDEV Rules (/etc/udev/rules.d/70-persistent-net.rules) ####"
cat /etc/udev/rules.d/70-persistent-net.rules
vagrant_interface_rule

# Run Any Platform Specific Code and Apply the interface Re-map
    #   (may or may not perform a reboot depending on platform)
    device.vm.provision :shell , :inline => $script

end



end