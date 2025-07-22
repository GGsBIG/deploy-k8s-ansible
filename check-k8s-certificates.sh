#!/bin/bash

# Kubernetes Master Node Certificate Expiration Check Script
# This script checks the expiration dates of Kubernetes certificates on master nodes

set -e

# Color codes for output formatting
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WARN_DAYS=30  # Warning threshold in days
CRITICAL_DAYS=7  # Critical threshold in days
LOG_FILE="/var/log/k8s-cert-check.log"

echo -e "${BLUE}=== Kubernetes Certificate Expiration Check ===${NC}"
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo

# Function to check if running on master node
check_master_node() {
    if [ ! -d "/etc/kubernetes/pki" ]; then
        echo -e "${RED}Error: /etc/kubernetes/pki directory not found${NC}"
        echo "This script should be run on a Kubernetes master node"
        exit 1
    fi
}

# Function to calculate days until expiration
calculate_days_until_expiry() {
    local cert_file=$1
    local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry_date" +%s)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
    echo $days_until_expiry
}

# Function to get certificate details
get_cert_info() {
    local cert_file=$1
    local cert_name=$2
    
    if [ ! -f "$cert_file" ]; then
        echo -e "${RED}Certificate not found: $cert_file${NC}"
        return
    fi
    
    local subject=$(openssl x509 -in "$cert_file" -noout -subject | sed 's/subject=//')
    local issuer=$(openssl x509 -in "$cert_file" -noout -issuer | sed 's/issuer=//')
    local start_date=$(openssl x509 -in "$cert_file" -noout -startdate | cut -d= -f2)
    local end_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    local days_until_expiry=$(calculate_days_until_expiry "$cert_file")
    
    # Determine status color
    local status_color=$GREEN
    local status="OK"
    
    if [ $days_until_expiry -le $CRITICAL_DAYS ]; then
        status_color=$RED
        status="CRITICAL"
    elif [ $days_until_expiry -le $WARN_DAYS ]; then
        status_color=$YELLOW
        status="WARNING"
    fi
    
    echo -e "${BLUE}Certificate: $cert_name${NC}"
    echo "  File: $cert_file"
    echo "  Subject: $subject"
    echo "  Valid From: $start_date"
    echo "  Valid Until: $end_date"
    echo -e "  Status: ${status_color}$status${NC}"
    echo -e "  Days Until Expiry: ${status_color}$days_until_expiry${NC}"
    echo
    
    # Log to file
    echo "$(date): $cert_name - Days until expiry: $days_until_expiry ($status)" >> "$LOG_FILE"
}

# Function to check kubeadm certificate status
check_kubeadm_certs() {
    echo -e "${BLUE}=== Checking certificates via kubeadm ===${NC}"
    
    if command -v kubeadm &> /dev/null; then
        kubeadm certs check-expiration 2>/dev/null || echo "kubeadm certs check-expiration failed"
    else
        echo "kubeadm command not found, skipping kubeadm certificate check"
    fi
    echo
}

# Function to check individual certificate files
check_individual_certs() {
    echo -e "${BLUE}=== Individual Certificate Files Check ===${NC}"
    
    # Define certificate files to check
    declare -A cert_files=(
        ["API Server"]="/etc/kubernetes/pki/apiserver.crt"
        ["API Server Kubelet Client"]="/etc/kubernetes/pki/apiserver-kubelet-client.crt"
        ["API Server etcd Client"]="/etc/kubernetes/pki/apiserver-etcd-client.crt"
        ["Front Proxy Client"]="/etc/kubernetes/pki/front-proxy-client.crt"
        ["etcd Server"]="/etc/kubernetes/pki/etcd/server.crt"
        ["etcd Peer"]="/etc/kubernetes/pki/etcd/peer.crt"
        ["etcd Healthcheck Client"]="/etc/kubernetes/pki/etcd/healthcheck-client.crt"
        ["CA Certificate"]="/etc/kubernetes/pki/ca.crt"
        ["etcd CA Certificate"]="/etc/kubernetes/pki/etcd/ca.crt"
        ["Front Proxy CA"]="/etc/kubernetes/pki/front-proxy-ca.crt"
    )
    
    for cert_name in "${!cert_files[@]}"; do
        get_cert_info "${cert_files[$cert_name]}" "$cert_name"
    done
}

# Function to check kubelet certificates
check_kubelet_certs() {
    echo -e "${BLUE}=== Kubelet Certificate Check ===${NC}"
    
    local kubelet_cert="/var/lib/kubelet/pki/kubelet-client-current.pem"
    local kubelet_server_cert="/var/lib/kubelet/pki/kubelet.crt"
    
    if [ -f "$kubelet_cert" ]; then
        get_cert_info "$kubelet_cert" "Kubelet Client Certificate"
    fi
    
    if [ -f "$kubelet_server_cert" ]; then
        get_cert_info "$kubelet_server_cert" "Kubelet Server Certificate"
    fi
}

# Function to generate summary report
generate_summary() {
    echo -e "${BLUE}=== Summary Report ===${NC}"
    
    local critical_count=0
    local warning_count=0
    local ok_count=0
    
    # Count certificates by status
    for cert_file in /etc/kubernetes/pki/*.crt /etc/kubernetes/pki/etcd/*.crt /var/lib/kubelet/pki/*.pem /var/lib/kubelet/pki/*.crt; do
        if [ -f "$cert_file" ]; then
            local days_until_expiry=$(calculate_days_until_expiry "$cert_file")
            
            if [ $days_until_expiry -le $CRITICAL_DAYS ]; then
                ((critical_count++))
            elif [ $days_until_expiry -le $WARN_DAYS ]; then
                ((warning_count++))
            else
                ((ok_count++))
            fi
        fi
    done
    
    echo "Certificate Status Summary:"
    echo -e "  ${GREEN}OK: $ok_count${NC}"
    echo -e "  ${YELLOW}Warning: $warning_count${NC}"
    echo -e "  ${RED}Critical: $critical_count${NC}"
    echo
    
    if [ $critical_count -gt 0 ]; then
        echo -e "${RED}⚠️  CRITICAL: $critical_count certificate(s) expiring within $CRITICAL_DAYS days!${NC}"
        echo -e "${RED}Action required: Renew certificates immediately${NC}"
    elif [ $warning_count -gt 0 ]; then
        echo -e "${YELLOW}⚠️  WARNING: $warning_count certificate(s) expiring within $WARN_DAYS days${NC}"
        echo -e "${YELLOW}Action recommended: Plan certificate renewal${NC}"
    else
        echo -e "${GREEN}✅ All certificates are valid and not expiring soon${NC}"
    fi
    echo
}

# Function to show renewal commands
show_renewal_commands() {
    echo -e "${BLUE}=== Certificate Renewal Commands ===${NC}"
    echo "To renew Kubernetes certificates, use the following commands:"
    echo
    echo "1. Check current certificate expiration:"
    echo "   sudo kubeadm certs check-expiration"
    echo
    echo "2. Renew all certificates:"
    echo "   sudo kubeadm certs renew all"
    echo
    echo "3. Renew specific certificates:"
    echo "   sudo kubeadm certs renew apiserver"
    echo "   sudo kubeadm certs renew apiserver-kubelet-client"
    echo "   sudo kubeadm certs renew controller-manager.conf"
    echo "   sudo kubeadm certs renew scheduler.conf"
    echo "   sudo kubeadm certs renew admin.conf"
    echo
    echo "4. After renewal, restart control plane components:"
    echo "   sudo systemctl restart kubelet"
    echo
    echo "Note: Always backup your certificates before renewal!"
    echo
}

# Function to setup cron job for regular checks
setup_cron_job() {
    echo -e "${BLUE}=== Setting up automatic certificate monitoring ===${NC}"
    
    local script_path=$(realpath "$0")
    local cron_job="0 9 * * * $script_path --quiet >> $LOG_FILE 2>&1"
    
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "$script_path"; then
        echo "Cron job already exists for certificate monitoring"
    else
        echo "Adding daily certificate check to crontab..."
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        echo "✅ Daily certificate check scheduled at 9:00 AM"
    fi
    
    echo "Log file location: $LOG_FILE"
    echo
}

# Main execution
main() {
    # Parse command line arguments
    local quiet_mode=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quiet|-q)
                quiet_mode=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --quiet, -q    Run in quiet mode (minimal output)"
                echo "  --help, -h     Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Create log file if it doesn't exist
    sudo touch "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
    
    # Check if running on master node
    check_master_node
    
    if [ "$quiet_mode" = false ]; then
        # Interactive mode - show detailed output
        check_kubeadm_certs
        check_individual_certs
        check_kubelet_certs
        generate_summary
        show_renewal_commands
        
        # Ask if user wants to setup cron job
        echo -n "Would you like to setup automatic daily certificate monitoring? (y/n): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            setup_cron_job
        fi
    else
        # Quiet mode - only log critical issues
        local critical_found=false
        
        for cert_file in /etc/kubernetes/pki/*.crt /etc/kubernetes/pki/etcd/*.crt; do
            if [ -f "$cert_file" ]; then
                local days_until_expiry=$(calculate_days_until_expiry "$cert_file")
                if [ $days_until_expiry -le $CRITICAL_DAYS ]; then
                    echo "CRITICAL: Certificate $cert_file expires in $days_until_expiry days"
                    critical_found=true
                fi
            fi
        done
        
        if [ "$critical_found" = false ]; then
            echo "All certificates are within acceptable expiration timeframes"
        fi
    fi
}

# Execute main function with all arguments
main "$@"