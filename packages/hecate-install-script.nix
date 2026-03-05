{ stdenv, lib, makeWrapper, bash, coreutils, util-linux, jq, gnugrep, gawk, pciutils }:

stdenv.mkDerivation {
  pname = "hecate-install-script";
  version = "0.1.0";

  src = ../scripts/hecate-install.sh;
  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/hecate-install
    chmod +x $out/bin/hecate-install

    wrapProgram $out/bin/hecate-install \
      --prefix PATH : ${lib.makeBinPath [ bash coreutils util-linux jq gnugrep gawk pciutils ]}
  '';

  meta = {
    description = "hecatOS install engine — partitions disks and installs NixOS";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "hecate-install";
  };
}
