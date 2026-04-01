# Overlay for nixpkgs
# Usage:
#   nixpkgs.overlays = [ (import /path/to/esp32-flake/overlay.nix) ];

final: prev:

let
  esp-lib = import ./lib { 
    pkgs = final; 
    lib = final.lib; 
  };
in
{
  # ESP32 toolchain packages
  esp32-toolchain = esp-lib.xtensa-esp32-elf;
  esp32s2-toolchain = esp-lib.xtensa-esp32-elf;
  esp32s3-toolchain = esp-lib.xtensa-esp32-elf;
  riscv32-esp-elf = esp-lib.riscv32-esp-elf;
  llvm-esp = esp-lib.llvm-esp;
  espup = esp-lib.espup;
  esp-idf = esp-lib.esp-idf;
  rust-xtensa = esp-lib.rust-xtensa;
  
  # Combined toolchains
  esp32-complete-toolchain = esp-lib.complete-toolchain;
  esp32-minimal-toolchain = esp-lib.minimal-toolchain;
  
  # Aliases for convenience
  inherit (esp-lib) 
    complete-toolchain
    minimal-toolchain
    esp32-toolchain
    esp32s2-toolchain
    esp32s3-toolchain
    esp32c3-toolchain
    esp32c6-toolchain
    esp32h2-toolchain
    esp32p4-toolchain
  ;
  
  # Development shells are available through the flake
  esp32-devShells = esp-lib.shells;
}
