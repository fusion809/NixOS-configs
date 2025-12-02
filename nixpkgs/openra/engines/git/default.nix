{ buildOpenRAEngine, dotnetCorePackages }:

buildOpenRAEngine {
  build = "git";
  version = "30624.git.b429ca7";
  rev = "b429ca7879b4448396d98dcb67193af1af6b545f";
  hash = "sha256-r+x21wJ5jFsv3jUyMqVZ3YXWh2oKRXMr2jYljvlLDAc=";
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
