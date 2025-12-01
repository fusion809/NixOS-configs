{ buildOpenRAEngine, dotnetCorePackages }:

buildOpenRAEngine {
  build = "git";
  version = "30621.git.62e6920";
  rev = "62e692063ad9d5a39bc1566308aecf89ce9bb95b";
  hash = "sha256-ij0Qwt5fzI+hCv1EXAdQ5BTekv3GQ1/zcsoaZxyPyDo=";
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
