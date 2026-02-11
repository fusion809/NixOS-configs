#!/usr/bin/env bash

# Centralized OS icon mapping
function get_os_icon {
	local name_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
	case "$name_lower" in
		*debian*) echo "" ;;
		*alpine*) echo "" ;;
		*alma*) echo "";;
		*arch*|*bedrock*) echo "" ;;
		*crux*) echo "󰇥";;
		*fedora*) echo "" ;;
		*freebsd*) echo "" ;;
		*gentoo*) echo "" ;;
		*linux*mint*) echo "" ;;
		*mageia*) echo "" ;;
		*openbsd*) echo "" ;;
		*aeryn*) echo "";;
		*pld*) echo "";;
		*rhino*) echo "";;
		*netbsd*) echo "";;
		*haiku*) echo "󰌪";;
		*gobo*) echo "";;
		*aosc*) echo "";;
		*rlxos*) echo "󰬙";;
		*dragon*) echo "";;
		*q4os*) echo "";;
		*4mlinux*) echo "󱓸";; # DW screenshot wallpaper looked like a light pole
		*mocaccino*) echo "";;
		*openmamba*) echo "󱔎";; # snake logo as reminds me of black mamba snake
		*alt*|*pclinuxos*|*openmandriva*|*rosa*) echo "";;
		*red*hat*) echo "";;
		*opensuse*|*tumbleweed*|*leap*) echo "" ;;
		*pop!_os*|*pop-os*) echo "" ;;
		*rocky*) echo "" ;;
		*slackware*) echo "" ;;
		*openindiana*|*smart*) echo "";; # Solaris family denoted with a solar eclipse logo
		*chimera*) echo "";; # Blender logo as it blends aspects of FreeBSD and Linux
		*solus*) echo "" ;;
		*ubuntu*) echo "" ;;
		*void*) echo "" ;;
		*zorin*) echo "" ;;
		*nixos*) echo "" ;;
		*manjaro*) echo "" ;;
		*kali*) echo "" ;;
		*centos*) echo "" ;;
		*raspbian*) echo "" ;;
		*elementary*) echo "" ;;
		*guix*) echo "" ;;
		*deepin*) echo "" ;;
		*devuan*) echo "" ;;
		*vanilla*) echo "";;
		*illumos*) echo "" ;;
		*redos*) echo "";;
		*reactos*) echo "";;
		*sabayon*) echo "" ;;
		*windows*) echo "" ;;
		*vine*) echo "";;
		*adelie*) echo "󰻀";;
		*venom*) echo "";;
		*pisi*) echo "";;
		*milis*) echo "󱜛";;
		*kolibri*) echo "󱗆";;
		*apple*|*macos*|*osx*) echo "" ;;
		*android*) echo "" ;;
		*exherbo*) echo "󰆚";;
		*gnome*) echo "" ;;
		*kde*) echo "" ;;
		*linux*from*scratch*) echo "" ;;
		*) echo "" ;; # Generic Linux/Unix
	esac
}
