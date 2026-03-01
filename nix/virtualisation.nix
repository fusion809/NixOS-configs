{ pkgs, ... }: {
  docker = { enable = true; };
  libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
      verbatimConfig = ''
        virtiofsd_path = "${pkgs.virtiofsd}/bin/virtiofsd"
      '';
    };
  };
  spiceUSBRedirection.enable = true;
}
