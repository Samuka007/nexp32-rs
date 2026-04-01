{
  pkgs,
  stdenv,
  fetchurl,
  toolchainVersions,
  systemMap,
}:

let
  versionInfo = toolchainVersions.riscv32-esp-elf;
  system = stdenv.hostPlatform.system;
  platform = systemMap.${system} or (throw "Unsupported system: ${system}");
in
stdenv.mkDerivation rec {
  pname = "riscv32-esp-elf";
  version = versionInfo.version;

  src = fetchurl {
    url = "https://github.com/espressif/crosstool-NG/releases/download/${version}/riscv32-esp-elf-${version}-${platform}.tar.xz";
    sha256 = versionInfo.sha256;
  };

  nativeBuildInputs = [ pkgs.xz ];

  phases = [
    "unpackPhase"
    "installPhase"
  ];

  unpackPhase = ''
    echo "Extracting RISC-V toolchain..."
    tar xf $src
  '';

  installPhase = ''
    mkdir -p $out

    # Find the extracted directory
    extractedDir=$(find . -maxdepth 1 -type d -name "riscv32-esp-elf-*" | head -1)

    if [ -d "$extractedDir" ]; then
      cp -r $extractedDir/* $out/
    else
      cp -r ./* $out/
    fi

    # Ensure bin directory exists and tools are executable
    mkdir -p $out/bin
    chmod -R +x $out/bin/ 2>/dev/null || true
  '';

  dontStrip = true;
  dontPatchELF = true;

  meta = with pkgs.lib; {
    description = "RISC-V toolchain for ESP32-C2/C3/C6/H2/P4 microcontrollers";
    homepage = "https://github.com/espressif/crosstool-NG";
    license = licenses.gpl3;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
  };
}
