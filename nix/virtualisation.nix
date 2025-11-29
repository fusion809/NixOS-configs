{ pkgs, ... }: {
  docker = { enable = true; };
  libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };
  spiceUSBRedirection.enable = true;
}
