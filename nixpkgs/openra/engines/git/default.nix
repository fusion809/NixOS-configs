{ buildOpenRAEngine, dotnetCorePackages }:

buildOpenRAEngine {
  build = "git";
  version = "30590.git.3f19c81";
  rev = "3f19c813920363f9bb45b344b313d8819c2cb52f";
  hash = "sha256-NENad/SUwt4ZkZt/OVVzxwQt3ro/7Zak3anu5Ko0YD4=";
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
