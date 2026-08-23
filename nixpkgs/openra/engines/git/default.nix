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
  hash = "sha256-WJGziDdVTu0RQzj7XctmnR4vgOBWNyl8sCt4xYFrcEc=";
  src = openraSrc;
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_10_0-bin;
}
