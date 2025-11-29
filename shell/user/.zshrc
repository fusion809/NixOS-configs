autoload -U colors && colors
export HISTSIZE=10000000
export SAVEHIST=10000000
cp $HOME/.zsh_history $HOME/.zsh_history.back$(date +"%Y-%m-%d_%H-%M-%S")
sed -i '/^:/!d' $HOME/.zsh_history
function shopt {
  #echo "shopt called with arguments: $@"
}
source $HOME/GitHub/mine/config/NixOS-configs/shell/user/main.sh
source $NIXCFG/shell/hnixos.zsh-theme