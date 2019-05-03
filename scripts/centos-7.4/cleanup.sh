#!/bin/bash

set -e
set -x

if rpm -q --whatprovides kernel | grep -Fqv "$(uname -r)"; then
  rpm -q --whatprovides kernel | grep -Fv "$(uname -r)" | xargs sudo yum -y autoremove
fi

sudo yum --enablerepo=epel clean all
# XXX remove EPEL repo because it should not be here in the first place and
# caused inconsistent cache issues. see
# https://github.com/reallyenglish/ansible-role-rabbitmq/issues/22
sudo yum -y remove epel-release
sudo rm -f /etc/yum.repos.d/epel.repo.rpmsave
sudo yum history new
sudo truncate -c -s 0 /var/log/yum.log
