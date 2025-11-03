# My NixOS configuration files
These are my NixOS 25.05 configuration files for running on my MS-7B90 PC.

To update the deps.json file for OpenRA git package, run:

```bash
nix-build --arg pkgs '(import <nixpkgs> {})' -A engines.git
```

in nixpkgs/openra. 