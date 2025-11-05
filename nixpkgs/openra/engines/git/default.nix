{ buildOpenRAEngine, dotnetCorePackages }:

buildOpenRAEngine {
  build = "git";
  rev = "a62b085f1d95c856f1be6e4240ea193c4fdadd34";
  hash = "sha256-IqA90UGCttEkfa0GEQvcSqQ8gAl2q3wd/HyyYFOfjB8=";
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
