#!/bin/bash

#Download microshit source code
git clone https://github.com/openshift/microshift.git
cd microshift

#Configure OCP sources
OSVERSION=$(awk -F: '{print $5}' /etc/system-release-cpe)
OCP_REPO_NAME=rhocp-4.13-for-rhel-${OSVERSION}-mirrorbeta-$(uname -m)-rpms
sudo tee /etc/yum.repos.d/${OCP_REPO_NAME}.repo >/dev/null <<EOF
[${OCP_REPO_NAME}]
name=Beta rhocp-4.13 RPMs for RHEL ${OSVERSION}
baseurl=https://mirror.openshift.com/pub/openshift-v4/\$basearch/dependencies/rpms/4.13-el${OSVERSION}-beta/
enabled=1
gpgcheck=0
skip_if_unavailable=0
EOF
sudo subscription-manager config --rhsm.manage_repos=1

# Download the OpenShift pull secret from the https://console.redhat.com/openshift/downloads#tool-pull-secret page and save it into the ~/.pull-secret.json file.
cp pull-secret.json ~/.pull-secret.json

# Prepare image builder and other required packages 
chmod 755 ~
./scripts/image-builder/configure.sh

# Build microshift rpm packages
dnf install -y golang selinux-policy-devel
make rpm

# Build RHEL for Edge image
./scripts/image-builder/build.sh -pull_secret_file ~/.pull-secret.json
mv _output/image-builder/microshift-installer-*.iso /var/lib/libvirt/images/microshit.iso

# Start microshift edge VM
virsh net-start --network default
VMNAME=microshift-edge
NETNAME=default
CDROM=/var/lib/libvirt/images/microshit.iso
virt-install \
    --name ${VMNAME} \
    --vcpus 2 \
    --memory 3072 \
    --disk path=/var/lib/libvirt/images/${VMNAME}.qcow2,size=20 \
    --network network=${NETNAME},model=virtio \
    --os-type generic \
    --events on_reboot=restart \
    --cdrom ${CDROM} \
    --noautoconsole \
    --wait
