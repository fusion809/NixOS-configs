if ! [[ -d $HOME/.ssh ]] || ! [[ -f $HOME/.ssh/id_rsa.pub ]]; then
  mkdir -p $HOME/.ssh
  ssh-keygen -t rsa -b 4096 -C 'brentonhorne77@gmail.com'
  clipf $HOME/.ssh/id_rsa.pub
  echo 'GitHub SSH key generated and is now in your clipboard. Go to https://github.com/settings/ssh to register it to your account!'
fi

function start_qemu_vm_root {
    if ! `sudo virsh list --all | grep "$1" | grep running &> /dev/null`; then
        sudo virsh start "$1"
        if [[ -n $2 ]]; then
            sleep $2 # Wait for VM to start
        fi
    fi
}

function start_qemu_vm_user {
    if ! `virsh list --all | grep "$1" | grep running &> /dev/null`; then
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
            start_qemu_vm_root "$1"
        fi
        virt-viewer --connect qemu:///system "$1"
    elif [[ -n "${user_vm// /}" ]]; then
        if ! `echo $user_vm | grep running &> /dev/null`; then
            start_qemu_vm_user "$1"
        fi
        virt-viewer "$1"
    fi
}

function start_debian {
    start_qemu_vm_root "Debian 13" 30
}

function ssh_debian {
    start_debian
    TERM=xterm-256color ssh fusion809@192.168.122.244
}

function cp_from_debian {
    start_debian
    scp -O -r fusion809@192.168.122.244:$HOME/$1 /arch$HOME/PhD/Rcode/
}

function view_debian {
    view_qemu_vm "Debian 13"
}

function start_fedora_rawhide {
    start_qemu_vm_root "Fedora Rawhide" 30
}

function ssh_fedora {
    start_fedora_rawhide
    TERM=xterm-256color ssh $USER@192.168.122.232
}

function cp_from_fedora {
    start_fedora_rawhide
    scp -O -r $USER@192.168.122.232:$1 $2
}

function view_fedora {
    view_qemu_vm "Fedora Rawhide"
}

function start_ubuntu {
    start_qemu_vm_root "Ubuntu 26.04" 30
}

function ssh_ubuntu {
    start_ubuntu
    TERM=xterm-256color ssh $USER@192.168.122.151
}

function cp_from_ubuntu {
    start_ubuntu
    scp -O -r $USER@192.168.122.151:$1 $2
}

function view_ubuntu {
    view_qemu_vm "Ubuntu 26.04"
}

function start_guix {
    start_qemu_vm_root "Guix System master" 30
}

function ssh_guix {
    start_guix
    TERM=xterm-256color ssh $USER@192.168.122.90
}

function cp_from_guix {
    start_guix
    scp -O -r $USER@192.168.122.90:$1 $2
}

function view_guix {
    view_qemu_vm "Guix System master"
}

function start_rocky {
    start_qemu_vm_root "Rocky Linux 10.1" 30
}

function ssh_rocky {
    start_rocky
    TERM=xterm-256color ssh fusion809@192.168.122.158
}

function cp_from_rocky {
    start_rocky
    scp -O -r fusion809@192.168.122.158:$1 $2
}

function view_rocky {
    view_qemu_vm "Rocky Linux 10.1"
}

function start_rosa {
    start_qemu_vm_root "ROSA Fresh GNOME 13.1" 30
}

function ssh_rosa {
    start_rosa
    TERM=xterm-256color ssh fusion809@192.168.122.165
}

function cp_from_rosa {
    start_rosa
    scp -O -r fusion809@192.168.122.165:$1 $2
}

function view_rosa {
    view_qemu_vm "ROSA Fresh GNOME 13.1"
}

function start_mint {
    start_qemu_vm_root "Linux Mint 22.2 Cinnamon" 30
}

function ssh_mint {
    start_mint
    TERM=xterm-256color ssh fusion809@192.168.122.54
}

function cp_from_mint {
    start_mint
    scp -O -r fusion809@192.168.122.54:$1 $2
}

function view_mint {
    view_qemu_vm "Linux Mint 22.2 Cinnamon"
}

function start_slackware {
    start_qemu_vm_root "Slackware Linux 15.0" 30
}

function ssh_slackware {
    start_slackware
    TERM=xterm-256color ssh fusion809@192.168.122.106
}

function cp_from_slackware {
    start_slackware
    scp -O -r fusion809@192.168.122.106:$1 $2
}

function view_slackware {
    view_qemu_vm "Slackware Linux 15.0"
}

function start_opensuse {
    start_qemu_vm_root "openSUSE Tumbleweed" 30
}

function ssh_opensuse {
    start_opensuse
    TERM=xterm-256color ssh fusion809@192.168.122.63
}

function cp_from_opensuse {
    start_opensuse
    scp -O -r fusion809@192.168.122.63:$1 $2
}

function view_opensuse {
    view_qemu_vm "openSUSE Tumbleweed"
}

function start_reactos {
    start_qemu_vm_root "ReactOS2"
}

function view_reactos {
    view_qemu_vm "ReactOS2"
}

function start_chimera {
    start_qemu_vm_root "Chimera Linux" 30
}

function ssh_chimera {
    start_chimera
    TERM=xterm-256color ssh fusion809@192.168.122.161
}

function cp_from_chimera {
    start_chimera
    scp -O -r fusion809@192.168.122.161:$1 $2
}

function view_chimera {
    view_qemu_vm "Chimera Linux"
}

function start_void {
    start_qemu_vm_root "Void Linux" 30
}

function ssh_void {
    start_void
    TERM=xterm-256color ssh fusion809@192.168.122.28
}

function cp_from_void {
    start_void
    scp -O -r fusion809@192.168.122.28:$1 $2
}

function view_void {
    view_qemu_vm "Void Linux"
}

function start_rhino {
    start_qemu_vm_root "Rhino Linux" 30
}

function ssh_rhino {
    start_rhino
    TERM=xterm-256color ssh fusion809@192.168.122.116
}

function cp_from_rhino {
    start_rhino
    scp -O -r fusion809@192.168.122.116:$1 $2
}

function view_rhino {
    view_qemu_vm "Rhino Linux"
}

function start_gentoo {
    start_qemu_vm_root "Gentoo Linux" 30
}

function ssh_gentoo {
    start_gentoo
    TERM=xterm-256color ssh fusion809@192.168.122.146
}

function cp_from_gentoo {
    start_gentoo
    scp -O -r fusion809@192.168.122.146:$1 $2
}

function view_gentoo {
    view_qemu_vm "Gentoo Linux"
}

function start_solus {
    start_qemu_vm_root "Solus Budgie" 30
}

function ssh_solus {
    start_solus
    TERM=xterm-256color ssh fusion809@192.168.122.64
}

function cp_from_solus {
    start_solus
    scp -O -r fusion809@192.168.122.64:$1 $2
}

function view_solus {
    view_qemu_vm "Solus Budgie"
}

function start_freebsd {
    start_qemu_vm_root "FreeBSD 15.0" 30
}

function ssh_freebsd {
    start_freebsd
    TERM=xterm-256color ssh fusion809@192.168.122.192
}

function cp_from_freebsd {
    start_freebsd
    scp -O -r fusion809@192.168.122.192:$1 $2
}

function view_freebsd {
    view_qemu_vm "FreeBSD 15.0"
}

function start_deepin {
    start_qemu_vm_root "Deepin 25.0.1" 30
}

function ssh_deepin {
    start_deepin
    TERM=xterm-256color ssh fusion809@192.168.122.23
}

function cp_from_deepin {
    start_deepin
    scp -O -r fusion809@192.168.122.23:$1 $2
}

function view_deepin {
    view_qemu_vm "Deepin 25.0.1"
}

function start_alpine {
    start_qemu_vm_root "Alpine Linux 3.23" 30
}

function ssh_alpine {
    start_alpine
    TERM=xterm-256color ssh fusion809@192.168.122.26
}

function cp_from_alpine {
    start_alpine
    scp -O -r fusion809@192.168.122.26:$1 $2
}

function view_alpine {
    view_qemu_vm "Alpine Linux 3.23"
}

function start_elementary {
    start_qemu_vm_root "elementary OS 8.0.2" 30
}

function ssh_elementary {
    start_elementary
    TERM=xterm-256color ssh fusion809@192.168.122.6
}

function cp_from_elementary {
    start_elementary
    scp -O -r fusion809@192.168.122.6:$1 $2
}

function view_elementary {
    view_qemu_vm "elementary OS 8.0.2"
}
