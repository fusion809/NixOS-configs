#!/bin/bash
lfs_ver=$(wget -cqO- https://www.linuxfromscratch.org/lfs/view/systemd/index.html | grep 'Version' | sed 's/^\s*//g' | cut -d ' ' -f 2 | sed 's/-systemd//g')
blfs_ver=$(wget -cqO- https://www.linuxfromscratch.org/blfs/view/systemd/ | grep "id=\"" | head -n 1 | cut -d '"' -f 4 | sed 's/blfs-//g')
if echo $upver | grep '^r'; then
    sudo sed -i -E "s|r[0-9]{2,}\.[0-9]-[0-9]+|$lfs_ver|g" /etc/os-release /etc/lfs-release /etc/lsb-release
    sudo sed -i -E "s|r[0-9]{2,}\.[0-9]-[0-9]+|$blfs_ver|g" /etc/blfs-release
fi