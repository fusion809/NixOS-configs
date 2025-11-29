{ pkgs, ... }: {
  defaultUserShell = pkgs.zsh;
  users.fusion809 = {
    isNormalUser = true;
    description = "Brenton";
    extraGroups = [ "networkmanager" "wheel" "input" "docker" "libvirtd" ];
    packages = with pkgs;
      [
        #  thunderbird
      ];
  };
}
