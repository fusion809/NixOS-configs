{ buildOpenRAEngine, dotnetCorePackages, runCommand }:

let
  # Use local Git repo to avoid re-downloading
  # Nix will cache this and only fetch updates
  openraSrc = builtins.fetchGit {
    url = "file:///home/fusion809/GitHub/others/OpenRA";
    ref = "bleed";
  };

  shortRev = builtins.substring 0 7 openraSrc.rev;

  # Calculate version from git commit count
  versionInfo = runCommand "openra-version" { } ''
    cd ${openraSrc}
    echo -n "$(git rev-list --count HEAD).git.${shortRev}" > $out
  '';

  version = builtins.readFile versionInfo;

in buildOpenRAEngine {
  build = "git";
  inherit version;
  rev = openraSrc.rev;
  hash = "sha256-NLkfwAPRvwpxeVv2zIY6dxPQ9C0Yv28lba12QIAEgGo=";
  src = openraSrc;
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
