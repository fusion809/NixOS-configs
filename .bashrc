function vbash {
	vim ~/.bashrc
}

function sbash {
	source ~/.bashrc
}

function vcf {
	sudo vim /etc/nixos/configuration.nix
}

function nixcg {
	sudo nix-collect-garbage -d
}

function nixcu {
	sudo nix-channel --update
}

function nixrsu {
	sudo nixos-rebuild switch --upgrade
}

function update {
	nixcu
	nixrsu
	nixcg
}

function rebuild {
	sudo nixos-rebuild switch
}

alias nixrb=rebuild
