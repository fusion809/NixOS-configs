{ buildOpenRAEngine, dotnetCorePackages }:

buildOpenRAEngine {
  build = "git";
  version = "20250531";
  version = "2cb1e5f8c546196e911827e5d33f3b686c3bf452";
  sha256 = "sha256-cAUAVdcoiAGo9x9ADs/QmFQ1sviVTMiqJilPrRbTexI=";
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
