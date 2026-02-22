{ buildOpenRAEngine, dotnetCorePackages, homeDir }:

let
  # Use local Git repo to avoid re-downloading
  # Nix will cache this and only fetch updates
  openraSrc = builtins.fetchGit {
    url = "file://${homeDir}/GitHub/others/OpenRA";
    ref = "bleed";
  };

  shortRev = builtins.substring 0 7 openraSrc.rev;

  # Calculate version from git metadata (revCount is provided by fetchGit)
  version = "${toString openraSrc.revCount}.git.${shortRev}";

in buildOpenRAEngine {
  build = "git";
  inherit version;
  rev = openraSrc.rev;
  hash = "sha256-kyneRkh9Ii9xFqqC6I5TimWNl0tFrA73XhZOfBebg+o=";
  src = openraSrc;
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
