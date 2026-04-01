{
  pkgs,
  lib,
  xtensa-esp32-elf,
  llvm-esp,
  rust-xtensa,
  esp-idf,
}:

let
  # Common packages for all ESP32 shells
  commonPackages = with pkgs; [
    # Build tools
    cmake
    ninja
    gnumake
    gcc
    pkg-config

    # Python for ESP-IDF
    python3
    python3Packages.pip
    python3Packages.virtualenv

    # Utilities
    git
    curl
    wget

    # Rust tools
    cargo-generate
    rust-analyzer

    # ESP tools
    esp-generate
    espflash
  ];

  # Helper to make shell hooks
  makeShellHook = target: extraEnv: ''
    echo ""
    echo "=========================================="
    echo "ESP32 Development Shell - ${target}"
    echo "=========================================="
    echo ""
    echo "Toolchains available:"
    echo "  - Xtensa GCC: ${xtensa-esp32-elf}/bin/xtensa-esp32-elf-gcc"
    echo "  - Rust Xtensa: ${rust-xtensa}/bin/rustc"
    echo "  - LLVM: ${llvm-esp}/bin/clang"
    echo ""
    echo "ESP tools:"
    echo "  - esp-generate: Generate new ESP projects"
    echo "    Usage: esp-generate --chip <esp32|esp32s2|esp32s3> <project-name>"
    echo ""

    # Set up PATH
    export PATH="${rust-xtensa}/bin:${xtensa-esp32-elf}/bin:${llvm-esp}/bin:$HOME/.cargo/bin:$PATH"

    # Set up Rust paths
    export RUST_SRC_PATH="${rust-xtensa}/lib/rustlib/src/rust/library"
    export RUSTC_SYSROOT="${rust-xtensa}"

    # Set up LLVM
    export LLVM_ESP_PATH="${llvm-esp}"
    export LIBCLANG_PATH="${llvm-esp}/lib"

    # Target-specific linker settings
    ${extraEnv}
  '';

in
{
  # Default shell with all Xtensa targets
  default = pkgs.mkShell {
    name = "esp32-all-dev";
    buildInputs = commonPackages ++ [
      xtensa-esp32-elf
      llvm-esp
      rust-xtensa
    ];

    shellHook = makeShellHook "All Xtensa ESP32 Targets" ''
      export CARGO_TARGET_XTENSA_ESP32_NONE_ELF_LINKER="xtensa-esp32-elf-gcc"
      export CARGO_TARGET_XTENSA_ESP32S2_NONE_ELF_LINKER="xtensa-esp32s2-elf-gcc"
      export CARGO_TARGET_XTENSA_ESP32S3_NONE_ELF_LINKER="xtensa-esp32s3-elf-gcc"

      echo ""
      echo "Available Xtensa targets:"
      echo "  - xtensa-esp32-none-elf (ESP32 - Original)"
      echo "  - xtensa-esp32s2-none-elf (ESP32-S2 - Single core, WiFi only)"
      echo "  - xtensa-esp32s3-none-elf (ESP32-S3 - Dual core, WiFi + BLE)"
    '';
  };

  # Shell with ESP-IDF (for std development)
  std = pkgs.mkShell {
    name = "esp32-std-dev";
    buildInputs = commonPackages ++ [
      xtensa-esp32-elf
      llvm-esp
      rust-xtensa
      esp-idf
    ];

    shellHook = makeShellHook "ESP32 with ESP-IDF" ''
      export CARGO_TARGET_XTENSA_ESP32_NONE_ELF_LINKER="xtensa-esp32-elf-gcc"
      export CARGO_TARGET_XTENSA_ESP32S2_NONE_ELF_LINKER="xtensa-esp32s2-elf-gcc"
      export CARGO_TARGET_XTENSA_ESP32S3_NONE_ELF_LINKER="xtensa-esp32s3-elf-gcc"
      export IDF_PATH="${esp-idf}"
      echo "ESP-IDF std development ready!"
      echo "Supports: ESP32, ESP32-S2, ESP32-S3"
    '';
  };
}
