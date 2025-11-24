{ buildOpenRAEngine, dotnetCorePackages }:

buildOpenRAEngine {
  build = "git";
  version = "30617.git.7e8f4a3";
  rev = "7e8f4a3479d704662a0f39a73476d2beb46004c1";
  hash = "sha256-XifwpAhyWv04qyEMzkj2UsW37RWUUoJYq5U17hzKvPA=";
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
