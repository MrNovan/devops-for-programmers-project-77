#!/bin/bash

yc_token=$(ansible-vault view ansible/group_vars/webservers/vault.yml | grep yc_token | awk '{print $2}')

cat <<EOF > terraform/terraform.auto.tfvars.json
{
  "yc_token": "$yc_token",
  "cloud_id": "b1ga7bs7bhi8j18avv94",
  "folder_id": "b1gd31b1da4n6mjmjtub"
}
EOF