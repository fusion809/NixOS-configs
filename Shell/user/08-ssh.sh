if ! [[ -d $HOME/.ssh ]] || ! [[ -f $HOME/.ssh/id_rsa.pub ]]; then
  mkdir -p $HOME/.ssh
  ssh-keygen -t rsa -b 4096 -C 'brentonhorne77@gmail.com'
  clipf $HOME/.ssh/id_rsa.pub
  echo 'GitHub SSH key generated and is now in your clipboard. Go to https://github.com/settings/ssh to register it to your account!'
fi

function ssh_debian {
    ssh fusion809@192.168.122.244
}

function cp_from_debian {
    scp -O -r fusion809@192.168.122.244:$HOME/$1 /arch$HOME/PhD/Rcode/
}

function ssh_fedora {
    ssh fusion809@192.168.122.232
}

function cp_from_fedora {
    scp -O -r fusion809@192.168.122.232:$HOME/$1 /arch$HOME/PhD/Rcode/
}

function ssh_ubuntu {
    ssh fusion809@192.168.122.151
}

function cp_from_ubuntu {
    scp -O -r fusion809@192.168.122.151:$HOME/$1 /arch$HOME/PhD/Rcode/
}