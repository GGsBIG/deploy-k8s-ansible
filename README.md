# Kubernetes Cluster Deployment

Automated deployment of high-availability Kubernetes cluster using Ansible scripts

## Deployment Steps

### 1. Configure Inventory
```bash
# Edit the main inventory file with your VM information
vim /deploy-k8s-ansible/inventory.ini

# Example configuration:
# [masters]
# master-01 ansible_host=10.10.7.236 hostname=master-01
# master-02 ansible_host=10.10.7.237 hostname=master-02
# master-03 ansible_host=10.10.7.238 hostname=master-03
#
# [workers]
# worker-01 ansible_host=10.10.7.239 hostname=worker-01
# worker-02 ansible_host=10.10.7.240 hostname=worker-02
#
# [all:vars]
# ansible_user=bbg
# ansible_become_pass=1qaz@WSX
# ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### 2. Execute SSH Setup Script
```bash
# Grant execution permission
chmod +x /deploy-k8s-ansible/setup-ssh/setup_ssh.sh
```

### 3. Start Kubernetes Cluster Deployment
```bash
# Grant execution permission to deployment script
chmod +x /deploy-k8s-ansible/deploy.sh
```

## Cluster Architecture

- **VIP**: 10.10.7.235 (kube-vip)
- **Master Nodes**: 
  - master-01: 10.10.7.236
  - master-02: 10.10.7.237  
  - master-03: 10.10.7.238
- **Worker Nodes**:
  - worker-01: 10.10.7.239
  - worker-02: 10.10.7.240

## Deployment Stages

### Stage 1: System Setup (01-system-setup.yml)
- Configure Taiwan timezone
- Install and configure chrony time synchronization
- Disable swap
- Load kernel modules
- Configure sysctl parameters

### Stage 2: Container Runtime (02-container-runtime.yml)
- Install containerd
- Install runc
- Install CNI plugins
- Configure containerd and crictl

### Stage 3: Kubernetes Installation (03-kubernetes-install.yml)
- Add Kubernetes APT repository
- Install kubelet, kubeadm, kubectl
- Lock package versions

### Stage 4: Kube-VIP Setup (04-kube-vip-setup.yml)
- Configure kube-vip manifest
- Prepare high-availability API Server

### Stage 5: Cluster Initialization (05-cluster-init.yml)
- Initialize first master using kubeadm
- Generate join token
- Configure kubeconfig

### Stage 6: Network Setup (06-network-setup.yml)
- Deploy Calico CNI
- Wait for network components to be ready

### Stage 7: Join Master Nodes (07-join-masters.yml)
- Other master nodes join the cluster
- Configure kubeconfig for each node

### Stage 8: Join Worker Nodes (08-join-workers.yml)
- Worker nodes join the cluster
- Verify node status

### Stage 9: Finalize Setup (09-finalize-cluster.yml)
- Add labels to worker nodes
- Check cluster status
- Generate cluster information

## Usage

### Full Deployment
```bash
./deploy.sh
# or
./deploy.sh --full
```

### Execute Specific Stage
```bash
./deploy.sh --stage 1    # Execute stage 1
./deploy.sh --stage 5    # Execute stage 5
```

### Use site.yml to Execute All Stages
```bash
./deploy.sh --site
```

### List All Stages
```bash
./deploy.sh --list
```

### Show Help
```bash
./deploy.sh --help
```

## File Structure

```
├── inventory.ini              # Main Ansible host inventory (only file you need to edit)
├── site.yml                   # Main orchestration playbook
├── deploy.sh                  # Deployment script
├── setup-ssh/
│   └── setup_ssh.sh           # SSH setup script (reads from main inventory.ini)
├── templates/
│   └── init-config.yaml.j2    # kubeadm configuration template
└── playbooks/
    ├── 01-system-setup.yml
    ├── 02-container-runtime.yml
    ├── 03-kubernetes-install.yml
    ├── 04-kube-vip-setup.yml
    ├── 05-cluster-init.yml
    ├── 06-network-setup.yml
    ├── 07-join-masters.yml
    ├── 08-join-workers.yml
    └── 09-finalize-cluster.yml
```

## Prerequisites

1. **Ansible Installation**
   - macOS: `brew install ansible`
   - Linux: `sudo apt install ansible`

2. **SSH Connection**
   - Ensure root SSH access to all nodes
   - Or configure passwordless sudo

3. **System Requirements**
   - Ubuntu 20.04/22.04
   - Minimum 2GB RAM
   - Minimum 2 CPU cores

## Post-Deployment Operations

1. **Get kubeconfig**
   ```bash
   scp root@10.10.7.236:/etc/kubernetes/admin.conf ~/.kube/config
   ```

2. **Verify Cluster**
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

3. **Install Additional Components**
   - Ingress Controller
   - Storage Classes
   - Monitoring (Prometheus/Grafana)
   - Logging (ELK Stack)

## Troubleshooting

- Check specific stage logs
- Re-execute failed stages
- Verify network connectivity and SSH permissions
- Ensure sufficient system resources

## Version Information

- Kubernetes: 1.31
- Containerd: 1.7.27
- Calico: v3.30.2
- kube-vip: Latest version