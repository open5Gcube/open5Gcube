#!/bin/bash
set -e

for f in /var/run/ssh/ssh_host_*; do
    cp -v $f /etc/ssh/$(basename $f | sed -E "s|(ssh_host_).*_(.*_key.*)|\1\2|")
done
cp -v /var/run/ssh/authorized_keys /root/.ssh

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

echo "root:o5gc" | chpasswd
sed -i "s|^#PermitRootLogin.*|PermitRootLogin yes|" /etc/ssh/sshd_config

git config --global safe.directory '*'

service ssh start

sleep infinity
