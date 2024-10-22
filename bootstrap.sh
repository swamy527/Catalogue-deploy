#!/bin/bash
component=$1
environment=$2
yum install ansible -y

ansible-pull -U https://github.com/swamy527/roboshop-ansible-roles-tf.git -e component=$component -e env=$environment main-tf.yaml