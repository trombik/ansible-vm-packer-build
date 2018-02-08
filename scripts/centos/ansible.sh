#!/bin/bash

set -e
set -x

sudo yum -y --enablerepo=epel install ansible
sudo yum -y install rsync
