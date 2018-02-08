#!/bin/ksh

set -e
set -x

sudo tee /etc/pkg.conf <<EOF
installpath = http://ftp5.usa.openbsd.org/pub/OpenBSD/5.6/packages/i386/
EOF

sudo pkg_add ansible rsync--
sudo ln -sf /usr/local/bin/python2.7 /usr/local/bin/python
sudo ln -sf /usr/local/bin/python2.7-2to3 /usr/local/bin/2to3
sudo ln -sf /usr/local/bin/python2.7-config /usr/local/bin/python-config
sudo ln -sf /usr/local/bin/pydoc2.7  /usr/local/bin/pydoc

sudo pkg_add curl

sudo tee /etc/rc.conf.local <<EOF
sndiod_flags=NO
sendmail_flags=NO
EOF

sed -e 's/\(ttyC[^0].*getty.*\)on /\1off/' /etc/ttys | sudo tee /etc/ttys > /dev/null
