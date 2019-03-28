#!/bin/bash

echo "################################################"
echo "  Running Management Server Setup (config_netq_server.sh)..."
echo "################################################"
echo -e "\n This script was written for cumulus/ts"
echo " Detected vagrant user is: $username"

echo " ### Overwriting /etc/network/interfaces ###"
cat <<EOT > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
    alias Connects (via NAT) To the Internet

auto eth1
iface eth1
    alias Faces the Internal Management Network
    address 172.17.192.247/23

EOT

cat << EOT > /etc/ntp.conf
# /etc/ntp.conf, configuration for ntpd; see ntp.conf(5) for help

driftfile /var/lib/ntp/ntp.drift

statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable

server 0.cumulusnetworks.pool.ntp.org iburst
server 1.cumulusnetworks.pool.ntp.org iburst
server 2.cumulusnetworks.pool.ntp.org iburst
server 3.cumulusnetworks.pool.ntp.org iburst


# By default, exchange time with everybody, but don't allow configuration.
restrict -4 default kod notrap nomodify nopeer noquery
restrict -6 default kod notrap nomodify nopeer noquery

# Local users may interrogate the ntp server more closely.
restrict 127.0.0.1
restrict ::1

# Specify interfaces, don't listen on switch ports
interface listen eth1
EOT


echo " ### Push Hosts File ###"
cat << EOT > /etc/hosts
127.0.0.1 localhost 
127.0.1.1 oob-mgmt-server

172.17.192.250 oob-mgmt-server 
172.17.192.247 netq-server
172.17.192.249 oob-mgmt-switch
172.17.192.1 leaf01 juliet-cl-leaf01.nwid.bris.ac.uk
172.17.192.2 leaf02 juliet-cl-leaf02.nwid.bris.ac.uk
172.17.192.7 f5-1
172.17.192.8 f5-2
172.17.192.3 spine01 juliet-cl-spine01.nwid.bris.ac.uk
172.17.192.4 spine02 juliet-cl-spine02.nwid.bris.ac.uk
172.17.192.31 server01
172.17.192.32 server02
172.17.192.33 server03
172.17.192.34 server04
172.17.192.5 exit01 juliet-cl-exit01.nwid.bris.ac.uk
172.17.192.6 exit02 juliet-cl-exit02.nwid.bris.ac.uk
172.17.192.51 edge01
172.17.192.81 storage01
172.17.192.82 storage02
172.17.192.83 storage03
172.17.192.84 storage04
172.17.192.248 internet


# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOT

echo " ### Creating SSH keys for cumulus user ###"
mkdir -p /home/cumulus/.ssh
#/usr/bin/ssh-keygen -b 2048 -t rsa -f /home/cumulus/.ssh/id_rsa -q -N ""
cat <<EOT > /home/cumulus/.ssh/id_rsa
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAsx/kflIY1YnFLSNHWjVHHnWIX74E9XW2V4GN9yG5uDDqPl/O
CMLs4q5t0BZ2H9jt7smYzcqwOn4/ahROxJLpeGw+jwrLULqVz8HzzI57NjO7ZB7C
py2IzcVjapf6wlMaB9gepz8s7XEQmrLN5SHNnJX15AmPSbX+5IAtnv3ZnIcsD1eT
6xarZR4GVJ8qD8lgR+zozy1cWMLQiZ/erBZK42hvUAznqHojb3BpZOAyaf4PS+H9
gGhKuvcfPoAUxVKgBbA/HnDveNXDPLGtdeu67ET8e0it9u9CYuRFBd5WbIKWoiID
IbSAf+0DU5DfWY0AWs8cZTVTelrYRfKJG+zkrQIDAQABAoIBAAqDBp+7JaXybdXW
SiurEL9i2lv0BMp62/aKrdAg9Iswo66BZM/y0IAFCIC7sLbxvhTTU9pP2MO2APay
tmSm0ni0sX8nfQMB0CTfFvWcLvLhWk/n1jiFXY/l042/2YFp6w8mybW66WINzpGl
iJu3vh9AVavKO9Rxj8HNG+BGuWyMEQ7TB4JLIGOglfapHlSFzjBxlMTcVA4mWyDd
bztzh+Hn/J7Mmqw+FqmFXha+IWbojiMGTm1wS/78Iy7YgWpUYTP5CXGewC9fGnoK
H3WvZDD7puTWa8Qhd5p73NSEe/yUd5Z0qmloij7lUVX9kFNVZGS19BvbjAdj7ZL6
OCVLOkECgYEA3I7wDN0pmbuEojnvG3k09KGX4bkJRc/zblbWzC83rFzPWTn7uryL
n28JZMk1/DCEGWtroOQL68P2zSGdF6Yp3PAqsSKHks9fVJsJ0F3ZlXkZHtRFfNI7
i0dl5SsSWlnDPiSnC4bshM25vYb4qd3vij7vvHzb3rA3255u69aU0DkCgYEAz+iA
qoLEja9kTR+sqbP9zvHUWQ/xtKfNCQ5nnjXc7tZ7XUGEf0UTMrAgOKcZXKDq6g5+
hNTkEDPUpPwGhA4iAPbA96RNWh/bwClFQEkBHU3oHPzKcL2Utvo/c6pAb44f2bGD
9kS4B/sumQxvUYM41jfwXDFTNPXN/SBn2XnWUBUCgYBoRug1nMbTWTXvISbsPVUN
J+1QGhTJPfUgwMvTQ6u1wTeDPwfGFOiKW4v8a6krb6C1B/Wd3tPIByGDgJXuHXCD
dcUpdGLWxVaUAK0WJ5j8s4Ft8vxbdGYUhpAlVkTaFMBbfCbCK2tdqopbkhm07ioX
mYPtALdPRM9T9UcKF6zJ+QKBgQCd57lpR55e+foU9VyfG1xGg7dC2XA7RELegPlD
2SbuoynY/zzRqLXXBpvCS29gwbsJf26qFkMM50C2+c89FrrOvpp6u2ggbhfpz66Q
D6JwDk6fTYO3stUzT8dHYuRDlc8s+L0AGtsm/Kg8h4w4fZB6asv8SV4n2BTWDnmx
W+7grQKBgQCm52n2zAOh7b5So1upvuV7REHiAmcNNCHhuXFU75eZz7DQlqazjTzn
CNr0QLZlgxpAg0o6iqwUaduck4655bSrClg4PtnzuDe5e2RuPNSiyZRbUmmiYIYp
i06Z/SJZSH8a1AjEh2I8ayxIEIESpmyhn1Rv1aUT6IjmIQjgbxWxGg==
-----END RSA PRIVATE KEY-----
EOT

cat <<EOT > /home/cumulus/.ssh/id_rsa.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCzH+R+UhjVicUtI0daNUcedYhfvgT1dbZXgY33Ibm4MOo+X84Iwuzirm3QFnYf2O3uyZjNyrA6fj9qFE7Ekul4bD6PCstQupXPwfPMjns2M7tkHsKnLYjNxWNql/rCUxoH2B6nPyztcRCass3lIc2clfXkCY9Jtf7kgC2e/dmchywPV5PrFqtlHgZUnyoPyWBH7OjPLVxYwtCJn96sFkrjaG9QDOeoeiNvcGlk4DJp/g9L4f2AaEq69x8+gBTFUqAFsD8ecO941cM8sa1167rsRPx7SK3270Ji5EUF3lZsgpaiIgMhtIB/7QNTkN9ZjQBazxxlNVN6WthF8okb7OSt
EOT

cat /home/cumulus/.ssh/id_rsa.pub >> /home/cumulus/.ssh/authorized_keys
cp /home/cumulus/.ssh/id_rsa.pub /var/www/html/authorized_keys

chmod 700 -R /home/cumulus/.ssh
chown cumulus:cumulus -R /home/cumulus/.ssh


# Setup SSH key authentication for Ansible
mkdir -p /home/cumulus/.ssh
#wget -O /home/cumulus/.ssh/authorized_keys http://192.168.200.1/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCzH+R+UhjVicUtI0daNUcedYhfvgT1dbZXgY33Ibm4MOo+X84Iwuzirm3QFnYf2O3uyZjNyrA6fj9qFE7Ekul4bD6PCstQupXPwfPMjns2M7tkHsKnLYjNxWNql/rCUxoH2B6nPyztcRCass3lIc2clfXkCY9Jtf7kgC2e/dmchywPV5PrFqtlHgZUnyoPyWBH7OjPLVxYwtCJn96sFkrjaG9QDOeoeiNvcGlk4DJp/g9L4f2AaEq69x8+gBTFUqAFsD8ecO941cM8sa1167rsRPx7SK3270Ji5EUF3lZsgpaiIgMhtIB/7QNTkN9ZjQBazxxlNVN6WthF8okb7OSt" >> /home/cumulus/.ssh/authorized_keys
chmod 700 -R /home/cumulus/.ssh
chown cumulus:cumulus -R /home/cumulus/.ssh


echo "cumulus ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10_cumulus

# Setup NTP
sed -i '/^server [1-3]/d' /etc/ntp.conf
sed -i 's/^server 0.cumulusnetworks.pool.ntp.org iburst/server 172.17.192.250 iburst/g' /etc/ntp.conf

ping 8.8.8.8 -c2
if [ "\$?" == "0" ]; then
  apt-get update -qy
  apt-get install ntpdate -qy
fi
nohup bash -c 'sleep 2; shutdown now -r "Rebooting to Complete ZTP"' &
exit 0
#CUMULUS-AUTOPROVISIONING
EOT

echo "############################################"
echo "      DONE!"
echo "############################################"
