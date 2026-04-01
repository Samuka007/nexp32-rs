{
  pkgs,
  stdenv,
  fetchurl,
  makeWrapper,
  toolchainVersions,
  systemMap,
  target,
}:

let
  versionInfo = toolchainVersions.xtensa-esp32-elf;
  system = stdenv.hostPlatform.system;
  platform = systemMap.${system} or (throw "Unsupported system: ${system}");
in
stdenv.mkDerivation rec {
  pname = target;
  version = versionInfo.version;

  src = fetchurl {
    url = "https://github.com/espressif/crosstool-NG/releases/download/${version}/${target}-${version}-${platform}.tar.xz";
    sha256 = versionInfo.sha256;
  };

  nativeBuildInputs = [
    pkgs.xz
    makeWrapper
  ];

  phases = [
    "unpackPhase"
    "installPhase"
    "fixupPhase"
  ];

  unpackPhase = ''
    echo "Extracting toolchain..."
    tar xf $src

    # Find the extracted directory
    extractedDir=$(find . -maxdepth 1 -type d -name "${target}-*" | head -1)
    if [ -z "$extractedDir" ]; then
      echo "Error: Could not find extracted directory"
      ls -la
      exit 1
    fi
    echo "Found extracted directory: $extractedDir"
  '';

  installPhase = ''
    mkdir -p $out

    # Find the extracted directory again (in new shell)
    extractedDir=$(find . -maxdepth 1 -type d -name "${target}-*" | head -1)

    if [ -d "$extractedDir" ]; then
      cp -r $extractedDir/* $out/
    else
      echo "Error: Extracted directory not found"
      exit 1
    fi

    # Ensure bin directory exists
    mkdir -p $out/bin

    # Make all binaries executable
    chmod -R +x $out/bin/ 2>/dev/null || true

    # Create symlinks for common tools if they don't exist
    # This helps with compatibility
    for tool in gcc g++ cpp ld as ar ranlib strip objcopy objdump readelf nm size strings; do
      if [ -f "$out/bin/${target}-$tool" ] && [ ! -f "$out/bin/$tool" ]; then
        ln -sf "${target}-$tool" "$out/bin/$tool" 2>/dev/null || true
      fi
    done
  '';

  # Don't strip the binaries - they're cross-compilers
  dontStrip = true;

  # Don't patch ELF - they're for different architecture
  dontPatchELF = true;

  meta = with pkgs.lib; {
    description = "Xtensa toolchain for ESP32 microcontrollers";
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
