{ buildOpenRAEngine, dotnetCorePackages }:

buildOpenRAEngine {
  build = "git";
  version = "30604.git.56e6a9e";
  rev = "56e6a9e6dc4f649b9c5939847e5673c04b3670c1";
  hash = "sha256-v+o5mqheTAKgI5U7MIwVYcitU2APFCPDD3DI7m85ZoA=";
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
