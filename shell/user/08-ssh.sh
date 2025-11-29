if ! [[ -d $HOME/.ssh ]] || ! [[ -f $HOME/.ssh/id_rsa.pub ]]; then
  mkdir -p $HOME/.ssh
  ssh-keygen -t rsa -b 4096 -C 'brentonhorne77@gmail.com'
  clipf $HOME/.ssh/id_rsa.pub
  echo 'GitHub SSH key generated and is now in your clipboard. Go to https://github.com/settings/ssh to register it to your account!'
fi

function start_qemu_vm_root {
    if ! `sudo virsh list --all | grep "$1" | grep running &> /dev/null`; then
        sudo virsh start "$1"
        sleep 30 # Wait for VM to start
    fi
}

function start_debian {
    start_qemu_vm_root "Debian 13"
}
function ssh_debian {
    start_debian
    TERM=xterm-256color ssh fusion809@192.168.122.244
}

function cp_from_debian {
    start_debian
    scp -O -r fusion809@192.168.122.244:$HOME/$1 /arch$HOME/PhD/Rcode/
}

function start_fedora_rawhide {
    start_qemu_vm_root "Fedora Rawhide"
}

function ssh_fedora {
    start_fedora_rawhide
    TERM=xterm-256color ssh fusion809@192.168.122.232
}

function cp_from_fedora {
    start_fedora_rawhide
    scp -O -r fusion809@192.168.122.232:$1 $2
}

function start_ubuntu {
    start_qemu_vm_root "Ubuntu 26.04"
}

function ssh_ubuntu {
    start_ubuntu
    TERM=xterm-256color ssh fusion809@192.168.122.151
}

function cp_from_ubuntu {
    start_ubuntu
    scp -O -r fusion809@192.168.122.151:$1 $2
}

function start_guix {
    start_qemu_vm_root "Guix System master"
}

function ssh_guix {
    start_guix
    TERM=xterm-256color ssh fusion809@192.168.122.90
}

function cp_from_guix {
    start_guix
    scp -O -r fusion809@192.168.122.90:$1 $2
}

function start_rocky {
    start_qemu_vm_root "Rocky Linux 10.1"
}

function ssh_rocky {
    start_rocky
    TERM=xterm-256color ssh fusion809@192.168.122.158
}

function cp_from_rocky {
    start_rocky
    scp -O -r fusion809@192.168.122.158:$1 $2
}

function start_mint {
    start_qemu_vm_root "Linux Mint 22.2 Cinnamon"
}

function ssh_mint {
    start_mint
    TERM=xterm-256color ssh fusion809@192.168.122.54
}

function cp_from_mint {
    start_mint
    scp -O -r fusion809@192.168.122.54:$1 $2
}