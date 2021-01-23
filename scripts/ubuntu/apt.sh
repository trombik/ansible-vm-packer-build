#!/bin/bash

set -e
set -x

# In Ubuntu 12.04, the contents of /var/lib/apt/lists are corrupt
ubuntu_version=$(lsb_release -r | awk '{ print $2 }')
if [ "$ubuntu_version" == '12.04' ]; then
  sudo rm -rf /var/lib/apt/lists
fi

# Disable periodic activities of apt, which causes `apt` tasks to fail by
# holding a lock
if [ "$ubuntu_version" != '14.04' ]; then
  sudo -S tee -a /etc/apt/apt.conf.d/10disable-periodic <<EOF
APT::Periodic::Enable "0";
EOF
fi

# Retry when fetching files fails
sudo -S tee -a /etc/apt/apt.conf.d/10retry <<EOF
Acquire::Retries "10";
EOF

sudo apt-get update
sudo apt-get -y install software-properties-common

source /etc/os-release
if [ "${NAME}" == "Devuan GNU/Linux" ]; then
    # XXX this should work, but does not
    # sudo apt-add-repository "deb http://deb.devuan.org/merged beowulf-backports main"
    echo "deb http://deb.devuan.org/merged ${VERSION_CODENAME}-backports main" | sudo tee -a /etc/apt/sources.list
else
    # install the latest ansible from ppa
    # XXX the ppa does not support 20.04
    # ==> virtualbox-iso: E: The repository 'http://ppa.launchpad.net/ansible/ansible/ubuntu focal Release' does not have a Release file.
    if [ "$ubuntu_version" != "20.04" ]; then
        sudo apt-add-repository ppa:ansible/ansible || true
    fi
fi

sudo apt-get update
if [ "${NAME}" == "Devuan GNU/Linux" ]; then
    sudo apt-get -y -t ${VERSION_CODENAME}-backports install python3 ansible rsync
else
    sudo apt-get -y install python3 ansible rsync
fi

# XXX remove snapd because it attempts to do something I don't (want to) know
# in the background upon boot.
if [ "${ubuntu_version}" == "20.04" ]; then
    sudo snap remove lxd
    sudo snap remove core18
    sudo snap remove snapd
    sudo rm -rf /var/cache/snapd
    sudo apt-get -y purge snapd
fi
