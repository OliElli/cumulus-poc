# cumulus-poc
Proof of Concept Cumulus Network

Vagrant and scripts to initialise the environment, then use https://github.com/OliElli/cumulus-poc-config

Quickstart: Run the demo
------------------------

Before running this demo, install VirtualBox and Vagrant.

    git clone https://github.com/OliElli/cumulus-poc
    cd cumulus-poc
    vagrant up oob-mgmt-server oob-mgmt-switch 
    vagrant up server01 server02 server03 server04 leaf01 leaf02 spine01 spine02 exit01 exit02 edge01 internet f5-1 f5-2 storage01 storage02 storage03 storage04
    vagrant ssh oob-mgmt-server
    git clone https://github.com/OliElli/cumulus-poc-config
    cd cumulus-poc-config
    ansible-playbook run-demo.yml
    ssh server01
    ping 172.16.1.1 
