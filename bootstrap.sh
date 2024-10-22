#!/bin/bash
component=$1
environment=$2
app_version=$3
yum install ansible -y

ansible-pull -U https://github.com/swamy527/roboshop-ansible-roles-tf.git -e component=$component -e env=$environment -e app_version=$app_version main-tf.yaml