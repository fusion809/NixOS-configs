{ buildOpenRAEngine }:

buildOpenRAEngine {
  build = "playtest";
  version = "20241228";
  sha256 = "sha256-N0cpM2ZQ2CuBXw18waz0Hvt8SMv8bwSre6T9BSoYvM4=";
  deps = ./deps.json;
}
