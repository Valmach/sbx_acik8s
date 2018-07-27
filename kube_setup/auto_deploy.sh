#! /bin/bash

POD_NUM=$1
POD_PASS=$2

echo "Pod Number: ${POD_NUM}"
echo "Pod Password: ${POD_PASS}"

if [ -z ${POD_NUM} ] || [ -z ${POD_PASS} ]
then
  echo "You mush provide a pod number and pod password."
  echo " ./auto_deploy.sh POD_NUM POD_PASS"
  exit
fi

# 1. Basic DevBox Setup
#
echo "Setup DevBox with Development Tools and Repos"
sudo yum install wget git sshpass
#
wget https://bootstrap.pypa.io/get-pip.py
sudo python get-pip.py
rm get-pip.py
sudo pip install virtualenv

git clone https://github.com/DevNetSandbox/sbx_acik8s ~/sbx_acik8s
cd ~/sbx_acik8s

# temporary for dev
git fetch
git checkout auto_deploy

virtualenv venv
source venv/bin/activate
pip install -r kube_setup/requirements.txt

echo " "

echo "Create and deploy RSA keys for passwordless login to pod nodes from DevBox"
cd ~/sbx_acik8s/kube_setup
ansible-playbook -i inventory/sbx${POD_NUM}-hosts \
  -e "ansible_ssh_pass=${POD_PASS}" \
  ssh_authorized_key_setup.yaml
echo " "

echo "Run kube_devbox_setup.yml"
ansible-playbook -i inventory/sbx${POD_NUM}-hosts \
  kube_devbox_setup.yml
echo " "

echo "Run kube_network_prep.yaml"
ansible-playbook -i inventory/sbx${POD_NUM}-hosts \
  kube_network_prep.yaml
echo

echo "Run kube_prereq_install.yml"
ansible-playbook -i inventory/sbx${POD_NUM}-hosts \
  kube_prereq_install.yml
echo " "

echo "Run kube_install.yaml"
ansible-playbook -i inventory/sbx${POD_NUM}-hosts \
  --extra-vars "POD_NUM=${POD_NUM}" \
  kube_install.yaml
echo " "

echo "Install ACI CNI Plugin"
cd ~/sbx_acik8s/kube_setup/aci_setup/sbx${POD_NUM}
kubectl apply -f aci-containers.yaml
echo " "
