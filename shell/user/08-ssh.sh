if ! [[ -d $HOME/.ssh ]] || ! [[ -f $HOME/.ssh/id_rsa.pub ]]; then
  mkdir -p $HOME/.ssh
  ssh-keygen -t rsa -b 4096 -C 'brentonhorne77@gmail.com'
  clipf $HOME/.ssh/id_rsa.pub
  echo 'GitHub SSH key generated and is now in your clipboard. Go to https://github.com/settings/ssh to register it to your account!'
fi

function get_vm_ip {
    local vm_name="$1"
    # Get MAC address from the first interface found
    local vm_mac=$(sudo virsh domiflist "$vm_name" | grep -o -E '([0-9a-fA-F]{2}:){5}([0-9a-fA-F]{2})' | head -n 1)

    if [ -z "$vm_mac" ]; then
        echo "Could not find MAC address for VM: $vm_name"
        return 1
    fi

    # Try libvirt DHCP leases first
    local ip=$(sudo virsh net-dhcp-leases default | grep "$vm_mac" | awk '{print $5}' | cut -d'/' -f1 | tail -n 1)

    # Fallback to ARP scan
    if [ -z "$ip" ]; then
        echo "IP not found in DHCP leases for $vm_mac. Scanning ARP table..."
        ip=$(arp -an | grep "$vm_mac" | awk '{print $2}' | tr -d '()')
    fi

    if [ -z "$ip" ]; then
        echo "Could not determine IP for $vm_name ($vm_mac)."
        return 1
    fi

    echo "$ip"
}

function cp_from_vm {
    start_qemu_vm "$1"
    local ip=$(get_vm_ip "$1")
    if [ -n "$ip" ]; then
        if [ -f "$HOME/.config/vm_pass" ]; then
            sshpass -f "$HOME/.config/vm_pass" scp -O -r "$USER@$ip:$2" "$3"
        else
            scp -O -r "$USER@$ip:$2" "$3"
        fi
    else
         echo "Failed to get IP for $1"
         return 1
    fi
}

function start_qemu_vm {
    local vm="$1"
    # Check if VM is running using domstate (robust against special chars in name)
    local state=$(sudo virsh domstate "$vm" 2>/dev/null | head -n1)

    # "running" or "idle" usually indicates it's up.
    if [[ "$state" != "running" && "$state" != "idle" ]]; then
        sudo virsh start "$vm"
        echo "Starting $vm..."
        
        # Wait for IP acquisition
        local ip=""
        local retries=0
        local max_retries=60 # Wait up to 60 seconds for IP
        
        while [ -z "$ip" ] && [ $retries -lt $max_retries ]; do
             ip=$(get_vm_ip "$vm" 2>/dev/null)
             if [ -z "$ip" ]; then
                 sleep 1
                 ((retries++))
             fi
        done
        
        if [ -z "$ip" ]; then
            echo "Timed out waiting for IP address for $vm."
            return 1
        fi
        
        echo "IP found: $ip. Waiting for SSH..."

        # Wait for SSH port to be open
        local port_ready=0
        retries=0
        max_retries=30 # Wait up to 30 more seconds for SSH
        
        while [ $port_ready -eq 0 ] && [ $retries -lt $max_retries ]; do
            if nc -z -w 1 "$ip" 22 2>/dev/null; then
                port_ready=1
            else
                sleep 1
                ((retries++))
            fi
        done
        
        if [ $port_ready -eq 0 ]; then
             echo "Timed out waiting for SSH on $ip."
             return 1
        fi
        
        echo "SSH is ready!"
    fi
}

function ssh_vm {
    local vm_name="$1"
    shift
    start_qemu_vm "$vm_name"
    local ip=$(get_vm_ip "$vm_name")
    
    if [ -n "$ip" ]; then
        if [ -f "$HOME/.config/vm_pass" ]; then
            # Use -t to force pseudo-terminal allocation if commands are passed
            TERM=xterm-256color sshpass -f "$HOME/.config/vm_pass" ssh -t "$USER@$ip" "$@"
        else
            TERM=xterm-256color ssh -t "$USER@$ip" "$@"
        fi
    else
        echo "Failed to get IP for $vm_name"
        return 1
    fi
}

function view_qemu_vm {
    root_vm=$(sudo virsh list --all | grep "$1")
    echo "root_vm = $root_vm"
    user_vm=$(virsh list --all | grep "$1")
    echo "user_vm = $user_vm"
    if [[ -n "${root_vm// /}" ]]; then
        echo "Assuming root vm..."
        if ! `echo $root_vm | grep running &> /dev/null`; then
            start_qemu_vm "$1"
        fi
        virt-viewer --connect qemu:///system "$1"
    elif [[ -n "${user_vm// /}" ]]; then
        if ! `echo $user_vm | grep running &> /dev/null`; then
            start_qemu_vm "$1"
        fi
        virt-viewer "$1"
    fi
}

declare -A vms=(
    ["aeryn"]="AerynOS"
    ["alpine"]="Alpine Linux 3.23"
    ["alt"]="ALT Linux 11"
    ["bedrock"]="Bedrock Linux (Arch Linux base)"
    ["chimera"]="Chimera Linux"
    ["debian"]="Debian 13"
    ["deepin"]="Deepin 25.0.1"
    ["elementary"]="elementary OS 8.0.2"
    ["fedora"]="Fedora Rawhide"
    ["freebsd"]="FreeBSD 15.0"
    ["gentoo"]="Gentoo Linux"
    ["guix"]="Guix System master"
    ["kylin"]="Ubuntu Kylin 25.10"
    ["mint"]="Linux Mint 22.2 Cinnamon"
    ["mocaccino"]="MocaccinOS"
    ["openmandriva"]="OpenMandriva Lx ROME"
    ["opensuse"]="openSUSE Tumbleweed"
    ["pclinuxos"]="PCLinuxOS"
    ["pop"]="Pop!_OS 24.04"
    ["reactos"]="ReactOS2"
    ["rhino"]="Rhino Linux"
    ["rocky"]="Rocky Linux 10.1"
    ["rosa"]="ROSA Fresh GNOME 13.1"
    ["slackware"]="Slackware Linux 15.0"
    ["solus"]="Solus Budgie"
    ["ubuntu"]="Ubuntu 26.04"    
    ["void"]="Void Linux"
    ["zorin"]="Zorin OS 18"
)

# Shell-agnostic key iteration
if [ -n "$ZSH_VERSION" ]; then
    short_names=("${(@k)vms}")
else
    short_names=("${!vms[@]}")
fi

for short_name in "${short_names[@]}"; do
    full_name="${vms[$short_name]}"
    eval "function ssh_${short_name} { ssh_vm \"$full_name\" \"\$@\"; }"
    eval "function cp_from_${short_name} { cp_from_vm \"$full_name\" \"\$1\" \"\$2\"; }"
    eval "function view_${short_name} { view_qemu_vm \"$full_name\"; }"
done

function hpc {
    ssh_debian "bash -ic hpc"
}