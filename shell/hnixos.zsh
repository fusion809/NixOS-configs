#!/usr/bin/env zsh
function prompt_char {
	if [ $UID -eq 0 ]; then echo "%{$fg_bold[red]%}#"; else echo "%{$fg_bold[green]%}$"; fi
}

function operating_system {

	OPS=$(uname)

	printf "$(grep "PRETTY_NAME" < /etc/os-release | cut -d '=' -f 2 | head -n 1 | cut -d '"' -f 2 | sed 's/ (.*)//g' | sed 's/ Linux//g' | sed 's/NixOS.*//g')"
}

function user {
	if id | grep root > /dev/null 2>&1; then
		echo "%{$fg_bold[red]%}root%{$reset_color%}"
	else
		echo "%{$fg_bold[green]%}$(printf '%-6s' "${USER}")%{$reset_color%}"
	fi
}

function conditional_newline {
	local built_prompt=${(%)PROMPT_PREFIX}
	# Strip ANSI escape codes
	local clean_prompt=${built_prompt//$'\e'[\[(]*([0-9;])#[mK]/}
	local prompt_len=${#clean_prompt}
	if (( prompt_len > COLUMNS * 0.9 )); then
		echo $'\n'
	fi
}

export OPS=$(operating_system)
function condensed_pwd {
	echo "${PWD/#$HOME/~}" | sed 's|/data/GitHub-nixos|~/GitHub|g' | sed 's|~/GitHub/mine/config/NixOS-configs|$NIXCFG|g' | sed 's|~/GitHub/mine/config|$CFG|g' | sed 's|~/GitHub/mine|$GHUBM|g' | sed 's|~/GitHub/others|$GHUBO|g' | sed 's|~/GitHub|$GHUB|g' | sed 's|~/VirtMachines|$VM|g' | sed 's|/arch/home/fusion809/GitHub/mine/config|$ARCHCFG|g' | sed 's|/arch/home/fusion809/GitHub/mine/websites/images|$ARCHIM|g' | sed 's|/arch/home/fusion809/GitHub/mine/websites/fusion809.github.io|$ARCHFGI|g' | sed 's|/arch/home/fusion809/GitHub/mine/websites|$ARCHWEB|g' | sed 's|/arch/home/fusion809/GitHub/mine|$ARCHGBM|g' | sed 's|/data/VirtualBox VMs/iso|$ISO|g' | sed 's|/data/VirtualBox VMs|$VBM|g' | sed 's|/arch/home/fusion809/.files|$ARCHDF|g' | sed 's|/arch/home/fusion809|$ARCHH|g' | sed 's|/home/fusion809|$HOME|g'
}

PROMPT_PREFIX='%{$fg_bold[yellow]%}%D{%H:%M:%S %d/%m/%y} $(user) %{$fg_bold[cyan]%}${OPS} %{$fg_bold[blue]%}$(condensed_pwd)$(git_prompt_info)'
setopt prompt_subst

PROMPT="${PROMPT_PREFIX}\$(conditional_newline)\$(prompt_char)%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_PREFIX="("
ZSH_THEME_GIT_PROMPT_SUFFIX=")"