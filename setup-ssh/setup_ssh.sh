#!/bin/bash
set -e


if ! command -v sshpass &> /dev/null; then
    echo -e "\033[0;31mError: sshpass not installed\033[0m"
    echo "Installing sshpass automatically..."
    
    # Try to install sshpass automatically
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y sshpass
    elif command -v yum &> /dev/null; then
        sudo yum install -y sshpass
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y sshpass
    elif command -v brew &> /dev/null; then
        brew install sshpass
    else
        echo "Please install sshpass manually:"
        echo "  Ubuntu/Debian: sudo apt install sshpass"
        echo "  CentOS/RHEL: sudo yum install sshpass"
        echo "  Fedora: sudo dnf install sshpass"
        echo "  macOS: brew install sshpass"
        exit 1
    fi
    
    # Check if installation was successful
    if ! command -v sshpass &> /dev/null; then
        echo -e "\033[0;31mFailed to install sshpass. Please install manually.\033[0m"
        exit 1
    else
        echo -e "\033[0;32m✓ sshpass installed successfully\033[0m"
    fi
fi

# Configuration file
INVENTORY_FILE="inventory.ini"

# Variables to be loaded from inventory.ini
USERNAME=""
USER_PASSWORD=""
ROOT_PASSWORD=""
SSH_KEY_PATH=""
NODES=()

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Ultra Simple SSH Setup ===${NC}"

# Load configuration from inventory.ini
load_config() {
    local inventory_file="$1"
    local in_config_section=false
    local in_nodes_section=false
    
    if [[ ! -f "$inventory_file" ]]; then
        echo -e "${RED}Error: Inventory file '$inventory_file' not found!${NC}"
        echo "Please create inventory.ini with configuration"
        exit 1
    fi
    
    echo "Loading configuration from: $inventory_file"
    
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        if [[ "$line" =~ ^\[.*\]$ ]]; then
            if [[ "$line" == "[config]" ]]; then
                in_config_section=true
                in_nodes_section=false
            elif [[ "$line" == "[master]" || "$line" == "[worker]" || "$line" == "[nodes]" ]]; then
                in_config_section=false
                in_nodes_section=true
            elif [[ "$line" == "[nodes:children]" ]]; then
                in_nodes_section=false
            else
                in_config_section=false
                in_nodes_section=false
            fi
            continue
        fi
        
        # Parse config variables
        if [[ "$in_config_section" == true && "$line" =~ ^[a-zA-Z_][a-zA-Z0-9_]*= ]]; then
            key=$(echo "$line" | cut -d'=' -f1)
            value=$(echo "$line" | cut -d'=' -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            
            case "$key" in
                "username") USERNAME="$value" ;;
                "password") USER_PASSWORD="$value" ;;
                "root_password") ROOT_PASSWORD="$value" ;;
                "ssh_key_path") SSH_KEY_PATH="${value/#\~/$HOME}" ;;
            esac
        fi
        
        # Parse node IPs and hostnames
        if [[ "$in_nodes_section" == true && "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            ip=$(echo "$line" | awk '{print $1}')
            
            # Extract hostname from hostname parameter or comment
            hostname=""
            if [[ "$line" =~ hostname=([a-zA-Z0-9-]+) ]]; then
                hostname="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ \#[[:space:]]*([a-zA-Z0-9-]+) ]]; then
                hostname="${BASH_REMATCH[1]}"
            fi
            
            NODES+=("$ip:$hostname")
        fi
    done < "$inventory_file"
    
    # Validate required variables
    if [[ -z "$USERNAME" || -z "$USER_PASSWORD" || -z "$ROOT_PASSWORD" || -z "$SSH_KEY_PATH" ]]; then
        echo -e "${RED}Error: Missing required configuration!${NC}"
        echo "Required: username, password, root_password, ssh_key_path"
        exit 1
    fi
    
    if [[ ${#NODES[@]} -eq 0 ]]; then
        echo -e "${RED}Error: No nodes found in inventory!${NC}"
        exit 1
    fi
    
    echo "✓ Configuration loaded"
    echo "  Username: $USERNAME"
    echo "  SSH Key: $SSH_KEY_PATH"
    echo "  Nodes: ${#NODES[@]} found"
}

# Load configuration
load_config "$INVENTORY_FILE"

# Generate SSH key if not exists
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "admin@$(hostname)"
    echo "✓ SSH key generated"
else
    echo "✓ SSH key exists"
fi

# Setup each node
for node_entry in "${NODES[@]}"; do
    # Parse IP and hostname
    IFS=':' read -r node_ip hostname <<< "$node_entry"
    
    echo "----------------------------------------"
    if [[ -n "$hostname" ]]; then
        echo "Setting up: $node_ip (hostname: $hostname)"
    else
        echo "Setting up: $node_ip"
    fi
    
    # Set hostname if provided
    if [[ -n "$hostname" ]]; then
        echo "  → Setting hostname to: $hostname"
        if sshpass -p "$USER_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USERNAME@$node_ip" "echo '$USER_PASSWORD' | sudo -S bash -c 'hostnamectl set-hostname $hostname && sed -i \"/127.0.1.1/d\" /etc/hosts && echo \"127.0.1.1 $hostname\" >> /etc/hosts'" 2>/dev/null; then
            echo "  ✓ Hostname set successfully"
        else
            echo "  ✗ Hostname setting failed"
        fi
    fi
    
    # Copy key to regular user
    echo "  → Copying key to $USERNAME@$node_ip"
    if sshpass -p "$USER_PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH.pub" "$USERNAME@$node_ip" 2>/dev/null; then
        echo "  ✓ User key copied"
    else
        echo "  ✗ User key failed"
        continue
    fi
    
    # Copy key to root
    echo "  → Copying key to root@$node_ip"
    if sshpass -p "$ROOT_PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH.pub" "root@$node_ip" 2>/dev/null; then
        echo "  ✓ Root key copied"
    else
        echo "  ✗ Root key failed"
    fi
    
    # Test connections
    echo "  → Testing connections..."
    if ssh -o ConnectTimeout=3 -o BatchMode=yes "$USERNAME@$node_ip" "echo 'User OK'" 2>/dev/null; then
        echo "  ✓ User passwordless login works"
    fi
    
    if ssh -o ConnectTimeout=3 -o BatchMode=yes "root@$node_ip" "echo 'Root OK'" 2>/dev/null; then
        echo "  ✓ Root passwordless login works"
    fi
    
    # Show current hostname for verification
    if [[ -n "$hostname" ]]; then
        current_hostname=$(ssh -o ConnectTimeout=3 -o BatchMode=yes "$USERNAME@$node_ip" "hostname" 2>/dev/null)
        if [[ "$current_hostname" == "$hostname" ]]; then
            echo "  ✓ Hostname verified: $current_hostname"
        else
            echo "  ! Hostname may need reboot to take effect"
        fi
    fi
done

echo "----------------------------------------"
echo -e "${GREEN}Setup completed!${NC}"
echo ""
echo "Test your passwordless login:"
for node_entry in "${NODES[@]}"; do
    IFS=':' read -r node_ip hostname <<< "$node_entry"
    if [[ -n "$hostname" ]]; then
        echo "  ssh $USERNAME@$node_ip  # $hostname"
        echo "  ssh root@$node_ip       # $hostname"
    else
        echo "  ssh $USERNAME@$node_ip"
        echo "  ssh root@$node_ip"
    fi
    break
done