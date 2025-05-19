## System Preparation
### BIOS
It is recommended to disable hyperthreading and certain CPU functions to reduce drifting of
carrier frequencies.

1. Press F2 when booting to enter the bios.
2. Press F6 in the bios to switch to extended mode.
3. Deactivate the functions under the following tabs:
    1. Enhanced -> CPU Configuration -> Hyperthreading Disabled
    2. Enhanced -> CPU Configuration -> C-State Disabled OC-Tweakere
       -> CPU Configuration -> Intel-SpeedStep Disabled
    3. System Start -> Full Screen Logo Disabled

## Operating System Preparation
Ubuntu 22.04 is recommended as base host distribution.

### Install required Packages
```console
sudo apt install linux-tools-common net-tools make git-lfs ca-certificates curl gnupg openssh-server python3-virtualenv
```

### Disable iscsi Services
To speed up the boot time, it is maybe necessary to disable the iscsi services:
```console
sudo systemctl disable iscsid.service
sudo systemctl disable open-iscsi.service
```

### Install Lowlatency-Kernel
```console
sudo apt install linux-image-lowlatency linux-headers-lowlatency
sudo apt install linux-tools-lowlatency
```

### Configure CPU Power Management Permanently
Create a file ``/etc/systemd/system/cpupower`` with the following content
```systemd
[Service]
Type = oneshot
RemainAfterExit = yes
ExecStart = cpupower idle-set -d 1
[Install]
WantedBy = multi-user.target
```
and enable it with
```
sudo systemctl enable cpupower
```

### Install Docker Engine
See [official Docker documentation](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository)
for details. Specific fixed versions of the Docker packages are installed with the script
``docker/o5gc/install-docker.sh``. Execute it with
```console
make system-install-docker
```
```console
sudo usermod -aG docker $USER
```

### Networking
To configure a static IP address and enable DHCP for the network interface, create a file
``/etc/netplan/00-ethernet.yaml`` with the following content on all hosts (adjust interface
name and ip address as required):
```
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s31f6:
      dhcp4: yes
      addresses: [10.132.1.211/24]
      nameservers:
        addresses: [8.8.8.8,8.8.4.4]
```
In addition, on the RAN hosts, add the following entries into ``/etc/sysctl.conf``:
```
net.core.rmem_max=33554432
net.core.wmem_max=33554432
```
and assign to the 10G Ethernet interface connected to the X310 the IP address ``192.168.40.1/24``
and set the MTU to 9000: in ``/etc/netplan/00-ethernet.yaml``:
```
network:
  version: 2
  renderer: networkd
  ethernets:
    enp3s0f0:
      addresses: [192.168.40.1/24]
      mtu: "9000"
```

### Setup ssh Access
On the Controller host, add entries in the ``/etc/hosts`` file for the ran hosts with their
static ip address. This ensures, that the hosts are reachable, even if no DHCP is available.
```console
10.132.1.212    o5gc2
10.132.1.213    o5gc3
```

In addition, from the Controller host, passwordless ssh access to the ran host must be granted.

1. On the Controller host, create an ssh key with
```console
ssh-keygen -t ed25519
```
2. Copy the key to the ran hosts with
```console
ssh-copy-id o5gc2
ssh-copy-id o5gc3
```

## Project Installation
Extract / Checkout / Clone the project on the Controller server into an arbitrary directory,
like ``/home/user/o5gc`` and change into it.

### System Specific Settings
The system installation specific configuration can be adjusted in the file ``etc/local.env``:

1. Set the ``CLOCK_SRC``either to ``external`` or ``internal``, depending on whether an external
clock supply is connected to the USRP or not.
2. If components of the network (especially the RANs like the gNB) are distributed across
different hosts, set the Docker network driver for the ``corenet`` to ``macvlan``. If all
services are running on the same host, a ``bridge`` can be used instead.
```shell
# CORENET_DRIVER should be
#   - 'macvlan' if components (such as the gNB) are distributed across
#               different hosts
#   - 'bridge' if *all* components are running on this host
# run 'make systemd-startup-unit' after changing one of the following
# settings
CORENET_DRIVER=macvlan
# If macvlan is used, set the parent interface here
CORENET_MACVLAN_IFACE=eno1
```
3. Set the ``USRP_IFACE`` to the interface name of the 10G adapter connected to the USRP X310
on the RAN hosts. Leave it unchanged if USRPs B210 via USB are used.
4. Configure the hostname of the enb and gnb ran hosts:
```shell
# eNB / gNB RAN hostnames
ENB_HOSTNAME=o5gc2
GNB_HOSTNAME=o5gc3
```

### Install open5Gcube systemd Startup Service
```console
make systemd-install-unit
```

### Build all Docker Images
To build all docker images for all sub-projects on the Controller host as well as the ran projects
on the configured ran hosts, run
```
make build-cacher-start docker-build-all
```
and get yourself a big cup of coffee as this will take a few hours.

### Start the open5Gcube WebUI
```console
make webui-start
```
