#!/run/current-system/sw/bin/zsh
ssh-keygen -t rsa -b 4096 -C "brentonhorne77@gmail.com"
git config --global user.name "fusion809"
git config --global user.email "brentonhorne77@gmail.com"
clipf $HOME/.ssh/id_rsa.pub
printf "Go to https://github.com/settings/keys and create new SSH key.\n The contents are in your clipboard"
./setup-symlinks.sh

