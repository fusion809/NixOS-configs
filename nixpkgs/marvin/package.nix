{ lib, stdenv, fetchurl, dpkg, makeWrapper, coreutils, gawk, gnugrep, gnused
, openjdk17, freetype, fontconfig, libXi, libX11, libXext, libXtst, libXrender,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "marvin";
  version = "26.1.1";

  src = fetchurl {
    name = "marvin-${finalAttrs.version}.deb";
    url =
      "http://dl.chemaxon.com/marvin/${finalAttrs.version}/marvin_linux_${finalAttrs.version}.deb";
    hash = "sha256-s52e/J6ohtUv5mSfEXaOGeC1FKkjwgFUH7wLSGqZRFM=";
  };

  nativeBuildInputs = [ dpkg makeWrapper ];

  buildInputs = [ freetype fontconfig libXi libX11 libXext libXtst libXrender ];

  unpackPhase = ''
    dpkg-deb -x $src opt
  '';

  installPhase = ''
    wrapBin() {
      makeWrapper $1 $out/bin/$(basename $1) \
        --set INSTALL4J_JAVA_HOME "${openjdk17}" \
        --prefix LD_LIBRARY_PATH : ${
          lib.makeLibraryPath finalAttrs.buildInputs
        } \
        --prefix PATH : ${lib.makeBinPath [ coreutils gawk gnugrep gnused ]}
    }
    cp -r opt $out
    mkdir -p $out/bin $out/share/pixmaps $out/share/applications
    for name in LicenseManager MarvinSketch MarvinView; do
      wrapBin $out/opt/chemaxon/marvinsuite/$name
      ln -s {$out/opt/chemaxon/marvinsuite/.install4j,$out/share/pixmaps}/$name.png
    done
    for name in cxcalc cxtrain evaluate molconvert mview msketch; do
      wrapBin $out/opt/chemaxon/marvinsuite/bin/$name
    done
    ${lib.concatStrings (map (name: ''
      substitute ${
        ./. + "/${name}.desktop"
      } $out/share/applications/${name}.desktop --subst-var out
    '') [ "LicenseManager" "MarvinSketch" "MarvinView" ])}
  '';

  meta = with lib; {
    description = "Chemical modelling, analysis and structure drawing program";
    homepage = "https://chemaxon.com/products/marvin";
    maintainers = with maintainers; [ fusion809 ];
    license = licenses.unfree;
    platforms = platforms.linux;
  };
})
