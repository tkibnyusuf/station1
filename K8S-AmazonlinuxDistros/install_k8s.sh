#!/bin/bash
set -e

echo "[1/10] Updating system..."
sudo dnf update -y

echo "[2/10] Installing required packages (no curl/gnupg2 to avoid conflicts)..."
# AL2023 already has curl-minimal and gnupg2-minimal, so we avoid curl/gnupg2 here.
sudo dnf install -y conntrack-tools ipset socat ebtables ethtool

echo "[3/10] Disabling swap..."
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

echo "[4/10] Loading kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "[5/10] Setting sysctl params..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

echo "[6/10] Installing containerd..."
sudo dnf install -y containerd

echo "[7/10] Configuring containerd..."
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

# enable systemd cgroups
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl enable containerd
sudo systemctl restart containerd

echo "[8/10] Adding Kubernetes 1.34 repo..."
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

echo "[9/10] Installing kubeadm, kubelet, kubectl..."
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

echo "[10/10] Enabling kubelet..."
sudo systemctl enable kubelet
sudo systemctl start kubelet

echo "===================================================="
echo "Kubernetes install complete on Amazon Linux 2023!"
echo
echo "If this is the CONTROL PLANE node, run:"
echo "  sudo kubeadm init --pod-network-cidr=192.168.0.0/16"
echo
echo "Then for your user:"
echo "  mkdir -p \$HOME/.kube"
echo "  sudo cp /etc/kubernetes/admin.conf \$HOME/.kube/config"
echo "  sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
echo
echo "Install Calico CNI:"
echo "  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/tigera-operator.yaml"
echo "  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/custom-resources.yaml"
echo "===================================================="
