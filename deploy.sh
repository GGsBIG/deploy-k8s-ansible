#!/bin/bash

# Deploy K8s cluster using Ansible
echo "==========================================="
echo "Kubernetes Cluster Deployment Script"
echo "==========================================="

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "Installing Ansible..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        brew install ansible
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        sudo apt update && sudo apt install -y ansible
    else
        echo "Please install Ansible manually for your OS"
        exit 1
    fi
fi

# Function to run individual stages
run_stage() {
    local stage_num=$1
    local stage_name=$2
    local playbook=$3
    
    echo ""
    echo "===========================================" 
    echo "Stage ${stage_num}: ${stage_name}"
    echo "==========================================="
    
    if ansible-playbook -i inventory.ini "${playbook}"; then
        echo "✅ Stage ${stage_num} completed successfully"
    else
        echo "❌ Stage ${stage_num} failed"
        exit 1
    fi
}

# Main deployment function
deploy_full() {
    echo "Starting full cluster deployment..."
    
    run_stage 1 "System Setup" "playbooks/01-system-setup.yml"
    run_stage 2 "Container Runtime" "playbooks/02-container-runtime.yml"
    run_stage 3 "Kubernetes Install" "playbooks/03-kubernetes-install.yml"
    run_stage 4 "Kube-VIP Setup" "playbooks/04-kube-vip-setup.yml"
    run_stage 5 "Cluster Initialization" "playbooks/05-cluster-init.yml"
    run_stage 6 "Network Setup" "playbooks/06-network-setup.yml"
    run_stage 7 "Join Masters" "playbooks/07-join-masters.yml"
    run_stage 8 "Join Workers" "playbooks/08-join-workers.yml"
    run_stage 9 "Finalize Cluster" "playbooks/09-finalize-cluster.yml"
    
    echo ""
    echo "🎉 Deployment completed successfully!"
    echo "To access the cluster, copy the kubeconfig from master-01:/etc/kubernetes/admin.conf"
}

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help                    Show this help message"
    echo "  -f, --full                    Run full deployment (default)"
    echo "  -s, --stage <stage_number>    Run specific stage (1-9)"
    echo "  -l, --list                    List all available stages"
    echo "  --site                        Run using site.yml (all stages at once)"
    echo ""
    echo "Stages:"
    echo "  1. System Setup"
    echo "  2. Container Runtime"
    echo "  3. Kubernetes Install"
    echo "  4. Kube-VIP Setup"
    echo "  5. Cluster Initialization"
    echo "  6. Network Setup"
    echo "  7. Join Masters"
    echo "  8. Join Workers"
    echo "  9. Finalize Cluster"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    -l|--list)
        echo "Available stages:"
        echo "  1. System Setup"
        echo "  2. Container Runtime"  
        echo "  3. Kubernetes Install"
        echo "  4. Kube-VIP Setup"
        echo "  5. Cluster Initialization"
        echo "  6. Network Setup"
        echo "  7. Join Masters"
        echo "  8. Join Workers"
        echo "  9. Finalize Cluster"
        exit 0
        ;;
    -s|--stage)
        if [[ -z "${2:-}" ]]; then
            echo "Error: Stage number required"
            usage
            exit 1
        fi
        
        case "$2" in
            1) run_stage 1 "System Setup" "playbooks/01-system-setup.yml" ;;
            2) run_stage 2 "Container Runtime" "playbooks/02-container-runtime.yml" ;;
            3) run_stage 3 "Kubernetes Install" "playbooks/03-kubernetes-install.yml" ;;
            4) run_stage 4 "Kube-VIP Setup" "playbooks/04-kube-vip-setup.yml" ;;
            5) run_stage 5 "Cluster Initialization" "playbooks/05-cluster-init.yml" ;;
            6) run_stage 6 "Network Setup" "playbooks/06-network-setup.yml" ;;
            7) run_stage 7 "Join Masters" "playbooks/07-join-masters.yml" ;;
            8) run_stage 8 "Join Workers" "playbooks/08-join-workers.yml" ;;
            9) run_stage 9 "Finalize Cluster" "playbooks/09-finalize-cluster.yml" ;;
            *) echo "Error: Invalid stage number. Use 1-9." && exit 1 ;;
        esac
        ;;
    --site)
        echo "Running site.yml (all stages at once)..."
        ansible-playbook -i inventory.ini site.yml
        ;;
    -f|--full|"")
        deploy_full
        ;;
    *)
        echo "Error: Unknown option $1"
        usage
        exit 1
        ;;
esac