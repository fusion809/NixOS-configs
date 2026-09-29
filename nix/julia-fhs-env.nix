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
      # NOTE: Do NOT include libunwind, libuv, libgit2, pcre2, or mbedtls here.
      # Julia requires its own patched/bundled versions (especially libunwind for JIT DWARF unwinding).
      glibc
      zlib
      curl
      openssl

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
      libx11
      libxext
      libxrender
      libxcursor
      libxfixes
      libxi
      libxrandr
      libxcb
    ];

  julia-fhs = pkgs.buildFHSEnv {
    name = "julia";
    targetPkgs = commonPkgs;
    extraOutputsToInstall = [
      "lib"
      "out"
      "dev"
    ];
    extraBwrapArgs = [
      "--bind-try"
      "/data"
      "/data"
      "--bind-try"
      "/arch"
      "/arch"
    ];
    profile = ''
      export LD_LIBRARY_PATH=/usr/lib64/julia:/usr/lib/julia:/lib:/lib64:/usr/lib:/usr/lib64''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    '';
    runScript = "julia";
  };

in
pkgs.symlinkJoin {
  name = "julia-fhs-envs";
  paths = [ julia-fhs ];
}
