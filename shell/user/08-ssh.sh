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

function ssh_vm {
    start_qemu_vm "$1" 30
    TERM=xterm-256color ssh $USER@$(get_vm_ip "$1")
}

function cp_from_vm {
    start_qemu_vm "$1" 30
    scp -O -r $USER@$(get_vm_ip "$1"):$2 $3
}

function start_qemu_vm {
    if ! `sudo virsh list --all | grep "$1" | grep running &> /dev/null`; then
        sudo virsh start "$1"
        if [[ -n $2 ]]; then
            sleep $2 # Wait for VM to start
        fi
    elif ! `virsh list --all | grep "$1" | grep running &> /dev/null`; then
        virsh start "$1"
        if [[ -n $2 ]]; then
            sleep $2 # Wait for VM to start
        fi
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

function ssh_debian {
    ssh_vm "Debian 13"
}

function cp_from_debian {
    cp_from_vm "Debian 13" "$1" "$2"
}

function view_debian {
    view_qemu_vm "Debian 13"
}

function ssh_fedora {
    ssh_vm "Fedora Rawhide"
}

function cp_from_fedora {
    cp_from_vm "Fedora Rawhide" "$1" "$2"
}

function view_fedora {
    view_qemu_vm "Fedora Rawhide"
}

function ssh_ubuntu {
    ssh_vm "Ubuntu 26.04"
}

function cp_from_ubuntu {
    cp_from_vm "Ubuntu 26.04" "$1" "$2"
}

function view_ubuntu {
    view_qemu_vm "Ubuntu 26.04"
}

function ssh_guix {
    ssh_vm "Guix System master"
}

function cp_from_guix {
    cp_from_vm "Guix System master" "$1" "$2"
}

function view_guix {
    view_qemu_vm "Guix System master"
}

function ssh_rocky {
    ssh_vm "Rocky Linux 10.1"
}

function cp_from_rocky {
    cp_from_vm "Rocky Linux 10.1" "$1" "$2"
}

function view_rocky {
    view_qemu_vm "Rocky Linux 10.1"
}

function ssh_rosa {
    ssh_vm "ROSA Fresh GNOME 13.1"
}

function cp_from_rosa {
    cp_from_vm "ROSA Fresh GNOME 13.1" "$1" "$2"
}

function view_rosa {
    view_qemu_vm "ROSA Fresh GNOME 13.1"
}

function ssh_mint {
    ssh_vm "Linux Mint 22.2 Cinnamon"
}

function cp_from_mint {
    cp_from_vm "Linux Mint 22.2 Cinnamon" "$1" "$2"
}

function view_mint {
    view_qemu_vm "Linux Mint 22.2 Cinnamon"
}

function ssh_slackware {
    ssh_vm "Slackware Linux 15.0"
}

function cp_from_slackware {
    cp_from_vm "Slackware Linux 15.0" "$1" "$2"
}

function view_slackware {
    view_qemu_vm "Slackware Linux 15.0"
}

function ssh_opensuse {
    ssh_vm "openSUSE Tumbleweed"
}

function cp_from_opensuse {
    cp_from_vm "openSUSE Tumbleweed" "$1" "$2"
}

function view_opensuse {
    view_qemu_vm "openSUSE Tumbleweed"
}

function start_reactos {
    start_qemu_vm "ReactOS2"
}

function view_reactos {
    view_qemu_vm "ReactOS2"
}

function ssh_chimera {
    ssh_vm "Chimera Linux"
}

function cp_from_chimera {
    cp_from_vm "Chimera Linux" "$1" "$2"
}

function view_chimera {
    view_qemu_vm "Chimera Linux"
}

function ssh_void {
    ssh_vm "Void Linux"
}

function cp_from_void {
    cp_from_vm "Void Linux" "$1" "$2"
}

function view_void {
    view_qemu_vm "Void Linux"
}

function ssh_rhino {
    ssh_vm "Rhino Linux"
}

function cp_from_rhino {
    cp_from_vm "Rhino Linux" "$1" "$2"
}

function view_rhino {
    view_qemu_vm "Rhino Linux"
}

function ssh_gentoo {
    ssh_vm "Gentoo Linux"
}

function cp_from_gentoo {
    cp_from_vm "Gentoo Linux" "$1" "$2"
}

function view_gentoo {
    view_qemu_vm "Gentoo Linux"
}

function ssh_solus {
    ssh_vm "Solus Budgie"
}

function cp_from_solus {
    cp_from_vm "Solus Budgie" "$1" "$2"
}

function view_solus {
    view_qemu_vm "Solus Budgie"
}

function ssh_freebsd {
    ssh_vm "FreeBSD 15.0"
}

function cp_from_freebsd {
    cp_from_vm "FreeBSD 15.0" "$1" "$2"
}

function view_freebsd {
    view_qemu_vm "FreeBSD 15.0"
}

function ssh_deepin {
    ssh_vm "Deepin 25.0.1"
}

function cp_from_deepin {
    cp_from_vm "Deepin 25.0.1" "$1" "$2"
}

function view_deepin {
    view_qemu_vm "Deepin 25.0.1"
}

function ssh_alpine {
    ssh_vm "Alpine Linux 3.23"
}

function cp_from_alpine {
    cp_from_vm "Alpine Linux 3.23" "$1" "$2"
}

function view_alpine {
    view_qemu_vm "Alpine Linux 3.23"
}

function ssh_elementary {
    ssh_vm "elementary OS 8.0.2"
}

function cp_from_elementary {
    cp_from_vm "elementary OS 8.0.2" "$1" "$2"
}

function view_elementary {
    view_qemu_vm "elementary OS 8.0.2"
}

function ssh_kylin {
    ssh_vm "Ubuntu Kylin 25.10"
}

function cp_from_kylin {
    cp_from_vm "Ubuntu Kylin 25.10" "$1" "$2"
}

function view_kylin {
    view_qemu_vm "Ubuntu Kylin 25.10"
}

function ssh_mocaccino {
    ssh_vm "MocaccinOS"
}

function cp_from_mocaccino {
    cp_from_vm "MocaccinOS" "$1" "$2"
}

function view_mocaccino {
    view_qemu_vm "MocaccinOS"
}

function ssh_pop {
    ssh_vm "Pop!_OS 24.04"
}

function cp_from_pop {
    cp_from_vm "Pop!_OS 24.04" "$1" "$2"
}

function view_pop {
    view_qemu_vm "Pop!_OS 24.04"
}

function ssh_pclinuxos {
    ssh_vm "PCLinuxOS"
}

function cp_from_pclinuxos {
    cp_from_vm "PCLinuxOS" "$1" "$2"
}

function view_pclinuxos {
    view_qemu_vm "PCLinuxOS"
}

function ssh_alt {
    ssh_vm "ALT Linux 11"
}

function cp_from_alt {
    cp_from_vm "ALT Linux 11" "$1" "$2"
}

function view_alt {
    view_qemu_vm "ALT Linux 11"
}

function ssh_openmandriva {
    ssh_vm "OpenMandriva Lx ROME"
}

function cp_from_openmandriva {
    cp_from_vm "OpenMandriva Lx ROME" "$1" "$2"
}

function view_openmandriva {
    view_qemu_vm "OpenMandriva Lx ROME"
}

function ssh_bedrock {
    ssh_vm "Bedrock Linux (Arch Linux base)"
}

function cp_from_bedrock {
    cp_from_vm "Bedrock Linux (Arch Linux base)" "$1" "$2"
}

function view_bedrock {
    view_qemu_vm "Bedrock Linux (Arch Linux base)"
}