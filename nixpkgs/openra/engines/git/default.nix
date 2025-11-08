{ buildOpenRAEngine, dotnetCorePackages }:

buildOpenRAEngine {
  build = "git";
  version = "30591.git.7004b55";
  rev = "7004b552c9cbc9ab73f1ba3d019c5eeb2e88f405";
  hash = "sha256-UhIEc9CPqfB6BvOHC7H1yZfo41iDOPjL2MEkuxUd07o=";
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
