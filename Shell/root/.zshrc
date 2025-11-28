cp $HOME/.zsh_history $HOME/.zsh_history.back$(date +"%Y-%m-%d_%H-%M-%S")
sed -i '/^:/!d' $HOME/.zsh_history
source /etc/profile
source /home/fusion809/GitHub/mine/config/NixOS-configs/Shell/root/main.sh
source $NIXPKGS/hnixos.zsh-theme
