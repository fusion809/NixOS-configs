autoload -U colors && colors
export HISTSIZE=10000000
export SAVEHIST=10000000
#cp $HOME/.zsh_history $HOME/.zsh_history.back$(date +"%Y-%m-%d_%H-%M-%S")
#sed -i '/^:/!d' $HOME/.zsh_history
function shopt {
  #echo "shopt called with arguments: $@"
}
source $NIXCFG/shell/user/main.sh
source $NIXCFG/shell/hnixos.zsh