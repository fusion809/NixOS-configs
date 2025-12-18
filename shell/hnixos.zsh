#!/usr/bin/env zsh
function prompt_char {
	if [ $UID -eq 0 ]; then echo "%{$fg_bold[red]%}"; else echo "%{$fg_bold[green]%}$"; fi
}

function operating_system {

	OPS=$(uname)

	printf "$(grep "PRETTY_NAME" < /etc/os-release | cut -d '=' -f 2 | head -n 1 | cut -d '"' -f 2 | sed 's/ (.*)//g' | sed 's/ Linux//g')"
}

function user {
	if id | grep root > /dev/null 2>&1; then
		echo "%{$fg_bold[red]%}$(printf '%-6s' "root")%{$reset_color%}"
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
	else
		echo " "
	fi
}

export OPS=$(operating_system)

if [[ $OPS == "openSUSE"* ]] || [[ $OPS == "Linux Mint"* ]]; then
	PROMPT_PREFIX='%{$fg_bold[green]%}[%{$fg_bold[yellow]%}%D{%l:%M:%S%p, %a %d/%m/%y}%{$fg_bold[green]%}|%{$fg_bold[cyan]%}${OPS}%{$fg_bold[green]%}] $(user) %{$fg_bold[cyan]%}%(!.%1~.%~) $(git_prompt_info)'
elif [[ $OPS == "NixOS"* ]]; then
	PROMPT_PREFIX='%{$fg_bold[yellow]%}[%D{%l:%M:%S%p, %a %d/%m/%y}|%{$fg_bold[blue]%}${OPS}] $(user) %{$fg_bold[blue]%}%(!.%1~.%~) $(git_prompt_info)'
elif [[ ${OPS} == "CentOS"* ]]; then
	PROMPT_PREFIX='%{$fg_bold[yellow]%}[%D{%l:%M:%S%p, %a, %d/%m/%y}|%{$fg_bold[cyan]%}${OPS}] $(user) %{$fg_bold[blue]%}%(!.%1~.%~) $(git_prompt_info)'
elif [[ ${OPS} == "FreeBSD"* ]] || [[ ${OPS} == "Scientific Linux"* ]] || [[ ${OPS} == "Ubuntu"* ]] ; then
	PROMPT_PREFIX='%{$fg_bold[yellow]%}[%D{%l:%M:%S%p, %a, %d/%m/%y}|%{$fg_bold[red]%}${OPS}] $(user) %{$fg_bold[blue]%}%(!.%1~.%~) $(git_prompt_info)'
elif [[ ${OPS} == "Arch Linux"* ]] || [[ ${OPS} == "Fedora"* ]] || [[ ${OPS} == "Mageia"* ]]; then
	PROMPT_PREFIX='%{$fg_bold[yellow]%}[%D{%l:%M:%S%p, %a, %d/%m/%y}|%{$fg_bold[blue]%}${OPS}] $(user) %{$fg_bold[blue]%}%(!.%1~.%~) $(git_prompt_info)'
elif [[ ${OPS} == "Gentoo Linux"* ]]; then
	PROMPT_PREFIX='%{$fg_bold[yellow]%}[%D{%l:%M:%S%p, %a, %d/%m/%y}|%{$fg_bold[purple]%}${OPS}] $(user) %{$fg_bold[blue]%}%(!.%1~.%~) $(git_prompt_info)'
elif [[ ${OPS} == "Void"* ]]; then
	PROMPT_PREFIX='%{$fg_bold[yellow]%}[%D{%l:%M:%S%p, %a, %d/%m/%y}|%{$fg_bold[white]%}${OPS}] $(user) %{$fg_bold[blue]%}%(!.%1~.%~) $(git_prompt_info)'
elif [[ $(uname) == "Linux" ]]; then
	echo "Linux selected"
	PROMPT_PREFIX='%{$fg_bold[yellow]%}[%D{%l:%M:%S%p, %a, %d/%m/%y}|%{$fg_bold[yellow]%}${OPS}] $(user) %{$fg_bold[blue]%}%(!.%1~.%~) $(git_prompt_info)'
fi

setopt prompt_subst

PROMPT="${PROMPT_PREFIX}\$(conditional_newline)\$(prompt_char)%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_PREFIX="("
ZSH_THEME_GIT_PROMPT_SUFFIX=")"
