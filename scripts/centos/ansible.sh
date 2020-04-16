#!/bin/bash

set -e
set -x

sudo yum -y --enablerepo=epel install python3 ansible
sudo yum -y install rsync
