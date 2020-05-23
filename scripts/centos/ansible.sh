#!/bin/bash

set -e
set -x

sudo yum -y --enablerepo=epel install python3 ansible
sudo yum -y install rsync

# XXX curl invoked by yum fails to load CA certificate. this happens only in
# libvirt image on Travis CI.
#
# stat("/etc/sysconfig/64bit_strstr_via_64bit_strstr_sse2_unaligned",
# 0x7ffc6c4f0a30) = -1 ENOENT (No such file or directory)
#
# https://bugs.centos.org/view.php?id=16282
echo '# https://bugs.centos.org/view.php?id=16282' | sudo tee /etc/sysconfig/64bit_strstr_via_64bit_strstr_sse2_unaligned
