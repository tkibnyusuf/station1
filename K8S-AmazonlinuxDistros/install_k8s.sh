#!/bin/bash

# Update the system
sudo yum update -y

# Install Docker
sudo amazon-linux-extras install docker -y
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# Disable SELinux (not recommended for production environments)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Disable swap
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# Install kubeadm, kubelet, and kubectl
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# Install Kubernetes packages
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# Enable and start kubelet
sudo systemctl enable --now kubelet

# Configure sysctl for Kubernetes networking
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system