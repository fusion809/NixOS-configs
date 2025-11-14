{ buildOpenRAEngine, dotnetCorePackages }:

buildOpenRAEngine {
  build = "git";
  version = "30597.git.0ed00a5";
  rev = "0ed00a57662b7d132e51c492d9b62de84c98e213";
  hash = "sha256-IG1+kRD5yjixUStDF16l9OXFcKGI3WgIzf3W2NoDisM=";
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
