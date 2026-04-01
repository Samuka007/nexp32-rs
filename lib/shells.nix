{
  pkgs,
  lib,
  complete,
  xtensa-gcc,
}:

let
  # Common packages for all ESP32 shells
  commonPackages = with pkgs; [
    cmake
    ninja
    gnumake
    gcc
    pkg-config
    python3
    python3Packages.pip
    python3Packages.virtualenv
    git
    curl
    wget
    cargo-generate
    rust-analyzer
    esp-generate
    espflash
  ];

  makeShellHook = target: extraEnv: ''
    echo ""
    echo "=========================================="
    echo "ESP32 Development Shell - ${target}"
    echo "=========================================="
    echo ""
    echo "Rust toolchain: ${complete}/bin/rustc"
    echo "GCC toolchain: ${xtensa-gcc}/bin/xtensa-esp32-elf-gcc"
    echo ""
    echo "ESP tools:"
    echo "  - esp-generate --chip <esp32|esp32s2|esp32s3> <project-name>"
    echo ""
    export PATH="${complete}/bin:${xtensa-gcc}/bin:$HOME/.cargo/bin:$PATH"
    export RUST_SRC_PATH="${complete}/lib/rustlib/src/rust/library"
    export RUSTC_SYSROOT="${complete}"
    
    # Configure GCC as the linker for Xtensa targets
    export CARGO_TARGET_XTENSA_ESP32_NONE_ELF_LINKER="xtensa-esp32-elf-gcc"
    export CARGO_TARGET_XTENSA_ESP32S2_NONE_ELF_LINKER="xtensa-esp32-elf-gcc"
    export CARGO_TARGET_XTENSA_ESP32S3_NONE_ELF_LINKER="xtensa-esp32-elf-gcc"
    
    ${extraEnv}
  '';

in
{
  default = pkgs.mkShell {
    name = "esp32-all-dev";
    buildInputs = commonPackages ++ [ complete xtensa-gcc ];
    shellHook = makeShellHook "All Xtensa ESP32 Targets" ''
      echo ""
      echo "Available Xtensa targets:"
      echo "  - xtensa-esp32-none-elf (ESP32 - Original)"
      echo "  - xtensa-esp32s2-none-elf (ESP32-S2 - Single core, WiFi only)"
      echo "  - xtensa-esp32s3-none-elf (ESP32-S3 - Dual core, WiFi + BLE)"
    '';
  };

  std = pkgs.mkShell {
    name = "esp32-std-dev";
    buildInputs = commonPackages ++ [
      complete
      xtensa-gcc
      (pkgs.callPackage ./esp-idf.nix { })
    ];
    shellHook = makeShellHook "ESP32 with ESP-IDF" ''
      echo "ESP-IDF std development ready!"
    '';
  };
}
