{ pkgs, username, ... }: {
  defaultUserShell = pkgs.zsh;
  users.${username} = {
    isNormalUser = true;
    description = "Brenton";
    extraGroups = [ "networkmanager" "wheel" "input" "docker" "libvirtd" ];
    packages = with pkgs;
      [
        #  thunderbird
      ];
  };
}
