{ ... }:

{
  settings = {
    experimental-features = [ "nix-command" "flakes" ];
    keep-outputs = false;
    keep-derivations = false;
  };
}
