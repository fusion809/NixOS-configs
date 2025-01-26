source /home/fusion809/NixOS-configs/hnixos.zsh-theme

source $HOME/.bashrc

function vzsh {
	vim $HOME/.zshrc
}

function szsh {
	source $HOME/.zshrc
}

function clipf {
	xclip -sel clip < $1
}

function rainbowfastfetch {
	hyfetch -p rainbow -b fastfetch --args="--localip-show-ipv4 false"
}

function gaymenfastfetch {
	hyfetch -p gay-men -b fastfetch --args="--localip-show-ipv4 false"
}

export NIXPKGS_ALLOW_INSECURE=1

function sclipf {
	sudo xclip -sel clip < $1
}

function push {
	git add --all
	git commit -m "$@"
	git push origin 24.11
}

function cdnc {
	cd $HOME/NixOS-configs/$1
}
