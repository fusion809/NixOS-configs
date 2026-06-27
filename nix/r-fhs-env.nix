{
  pkgs ? import <nixpkgs> { },
}:

let
  commonPkgs =
    pkgs: with pkgs; [
      R

      # R package compilation tools
      gcc
      gnumake
      cmake
      pkg-config

      # Missing dependencies reported by user
      cargo
      rustc
      zlib
      zlib.dev
      curl
      curl.dev
      libuv
      libuv.dev

      # Common libraries that R packages tend to need
      openssl
      openssl.dev
      libxml2
      libxml2.dev
      fontconfig
      fontconfig.dev
      freetype
      freetype.dev
      harfbuzz
      harfbuzz.dev
      fribidi
      fribidi.dev
      libpng
      libpng.dev
      libjpeg
      libjpeg.dev
      libtiff
      libtiff.dev
      bzip2
      bzip2.dev
      glib
      glib.dev
      pcre2
      pcre2.dev
      xz
      xz.dev
      icu
      icu.dev
      xorg.libX11
      xorg.libX11.dev
    ];

  r-fhs = pkgs.buildFHSEnv {
    name = "R";
    targetPkgs = commonPkgs;
    runScript = "R";
  };

in
pkgs.symlinkJoin {
  name = "r-fhs-envs";
  paths = [ r-fhs ];
}
