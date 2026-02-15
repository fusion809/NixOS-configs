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
  hash = "sha256-Vu3IROvMeq1gD7OGQA3cy97l4R5v/CyY1IbkuZynrqs=";
  src = openraSrc;
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
