{
  pkgs,
  lib,
  xtensa-esp32-elf,
  riscv32-esp-elf,
  llvm-esp,
  rust-xtensa,
  esp-idf,
  espup,
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
    echo "  - RISC-V GCC: ${riscv32-esp-elf}/bin/riscv32-esp-elf-gcc"
    echo "  - Rust Xtensa: ${rust-xtensa}/bin/rustc"
    echo "  - LLVM: ${llvm-esp}/bin/clang"
    echo ""
    echo "ESP tools:"
    echo "  - esp-generate: Generate new ESP projects"
    echo "    Usage: esp-generate --chip <esp32|esp32s2|esp32s3|esp32c3|esp32c6|esp32h2> <project-name>"
    echo ""

    # Set up PATH
    export PATH="${rust-xtensa}/bin:${xtensa-esp32-elf}/bin:${riscv32-esp-elf}/bin:${llvm-esp}/bin:$HOME/.cargo/bin:$PATH"

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
  # ESP32 (Xtensa LX6)
  esp32 = pkgs.mkShell {
    name = "esp32-dev";

    buildInputs = commonPackages ++ [
      xtensa-esp32-elf
      riscv32-esp-elf
      llvm-esp
      rust-xtensa
    ];

    shellHook = makeShellHook "ESP32" ''
      export CARGO_TARGET_XTENSA_ESP32_NONE_ELF_LINKER="xtensa-esp32-elf-gcc"
      export CC_XTENSA_ESP32_NONE_ELF="xtensa-esp32-elf-gcc"
      export AR_XTENSA_ESP32_NONE_ELF="xtensa-esp32-elf-ar"

      echo "Target: xtensa-esp32-none-elf"
      echo "Ready to build!"
    '';
  };

  # All other targets can use the esp32 shell since we have all toolchains
  # Just providing aliases for convenience
  esp32s2 = pkgs.mkShell {
    name = "esp32s2-dev";
    buildInputs = commonPackages ++ [
      xtensa-esp32-elf
      riscv32-esp-elf
      llvm-esp
      rust-xtensa
    ];
    shellHook = makeShellHook "ESP32-S2" ''
      export CARGO_TARGET_XTENSA_ESP32S2_NONE_ELF_LINKER="xtensa-esp32s2-elf-gcc"
      echo "Target: xtensa-esp32s2-none-elf"
    '';
  };

  esp32s3 = pkgs.mkShell {
    name = "esp32s3-dev";
    buildInputs = commonPackages ++ [
      xtensa-esp32-elf
      riscv32-esp-elf
      llvm-esp
      rust-xtensa
    ];
    shellHook = makeShellHook "ESP32-S3" ''
      export CARGO_TARGET_XTENSA_ESP32S3_NONE_ELF_LINKER="xtensa-esp32s3-elf-gcc"
      echo "Target: xtensa-esp32s3-none-elf"
    '';
  };

  esp32c3 = pkgs.mkShell {
    name = "esp32c3-dev";
    buildInputs = commonPackages ++ [
      xtensa-esp32-elf
      riscv32-esp-elf
      llvm-esp
      rust-xtensa
    ];
    shellHook = makeShellHook "ESP32-C3" ''
      export CARGO_TARGET_RISCV32IMC_UNKNOWN_NONE_ELF_LINKER="riscv32-esp-elf-gcc"
      echo "Target: riscv32imc-unknown-none-elf"
    '';
  };

  esp32c6 = pkgs.mkShell {
    name = "esp32c6-dev";
    buildInputs = commonPackages ++ [
      xtensa-esp32-elf
      riscv32-esp-elf
      llvm-esp
      rust-xtensa
    ];
    shellHook = makeShellHook "ESP32-C6" ''
      export CARGO_TARGET_RISCV32IMAC_UNKNOWN_NONE_ELF_LINKER="riscv32-esp-elf-gcc"
      echo "Target: riscv32imac-unknown-none-elf"
    '';
  };

  esp32h2 = pkgs.mkShell {
    name = "esp32h2-dev";
    buildInputs = commonPackages ++ [
      xtensa-esp32-elf
      riscv32-esp-elf
      llvm-esp
      rust-xtensa
    ];
    shellHook = makeShellHook "ESP32-H2" ''
      export CARGO_TARGET_RISCV32IMAC_UNKNOWN_NONE_ELF_LINKER="riscv32-esp-elf-gcc"
      echo "Target: riscv32imac-unknown-none-elf"
    '';
  };

  # Default shell with all targets
  default = pkgs.mkShell {
    name = "esp32-all-dev";
    buildInputs = commonPackages ++ [
      xtensa-esp32-elf
      riscv32-esp-elf
      llvm-esp
      rust-xtensa
    ];

    shellHook = makeShellHook "All ESP32 Targets" ''
      export CARGO_TARGET_XTENSA_ESP32_NONE_ELF_LINKER="xtensa-esp32-elf-gcc"
      export CARGO_TARGET_XTENSA_ESP32S2_NONE_ELF_LINKER="xtensa-esp32s2-elf-gcc"
      export CARGO_TARGET_XTENSA_ESP32S3_NONE_ELF_LINKER="xtensa-esp32s3-elf-gcc"
      export CARGO_TARGET_RISCV32IMC_UNKNOWN_NONE_ELF_LINKER="riscv32-esp-elf-gcc"
      export CARGO_TARGET_RISCV32IMAC_UNKNOWN_NONE_ELF_LINKER="riscv32-esp-elf-gcc"

      echo ""
      echo "Available targets:"
      echo "  - xtensa-esp32-none-elf (ESP32)"
      echo "  - xtensa-esp32s2-none-elf (ESP32-S2)"
      echo "  - xtensa-esp32s3-none-elf (ESP32-S3)"
      echo "  - riscv32imc-unknown-none-elf (ESP32-C3)"
      echo "  - riscv32imac-unknown-none-elf (ESP32-C6, ESP32-H2)"
    '';
  };

  # Shell with ESP-IDF (for std development)
  std = pkgs.mkShell {
    name = "esp32-std-dev";
    buildInputs = commonPackages ++ [
      xtensa-esp32-elf
      riscv32-esp-elf
      llvm-esp
      rust-xtensa
      esp-idf
    ];

    shellHook = makeShellHook "ESP32 with ESP-IDF" ''
      export CARGO_TARGET_XTENSA_ESP32_NONE_ELF_LINKER="xtensa-esp32-elf-gcc"
      export CARGO_TARGET_XTENSA_ESP32S2_NONE_ELF_LINKER="xtensa-esp32s2-elf-gcc"
      export CARGO_TARGET_XTENSA_ESP32S3_NONE_ELF_LINKER="xtensa-esp32s3-elf-gcc"
      export CARGO_TARGET_RISCV32IMC_UNKNOWN_NONE_ELF_LINKER="riscv32-esp-elf-gcc"
      export CARGO_TARGET_RISCV32IMAC_UNKNOWN_NONE_ELF_LINKER="riscv32-esp-elf-gcc"
      export IDF_PATH="${esp-idf}"
      echo "ESP-IDF std development ready!"
    '';
  };
}
