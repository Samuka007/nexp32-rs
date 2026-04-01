{
  description = "ESP32 Rust toolchain and development environment for Nix - Pure Nix implementation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      inherit (nixpkgs) lib;
      
      # Supported systems
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      
      # Import the library
      mkLib = pkgs: import ./lib { inherit pkgs lib; };
      
    in
    flake-utils.lib.eachSystem systems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        esp-lib = mkLib pkgs;
      in
      {
        # Packages - All toolchains as pure Nix packages
        packages = {
          # GCC Toolchains
          xtensa-esp32-elf = esp-lib.xtensa-esp32-elf;
          riscv32-esp-elf = esp-lib.riscv32-esp-elf;
          
          # LLVM/Clang with Xtensa support
          llvm-esp = esp-lib.llvm-esp;
          
          # Rust with Xtensa support
          rust-xtensa = esp-lib.rust-xtensa;
          
          # ESP-IDF
          esp-idf = esp-lib.esp-idf;
          
          # Combined toolchain
          default = esp-lib.complete-toolchain;
          minimal = esp-lib.minimal-toolchain;
        };
        
        # Development shells
        devShells = {
          esp32 = esp-lib.shells.esp32;
          esp32s2 = esp-lib.shells.esp32s2;
          esp32s3 = esp-lib.shells.esp32s3;
          esp32c3 = esp-lib.shells.esp32c3;
          esp32c6 = esp-lib.shells.esp32c6;
          esp32h2 = esp-lib.shells.esp32h2;
          default = esp-lib.shells.default;
          std = esp-lib.shells.std;
        };
        
        # Apps
        apps = {
          default = {
            type = "app";
            program = "${esp-lib.rust-xtensa}/bin/cargo";
          };
        };
        
        # Legacy attributes
        legacyPackages = self.packages.${system};
      }
    ) // {
      # Overlay
      overlays = {
        default = final: prev: {
          esp-rs = mkLib final;
        };
      };
      
      # Module for NixOS/home-manager
      nixosModules.default = import ./module.nix;
      homeManagerModules.default = import ./module.nix;
      
      # Library functions
      lib = {
        inherit mkLib;
      };
    };
}
