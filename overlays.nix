[ (self: super:

let
  pkgs = self;
  inherit (pkgs) lib;
  callPackage = lib.callPackageWith (pkgs // builtins.removeAttrs pkgs.xorg [ "callPackage" "newScope" "overrideScope" "packages" ]);
  github = /home/fusion809/GitHub;
  gitother = github + /others;
  gitpkgs = github + /mine/packaging;
  forkNixpkgsPath = gitpkgs + /nixpkgs;

in with pkgs; {
  fork = import forkNixpkgsPath {
    config = {
      allowUnfree = true;
    };
    overlays = [ ];
  };

stdenv = super.stdenv // { inherit lib; };
  lib = super.lib.recursiveUpdate super.lib {
    maintainers = {
      fusion809 = {
        email = "brentonhorne77@gmail.com";
        github = "fusion809";
        name = "Brenton Horne";
      };
    };
  };

#  openraPackages = import (/data/GitHub/others/nixpkgs-msteen/pkgs/games/openra) pkgs;
  openraPackages = import (forkNixpkgsPath + /pkgs/games/openra) pkgs;
  openra = openraPackages.engines.release;

  vim = callPackage (forkNixpkgsPath + /pkgs/applications/editors/vim) { 
    inherit (darwin) cf-private;
    inherit (darwin.apple_sdk.frameworks) Carbon Cocoa;
  };

  vimHugeX = vim_configurable;

  vim_configurable = vimUtils.makeCustomizable (callPackage ( forkNixpkgsPath + /pkgs/applications/editors/vim/configurable.nix ) { 
    inherit (darwin.apple_sdk.frameworks) CoreServices Cocoa Foundation CoreData;
    inherit (darwin) libobjc cf-private;
    gtk2 = if stdenv.isDarwin then gtk2-x11 else gtk2;
    gtk3 = if stdenv.isDarwin then gtk3-x11 else gtk3;
  });

  vscode = callPackage (forkNixpkgsPath + /pkgs/applications/editors/vscode) {};
  marvin = callPackage (forkNixpkgsPath + /pkgs/applications/science/chemistry/marvin) { };
  googleearth = callPackage (/home/fusion809/GitHub/mine/packaging/nixpkgs.googleearth-pr/pkgs/applications/misc/googleearth) {};
  appimageTools = callPackage (gitother + /nixpkgs-tilpner/pkgs/build-support/appimage) {};
    thunderbird = callPackage (forkNixpkgsPath + /pkgs/applications/networking/mailreaders/thunderbird ) {
    inherit (gnome2) libIDL;
    libpng = libpng_apng;
    enableGTK3 = true;
  };
    inherit (
    let
      defaultOctaveOptions = {
        qt = null;
        ghostscript = null;
        graphicsmagick = null;
        llvm = null;
        hdf5 = null;
        glpk = null;
        suitesparse = null;
        jdk = null;
        openblas = if stdenv.isDarwin then openblasCompat else openblas;
      };

      hgOctaveOptions =
        (removeAttrs defaultOctaveOptions ["ghostscript"]) // {
          overridePlatforms = stdenv.lib.platforms.none;
        };
    in {
      octave = callPackage (forkNixpkgsPath + /pkgs/development/interpreters/octave ) defaultOctaveOptions;
      octaveHg = lowPrio (callPackage (forkNixpkgsPath + /pkgs/development/interpreters/octave/hg.nix ) hgOctaveOptions);
  }) octave octaveHg;

  octaveFull = (lowPrio (octave.override {
    qt = qt4;
    overridePlatforms = ["x86_64-linux" "x86_64-darwin"];
    openblas = if stdenv.isDarwin then openblasCompat else openblas;
  }));

}) ]

