{ buildOpenRAEngine, dotnetCorePackages }:

buildOpenRAEngine {
  build = "git";
  version = "30625.git.8b8651d";
  rev = "8b8651dcf74c2ec00f64b1ac23cf207d7251eeb6";
  hash = "sha256-4lfgzELsmLG4enbTtVIYfguFycuhquEp3iIV3WsxyaA=";
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
