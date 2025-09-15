#!/bin/bash
CONFIG_FILE="/etc/pve/universal-ssh-keys.cfg"

# Load keys
DATACENTER_KEYS=$(awk '/keys = \[/{flag=1;next}/\]/{flag=0}flag' $CONFIG_FILE | tr -d '", ')

# Apply keys to node
mkdir -p /root/.ssh
touch /root/.ssh/authorized_keys
for KEY in $DATACENTER_KEYS; do
    grep -qxF "$KEY" /root/.ssh/authorized_keys || echo "$KEY" >> /root/.ssh/authorized_keys
done
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl reload sshd

# Apply keys & reboot VMs in order
VMIDS=$(qm list | awk 'NR>1 {print $1}' | sort -n)

for VMID in $VMIDS; do
    # Skip if no cloud-init
    if ! qm config $VMID | grep -q "ciuser:"; then
        continue
    fi

    # Try cloud-init injection first
    for KEY in $DATACENTER_KEYS; do
        qm set $VMID --sshkeys "$KEY"
    done

    # Reboot VM
    echo "Rebooting VM $VMID..."
    qm reboot $VMID

    # Wait for IP via QEMU guest agent
    VM_IP=""
    while [ -z "$VM_IP" ]; do
        sleep 5
        VM_IP=$(qm guest exec $VMID -- ip addr show eth0 | grep -Po 'inet \K[\d.]+' || echo "")
    done

    # Wait until VM responds to ping
    while ! ping -c 1 -W 1 "$VM_IP" >/dev/null 2>&1; do
        echo "Waiting for VM $VMID to be online..."
        sleep 5
    done

    # Push keys via SSH if cloud-init somehow missed
    for KEY in $DATACENTER_KEYS; do
        ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa root@"$VM_IP" "grep -qxF '$KEY' ~/.ssh/authorized_keys || echo '$KEY' >> ~/.ssh/authorized_keys"
    done

    echo "VM $VMID is online and keys applied!"
done

echo "All VMs updated and online."
