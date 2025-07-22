#!/bin/bash

# Kubernetes Cluster Cleanup Script for Ubuntu 20.04
# This script completely removes Kubernetes cluster and all related components

set -e

echo "=== Kubernetes Cluster Cleanup Script for Ubuntu 20.04 ==="
echo "WARNING: This will completely remove Kubernetes cluster and all related components!"
echo "Press Ctrl+C to cancel, or wait 10 seconds to continue..."
sleep 10

echo "Starting cleanup process..."

# Step 1: Stop Kubernetes services
echo "Step 1: Stopping Kubernetes services..."
sudo kubeadm reset -f --force 2>/dev/null || true

sudo systemctl stop kubelet 2>/dev/null || true
sudo systemctl disable kubelet 2>/dev/null || true
sudo systemctl stop docker 2>/dev/null || true
sudo systemctl disable docker 2>/dev/null || true
sudo systemctl stop containerd 2>/dev/null || true
sudo systemctl disable containerd 2>/dev/null || true

# Step 2: Clean up all virtual network interfaces
echo "Step 2: Cleaning up virtual network interfaces..."
ip link show | grep -E 'cali|flannel|tunl|vxlan|docker|cni|kube' | awk -F: '{print $2}' | while read iface; do
    iface=$(echo "$iface" | tr -d ' ')
    if [ -n "$iface" ]; then
        sudo ip link set "$iface" down 2>/dev/null || true
        sudo ip link delete "$iface" 2>/dev/null || true
    fi
done

# Clean up bridge interfaces
ip link show type bridge | awk -F: '{print $2}' | grep -E 'docker|cni|kube|cali' | while read bridge; do
    bridge=$(echo "$bridge" | tr -d ' ')
    if [ -n "$bridge" ]; then
        sudo ip link set "$bridge" down 2>/dev/null || true
        sudo ip link delete "$bridge" 2>/dev/null || true
    fi
done

# Remove all veth pairs
ip link show type veth | awk -F: '{print $2}' | while read veth; do
    veth=$(echo "$veth" | tr -d ' ')
    if [ -n "$veth" ]; then
        sudo ip link delete "$veth" 2>/dev/null || true
    fi
done

# Clear routing tables
sudo ip route flush table main 2>/dev/null || true
sudo ip route flush cache 2>/dev/null || true

# Step 3: Unload kernel modules
echo "Step 3: Unloading kernel modules..."
sudo modprobe -r br_netfilter 2>/dev/null || true
sudo modprobe -r overlay 2>/dev/null || true
sudo modprobe -r ip_vs 2>/dev/null || true
sudo modprobe -r ip_vs_rr 2>/dev/null || true
sudo modprobe -r ip_vs_wrr 2>/dev/null || true
sudo modprobe -r ip_vs_sh 2>/dev/null || true
sudo modprobe -r nf_conntrack 2>/dev/null || true
sudo modprobe -r veth 2>/dev/null || true
sudo modprobe -r bridge 2>/dev/null || true
sudo modprobe -r xt_nat 2>/dev/null || true

# Step 4: Remove all related directories and configurations
echo "Step 4: Removing directories and configurations..."
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/kubelet/
sudo rm -rf /var/lib/etcd/
sudo rm -rf /etc/cni/
sudo rm -rf /opt/cni/
sudo rm -rf ~/.kube/
sudo rm -rf /root/.kube/

# Remove container runtime directories
sudo rm -rf /var/lib/containerd/
sudo rm -rf /etc/containerd/
sudo rm -rf /var/lib/docker/
sudo rm -rf /etc/docker/
sudo rm -rf /run/containerd/
sudo rm -rf /run/docker/

# Remove network configurations
sudo rm -rf /etc/systemd/network/10-calico.netdev 2>/dev/null || true
sudo rm -rf /etc/systemd/network/10-calico.network 2>/dev/null || true
sudo rm -rf /run/flannel/ 2>/dev/null || true
sudo rm -rf /etc/kube-flannel/ 2>/dev/null || true

# Step 5: Clear iptables and ipvs rules
echo "Step 5: Clearing iptables and ipvs rules..."
sudo iptables -t filter -F 2>/dev/null || true
sudo iptables -t filter -X 2>/dev/null || true
sudo iptables -t nat -F 2>/dev/null || true
sudo iptables -t nat -X 2>/dev/null || true
sudo iptables -t mangle -F 2>/dev/null || true
sudo iptables -t mangle -X 2>/dev/null || true
sudo iptables -t raw -F 2>/dev/null || true
sudo iptables -t raw -X 2>/dev/null || true

# Reset iptables default policies
sudo iptables -P INPUT ACCEPT 2>/dev/null || true
sudo iptables -P FORWARD ACCEPT 2>/dev/null || true
sudo iptables -P OUTPUT ACCEPT 2>/dev/null || true

# Clear ipvs rules
sudo ipvsadm -C 2>/dev/null || true

# Step 6: Uninstall all related packages
echo "Step 6: Uninstalling packages..."
# Remove Kubernetes packages
sudo apt-get remove -y kubeadm kubectl kubelet kubernetes-cni 2>/dev/null || true
sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni 2>/dev/null || true

# Remove container runtime packages
sudo apt-get remove -y containerd.io docker-ce docker-ce-cli docker-compose-plugin 2>/dev/null || true
sudo apt-get remove -y podman buildah skopeo 2>/dev/null || true
sudo apt-get remove -y runc containernetworking-plugins 2>/dev/null || true
sudo apt-get purge -y containerd.io docker-ce docker-ce-cli docker-compose-plugin 2>/dev/null || true
sudo apt-get purge -y podman buildah skopeo 2>/dev/null || true
sudo apt-get purge -y runc containernetworking-plugins 2>/dev/null || true

# Remove repository files
sudo rm -f /etc/apt/sources.list.d/kubernetes.list 2>/dev/null || true
sudo rm -f /etc/apt/sources.list.d/docker.list 2>/dev/null || true
sudo rm -f /etc/apt/keyrings/kubernetes-archive-keyring.gpg 2>/dev/null || true
sudo rm -f /etc/apt/keyrings/docker.gpg 2>/dev/null || true
sudo rm -f /usr/share/keyrings/kubernetes-archive-keyring.gpg 2>/dev/null || true

# Step 7: Clear system configurations
echo "Step 7: Clearing system configurations..."
sudo rm -rf /etc/systemd/system/kubelet.service.d/
sudo rm -rf /etc/systemd/system/docker.service.d/
sudo rm -rf /etc/systemd/system/containerd.service.d/

# Remove module loading configurations
sudo rm -f /etc/modules-load.d/k8s.conf
sudo rm -f /etc/modules-load.d/containerd.conf
sudo rm -f /etc/modules-load.d/docker.conf

# Remove sysctl configurations
sudo rm -f /etc/sysctl.d/k8s.conf
sudo rm -f /etc/sysctl.d/99-kubernetes-cri.conf

# Reload systemd
sudo systemctl daemon-reload
sudo systemctl reset-failed

# Step 8: Clear cache and temporary files
echo "Step 8: Clearing cache and temporary files..."
sudo apt-get autoremove -y 2>/dev/null || true
sudo apt-get autoclean 2>/dev/null || true
sudo apt-get clean 2>/dev/null || true

# Clear systemd logs (optional)
sudo journalctl --vacuum-time=1d 2>/dev/null || true

# Clear temporary files
sudo rm -rf /tmp/k8s-*
sudo rm -rf /tmp/calico-*
sudo rm -rf /tmp/containerd-*

# Step 9: Reset network and restart services
echo "Step 9: Resetting network..."
sudo sysctl --system 2>/dev/null || true
sudo systemctl restart systemd-networkd 2>/dev/null || true
sudo systemctl restart networking 2>/dev/null || true

# Step 10: Verification
echo "Step 10: Verifying cleanup..."
echo "=== Checking for remaining Kubernetes processes ==="
ps aux | grep -E 'kube|docker|containerd' | grep -v grep || echo "No Kubernetes processes found"

echo "=== Checking network interfaces ==="
ip link show | grep -E 'cali|flannel|tunl|vxlan|docker|cni|kube' || echo "No Kubernetes network interfaces found"

echo "=== Checking mount points ==="
mount | grep -E 'kube|docker|containerd' || echo "No Kubernetes mount points found"

echo "=== Checking installed packages ==="
dpkg -l | grep -E 'kube|docker|containerd' || echo "No Kubernetes packages found"

echo "=== Checking iptables rules ==="
sudo iptables -L -n -v | grep -E 'kube|docker|cali' || echo "No Kubernetes iptables rules found"

echo "=== Checking loaded modules ==="
lsmod | grep -E 'br_netfilter|overlay|ip_vs' || echo "No Kubernetes modules loaded"

echo ""
echo "=== Cleanup completed! ==="
echo "It's recommended to reboot the system to ensure complete cleanup:"
echo "sudo reboot"
echo ""
echo "After reboot, you can verify the cleanup by running:"
echo "docker version 2>/dev/null || echo 'Docker removed successfully'"
echo "kubectl version 2>/dev/null || echo 'kubectl removed successfully'"
echo "systemctl status kubelet 2>/dev/null || echo 'kubelet service removed'"