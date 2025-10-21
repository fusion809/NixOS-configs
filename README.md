# My NixOS configuration files
These are my configs for 25.05 on my actual hardware with UEFI. They do not currently work fully. I have tried to get Steam to run RuneScape properly by following the Wiki, specifically with:

```nix
programs.steam = {
  enable = true;
  remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
  dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
};
```

in my config. But this still doesn't seem to work. Steam will launch, yes, but RuneScape will not run via it. Even though it runs flawlessly on Arch. 

Likewise, I've also added:

```nix
  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableKvm = true;
  virtualisation.virtualbox.host.addNetworkInterface = false;
  virtualisation.virtualbox.host.enableExtensionPack = true;
  users.extraGroups.vboxusers.members = ["fusion809"];
```

to my config to get VirtualBox to work. The enableKvm and addNetworkInterface lines were based on this https://discourse.nixos.org/t/issue-with-virtualbox-in-24-11/57607 discourse discussion as an attempt to fix an issue wherein VirtualBox complained about KVM being enabled and wouldn't launch any VMs. Even with this my VMs fail to launch. 
