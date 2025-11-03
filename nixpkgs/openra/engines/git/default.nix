{ buildOpenRAEngine, dotnetCorePackages }:

buildOpenRAEngine {
  build = "git";
  version = "20250531";
  rev = "10db26fa0b3df25e679b465475fe69b21381b26b";
  hash = "sha256-8DZDjnviZyQ+9PuA0hyRn6tyyGqlqBX6C5GkOUjzidM=";
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
