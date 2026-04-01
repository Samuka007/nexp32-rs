{
  pkgs,
  stdenv,
  fetchurl,
  makeWrapper,
  toolchainVersions,
  systemMap,
}:

let
  versionInfo = toolchainVersions.llvm-esp;
  system = stdenv.hostPlatform.system;
  platform = systemMap.${system} or (throw "Unsupported system: ${system}");
in
stdenv.mkDerivation rec {
  pname = "llvm-esp";
  version = versionInfo.version;

  src = fetchurl {
    url = "https://github.com/espressif/llvm-project/releases/download/${version}/clang-${version}-${platform}.tar.xz";
    sha256 = versionInfo.sha256;
  };

  nativeBuildInputs = [ pkgs.xz ];

  phases = [
    "unpackPhase"
    "installPhase"
  ];

  unpackPhase = ''
    echo "Extracting LLVM..."
    tar xf $src
  '';

  installPhase = ''
    mkdir -p $out

    # Find the extracted directory
    extractedDir=$(find . -maxdepth 1 -type d -name "llvm-*" | head -1)

    if [ -d "$extractedDir" ]; then
      cp -r $extractedDir/* $out/
    else
      cp -r ./* $out/
    fi

    # Ensure bin directory exists
    mkdir -p $out/bin
    chmod -R +x $out/bin/ 2>/dev/null || true

    # Create a setup hook for libclang path
    mkdir -p $out/nix-support
    cat > $out/nix-support/setup-hook << 'EOF'
      export LLVM_ESP_PATH="${placeholder "out"}"
      export LIBCLANG_PATH="${placeholder "out"}/lib"
    EOF
  '';

  dontStrip = true;

  meta = with pkgs.lib; {
    description = "LLVM with Xtensa support for ESP32";
    homepage = "https://github.com/espressif/llvm-project";
    license = licenses.asl20;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
  };
}
