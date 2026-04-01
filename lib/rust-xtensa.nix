{
  pkgs,
  stdenv,
  fetchurl,
  toolchainVersions,
  systemMap,
}:

let
  versionInfo = toolchainVersions.rust-xtensa;
  system = stdenv.hostPlatform.system;
  platform = systemMap.${system} or (throw "Unsupported system: ${system}");

  # ESP32 Rust targets
  targets = [
    "xtensa-esp32-none-elf"
    "xtensa-esp32s2-none-elf"
    "xtensa-esp32s3-none-elf"
    "riscv32imc-unknown-none-elf"
    "riscv32imac-unknown-none-elf"
  ];
in
stdenv.mkDerivation rec {
  pname = "rust-xtensa";
  version = versionInfo.version;

  # Using esp-rs/rust-build releases
  src = fetchurl {
    url = "https://github.com/esp-rs/rust-build/releases/download/v${version}/rust-${version}-${platform}.tar.xz";
    sha256 = versionInfo.sha256;
  };

  nativeBuildInputs = [ pkgs.xz ];

  phases = [
    "unpackPhase"
    "installPhase"
  ];

  unpackPhase = ''
    echo "Extracting Rust..."
    tar xf $src
  '';

  installPhase = ''
    mkdir -p $out

    # Find the extracted directory
    extractedDir=$(find . -maxdepth 1 -type d -name "rust-*" | head -1)

    if [ -d "$extractedDir" ]; then
      cp -r $extractedDir/* $out/
    else
      cp -r ./* $out/
    fi

    # Ensure bin directory exists
    mkdir -p $out/bin
    chmod -R +x $out/bin/ 2>/dev/null || true

    # Create wrapper scripts that set proper environment
    mkdir -p $out/nix-support

    # Add to PATH and set up Rust flags for ESP32 targets
    cat > $out/nix-support/setup-hook << 'EOF'
      export PATH="${placeholder "out"}/bin:$PATH"
      
      # Set RUST_SRC_PATH for rust-analyzer
      if [ -d "${placeholder "out"}/lib/rustlib/src/rust/library" ]; then
        export RUST_SRC_PATH="${placeholder "out"}/lib/rustlib/src/rust/library"
      fi
      
      # Target-specific linker settings (can be overridden by user)
      export CARGO_TARGET_XTENSA_ESP32_NONE_ELF_LINKER="xtensa-esp32-elf-gcc"
      export CARGO_TARGET_XTENSA_ESP32S2_NONE_ELF_LINKER="xtensa-esp32s2-elf-gcc"
      export CARGO_TARGET_XTENSA_ESP32S3_NONE_ELF_LINKER="xtensa-esp32s3-elf-gcc"
      export CARGO_TARGET_RISCV32IMC_UNKNOWN_NONE_ELF_LINKER="riscv32-esp-elf-gcc"
      export CARGO_TARGET_RISCV32IMAC_UNKNOWN_NONE_ELF_LINKER="riscv32-esp-elf-gcc"
      
      # Set LLVM path if available
      if [ -n "$LLVM_ESP_PATH" ]; then
        export LIBCLANG_PATH="$LLVM_ESP_PATH/lib"
      fi
    EOF

    # Create rustup-like wrappers if needed
    for binary in cargo rustc rustfmt clippy-driver; do
      if [ -f "$out/bin/$binary" ]; then
        chmod +x "$out/bin/$binary"
      fi
    done
  '';

  dontStrip = true;

  meta = with pkgs.lib; {
    description = "Rust compiler with Xtensa support for ESP32";
    homepage = "https://github.com/esp-rs/rust-build";
    license = licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
  };
}
