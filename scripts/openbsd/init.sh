#!/bin/ksh

set -e
set -x

# pkg.conf has been replaced with installurl since 6.1
if [ `uname -r` == 5.9 -o `uname -r` == 6.0 ]; then
    sudo tee /etc/pkg.conf <<EOF
installpath = fastly.cdn.openbsd.org
EOF
fi

sudo pkg_add ansible rsync-- curl
sudo ln -sf /usr/local/bin/python2.7 /usr/local/bin/python
sudo ln -sf /usr/local/bin/python2.7-2to3 /usr/local/bin/2to3
sudo ln -sf /usr/local/bin/python2.7-config /usr/local/bin/python-config
sudo ln -sf /usr/local/bin/pydoc2.7  /usr/local/bin/pydoc

# install latest ansible
case `uname -r` in
    6.[012])
        ftp -o - https://github.com/trombik/ansible-ports-openbsd/archive/master.tar.gz | tar -zxvf -
        (cd ansible-ports-openbsd-master && sudo sh install.sh)
        rm -rf ansible-ports-openbsd-master
        sudo rm -R /usr/ports/*
        ;;
esac

sudo tee /etc/rc.conf.local <<EOF
sndiod_flags=NO
sendmail_flags=NO
EOF

sudo sed -i'.bak' -e 's/ \/opt ffs rw,nodev,nosuid 1 2/ \/opt ffs rw,nosuid 1 2/' /etc/fstab
sudo rm /etc/fstab.bak

sudo sed -i'.bak' -e 's/\(ttyC[^0].*getty.*\)on /\1off/' /etc/ttys
sudo rm /etc/ttys.bak

if sysctl -n kern.version | head -n1 | grep -q -- -current ;then
    # syspatch is not available for -current
    :
else
    case `uname -r` in
        6.[123])
            sudo syspatch
            ;;
    esac
fi
