#!/bin/sh

set -e
set -x

sed -e 's/\(ttyv[^0].*getty.*\)on /\1off/' /etc/ttys | sudo tee /etc/ttys > /dev/null
echo 'firewall_enable="YES"' | sudo tee -a /etc/rc.conf
echo 'firewall_script="/etc/ipfw.conf"' | sudo tee -a /etc/rc.conf
sudo tee /etc/ipfw.conf <<'EOF'
fwcmd="/sbin/ipfw"
${fwcmd} -f flush
${fwcmd} check-state
${fwcmd} add 65000 pass all from any to any keep-state
EOF

# XXX install python first so that `/usr/local/bin/python` works. when python
# is installed as a dependency of `ansible`, `/usr/local/bin/python$X.$Y`,
# where $X and $Y is python version number, is installed.
# XXX after FLAVORed ansible, `sysutils/` prefix is required.
sudo pkg install -y lang/python3 py37-ansible rsync

# adjust date before freebsd-update. incorrect time causes freebsd-update to
# log "expr: illegal option" to stderr, which causes a failure in tests
sudo ntpdate -b pool.ntp.org

case `uname -r` in
    10.3-*|11.1-*)
        # XXX when EoLed, freebsd-update exits with zero
        sudo freebsd-update --not-running-from-cron fetch || true
        ;;
    *)
        sudo freebsd-update --not-running-from-cron fetch
        ;;
esac

sudo freebsd-update --not-running-from-cron install
