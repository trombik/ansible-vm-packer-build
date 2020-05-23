#!/bin/sh

set -e
set -x

cat <<EOF > /etc/installurl
http://mirror.vdms.com/pub/OpenBSD
EOF

pkg_add sudo--
cat <<EOF > /etc/sudoers

#includedir /etc/sudoers.d
EOF
mkdir /etc/sudoers.d
cat <<EOF > /etc/sudoers.d/vagrant
Defaults:vagrant !requiretty
vagrant ALL=(ALL) NOPASSWD: ALL
root ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/vagrant

cat <<EOF > /etc/boot.conf
set timeout 1
EOF
