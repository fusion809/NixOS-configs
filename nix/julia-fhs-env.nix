{
  pkgs ? import <nixpkgs> { },
}:

let
  juliaPkg = pkgs.unstable.julia or pkgs.julia;

  commonPkgs =
    pkgs: with pkgs; [
      juliaPkg

      # C / C++ / Fortran compilers & runtimes for native dependencies & JLL artifacts
      gcc
      gcc-unwrapped.lib
      gfortran
      stdenv.cc.cc.lib
      gfortran.cc.lib
      gnumake
      cmake
      pkg-config

      # Core system libraries
      glibc
      zlib
      curl
      openssl
      libuv
      pcre2
      mbedtls
      libunwind
      libgit2

      # Graphics, fonts, and plotting support (GR, Makie, Plots, Cairo, etc.)
      fontconfig
      fontconfig.dev
      freetype
      freetype.dev
      libpng
      libpng.dev
      libjpeg
      libjpeg.dev
      expat
      cairo
      pango
      glib
      mesa
      libglvnd
      xorg.libX11
      xorg.libXext
      xorg.libXrender
      xorg.libXcursor
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libxcb
    ];

  julia-fhs = pkgs.buildFHSEnv {
    name = "julia";
    targetPkgs = commonPkgs;
    extraOutputsToInstall = [ "lib" "out" "dev" ];
    profile = ''
      export LD_LIBRARY_PATH=/lib:/lib64:/usr/lib:/usr/lib64:$LD_LIBRARY_PATH
    '';
    runScript = "julia";
  };

in
pkgs.symlinkJoin {
  name = "julia-fhs-envs";
  paths = [ julia-fhs ];
}
