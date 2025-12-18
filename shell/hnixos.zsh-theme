#!/usr/bin/env zsh
function prompt_char {
	if [ $UID -eq 0 ]; then echo "%{$fg_bold[red]%}"; else echo "%{$fg_bold[green]%}$"; fi
}

function operating_system {

	OPS=$(uname)

	if [[ $OPS == "Linux" ]]; then
		CAT=$(grep "PRETTY_NAME" < /etc/os-release | cut -d '=' -f 2 | head -n 1 | cut -d '"' -f 2 | sed 's/ (.*)//g' | sed 's/ Linux//g')

		if [[ $CAT == "void" ]]; then
			printf "Void"
		else
			printf "$CAT"
		fi
	else

		 printf "$OPS"

	fi
}

function kernel {

	KERNEL=$(uname -r)

	printf "Kernel: $KERNEL"

}

function user {
	if id | grep root > /dev/null 2>&1; then
		printf '\e[1;31m%-6s\e[m' "root"
	else
		printf '\e[1;32m%-6s\e[m' "${USER}"
	fi
}

export OPS=$(operating_system)

PROMPT='$fg_bold[yellow][%D{%l:%M:%S%p, %a %d/%m/%y}|$fg_bold[blue]${OPS}] $(user) %{$fg_bold[blue]%}%(!.%1~.%~) $(git_prompt_info) $(prompt_char)%{$reset_color%} '

ZSH_THEME_GIT_PROMPT_PREFIX="("
ZSH_THEME_GIT_PROMPT_SUFFIX=")"
