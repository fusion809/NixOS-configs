[ (self: super:

let
  pkgs = self;
  inherit (pkgs) lib;
  callPackage = lib.callPackageWith (pkgs // builtins.removeAttrs pkgs.xorg [ "callPackage" "newScope" "overrideScope" "packages" ]);
  github = /home/fusion809/GitHub;
  gitother = github + /others;
  gitpkgs = github + /mine/packaging;
  forkNixpkgsPath = gitpkgs + /nixpkgs;

  packageOverrides = pkgs: with pkgs; rec {
    # FF bin with plugins
    firefox-bin-wrapper = wrapFirefox { browser = firefox-bin; };
  };

in with pkgs; {
  fork = import forkNixpkgsPath {
    config = {
      allowUnfree = true;
    };
    overlays = [ ];
  };

  zsh = callPackage (forkNixpkgsPath + /pkgs/shells/zsh) {};

  # Code/text editors
  # Best run Atom in the chroot, as I only use it for Julia and
  # Julia is a very tedious package to build on NixOS
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

  # Chemistry
  jmol = callPackage (forkNixpkgsPath + /pkgs/applications/science/chemistry/jmol) {};
  marvin = callPackage (forkNixpkgsPath + /pkgs/applications/science/chemistry/marvin) { };
  
  # Maths software
  jabref = callPackage (forkNixpkgsPath + /pkgs/applications/office/jabref) {};
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

  sagemath = callPackage (forkNixpkgsPath + /pkgs/applications/science/math/sage) {};

  #masterpdfeditor = libsForQt5.callPackage (forkNixpkgsPath + /pkgs/applications/misc/masterpdfeditor) { };
  wpsoffice = let dict = builtins.fetchurl { url = "https://github.com/wps-community/wps_community_website/raw/master/root/download/dicts/en_GB.zip"; sha256 = "0056c14xjx7zz90cla4xajr6qznlim4lnr22cp3gfiqkvm32dzx0"; };
   in fork.wpsoffice.overrideAttrs (attrs: {
        installPhase = attrs.installPhase + ''
           ${super.unzip}/bin/unzip ${dict} -d $out/opt/kingsoft/wps-office/office6/dicts/spellcheck
        '';
    });
  # broken
  runescape-launcher = callPackage (forkNixpkgsPath + /pkgs/games/runescape-launcher) {} ;
  # flashplayer = callPackage (forkNixpkgsPath + /pkgs/applications/networking/browsers/mozilla-plugins/flashplayer) {};
  # brave = callPackage (forkNixpkgsPath + /pkgs/applications/networking/browsers/brave) {};
  # openraPackages = import (forkNixpkgsPath + /pkgs/games/openra) pkgs;
  # openra = openraPackages.engines.release;
  # appimageTools = callPackage (gitother + /nixpkgs/pkgs/build-support/appimage) {};
  # thunderbird = callPackage (forkNixpkgsPath + /pkgs/applications/networking/mailreaders/thunderbird ) {
  #  inherit (gnome2) libIDL;
  #  libpng = libpng_apng;
  #  enableGTK3 = true;
  #};
}) ]

