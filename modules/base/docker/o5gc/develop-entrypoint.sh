#!/bin/bash
set -e

# Do not update /etc/resolv.conf when getting an IP address via DHCP
cat > /etc/dhcp/dhclient-enter-hooks.d/nodnsupdate << EOF
#!/bin/sh
make_resolv_conf(){
	:
}
EOF
chmod +x /etc/dhcp/dhclient-enter-hooks.d/nodnsupdate

echo "cd /o5gc/" >> /root/.bashrc

set -x

dhclient -nw -q eth1 &
sleep 5
ip address show eth1

git config --global safe.directory '*'

sleep infinity
