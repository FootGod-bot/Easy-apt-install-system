#!/bin/bash
CONFIG_FILE="/etc/pve/universal-ssh-keys.cfg"

# Load keys
DATACENTER_KEYS=$(awk '/keys = \[/{flag=1;next}/\]/{flag=0}flag' $CONFIG_FILE | tr -d '", ')

# Load static IPs
declare -A VM_STATIC_IPS
while IFS='=' read -r vm ip; do
    [[ "$vm" =~ ^[0-9]+$ ]] || continue
    VM_STATIC_IPS[$vm]=$ip
done < <(awk '/\[static_ips\]/ {f=1; next} /^\[/ {f=0} f && /=/ {print}' $CONFIG_FILE)

# Apply keys to node root
mkdir -p /root/.ssh
touch /root/.ssh/authorized_keys
for KEY in $DATACENTER_KEYS; do
    grep -qxF "$KEY" /root/.ssh/authorized_keys || echo "$KEY" >> /root/.ssh/authorized_keys
done
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl reload sshd
echo "Applied keys to node root and disabled password SSH"

# Get list of VMs
VMIDS=$(qm list | awk 'NR>1 {print $1}' | sort -n)

for VMID in $VMIDS; do
    if ! qm config $VMID | grep -q "ciuser:"; then
        continue
    fi

    # Apply keys via cloud-init
    for KEY in $DATACENTER_KEYS; do
        qm set $VMID --sshkeys "$KEY"
    done

    # Reboot VM
    echo "Rebooting VM $VMID..."
    qm reboot $VMID 2>/dev/null || qm start $VMID 2>/dev/null

    # Determine IP
    VM_IP=${VM_STATIC_IPS[$VMID]}

    if [ -z "$VM_IP" ]; then
        echo "VM $VMID uses DHCP, waiting for QEMU guest agent..."
        while true; do
            VM_IP=$(qm guest exec $VMID -- ip addr show eth0 2>/dev/null | grep -Po 'inet \K[\d.]+' || echo "")
            [ -n "$VM_IP" ] && break
            sleep 5
        done
    fi

    # Wait for network up
    while ! ping -c 1 -W 1 "$VM_IP" >/dev/null 2>&1; do
        echo "Waiting for VM $VMID ($VM_IP) to be online..."
        sleep 5
    done

    # Push keys via SSH if needed
    for KEY in $DATACENTER_KEYS; do
        ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa root@"$VM_IP" \
            "grep -qxF '$KEY' ~/.ssh/authorized_keys || echo '$KEY' >> ~/.ssh/authorized_keys"
    done

    echo "VM $VMID is online and keys applied!"
done

echo "All VMs updated successfully."
