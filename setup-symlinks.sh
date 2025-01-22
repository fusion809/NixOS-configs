#!/run/current-system/sw/bin/zsh
sudo ln -sf $PWD/configuration.nix /etc/nixos/configuration.nix
sudo ln -sf $PWD/hardware-configuration.nix /etc/nixos/hardware-configuration.nix
ln -sf $PWD/.bashrc $HOME/.bashrc
ln -sf $PWD/.zshrc $HOME/.zshrc
sudo ln -sf $PWD/.root-bashrc /root/.bashrc
sudo ln -sf $PWD/.root-zshrc /root/.zshrc
