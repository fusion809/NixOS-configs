#cp $HOME/.zsh_history $HOME/.zsh_history.back$(date +"%Y-%m-%d_%H-%M-%S")
#sed -i '/^:/!d' $HOME/.zsh_history
source /etc/profile
# User and config dir are set by Nix during evaluation
# These should be provided by the environment or set in programs.nix
source $NIXCFG/shell/root/main.sh
source $NIXCFG/shell/hnixos.zsh-theme
