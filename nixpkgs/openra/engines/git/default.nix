{ buildOpenRAEngine, dotnetCorePackages }:

buildOpenRAEngine {
  build = "git";
  version = "20250531";
  rev = "2cb1e5f8c546196e911827e5d33f3b686c3bf452";
  hash = "sha256-cAUAVdcoiAGo9x9ADs/QmFQ1sviVTMiqJilPrRbTexI=";
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
