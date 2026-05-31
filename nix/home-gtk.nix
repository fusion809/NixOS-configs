{ config, ... }: {
  enable = true;
  theme = { name = "WhiteSur-Dark-solid"; };
  iconTheme = { name = "WhiteSur-dark"; };
  cursorTheme = { name = "WhiteSur-cursors"; };
  # Silence NixOS 26.05 warning: gtk.gtk4.theme default changed from
  # config.gtk.theme → null. Explicitly keep legacy behaviour.
  gtk4.theme = config.gtk.theme;
}
