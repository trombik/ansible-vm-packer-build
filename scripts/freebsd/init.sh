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

case `uname -r` in
    10.3-*)
        # XXX when EoLed, freebsd-update exits with zero
        sudo freebsd-update --not-running-from-cron fetch || true
        ;;
    *)
        sudo freebsd-update --not-running-from-cron fetch
        ;;
esac

sudo freebsd-update --not-running-from-cron install
