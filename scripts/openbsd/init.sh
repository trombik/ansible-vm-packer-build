#!/bin/ksh

set -e
set -x

python_version="3.8"
case `uname -r` in
    6.5)
        python_version="3.6"
        ;;
    6.8)
        python_version="3.7"
        ;;
esac
python_package="python%${python_version}"

sudo pkg_add ${python_package} ansible rsync-- curl
sudo ln -sf /usr/local/bin/python${python_version} /usr/local/bin/python
sudo ln -sf /usr/local/bin/python${python_version}-config /usr/local/bin/python-config
sudo ln -sf /usr/local/bin/pydoc${python_version}  /usr/local/bin/pydoc

# install latest ansible on older versions
case `uname -r` in
6.[0123])
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
    # $? == 2 means no patch available
    if ! sudo syspatch && [ $? -ne 2 ]; then
        exit $?
    fi
    # run syspatch again. when syspatch has been updated, you need to run it
    # again.
    # "syspatch updated itself, run it again to install missing patches"
    if ! sudo syspatch && [ $? -ne 2 ]; then
        exit $?
    fi
fi
