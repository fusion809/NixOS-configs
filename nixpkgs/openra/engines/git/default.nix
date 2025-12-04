{ buildOpenRAEngine, dotnetCorePackages }:

buildOpenRAEngine {
  build = "git";
  version = "30626.git.79567f3";
  rev = "79567f3f8af761bfe34f11874586097d32397e41";
  hash = "sha256-NLkfwAPRvwpxeVv2zIY6dxPQ9C0Yv28lba12QIAEgGo=";
  deps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0-bin;
}
