{ buildOpenRAEngine }:

buildOpenRAEngine {
  build = "git";
  version = "2126f3c5a205654ee0230b4b048369378c7f4471";
  sha256 = "sha256-T6bmwfzNGyCbZ4iRcVgLgx7d9KokorHIvIrYxhf4L8E=";
  deps = ./deps.json;
}
