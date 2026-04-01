{
  description = "ESP32 Rust toolchain and development environment for Nix - Inspired by fenix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      inherit (nixpkgs) lib;

      # Supported systems
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

    in
    flake-utils.lib.eachSystem systems (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        # Build ESP toolchain (fenix-inspired design)
        esp-toolchain = import ./lib {
          inherit pkgs lib;
          manifestFile = ./data/esp32.json;
        };
      in
      {
        # Packages - Rust toolchain components and standalone tools
        packages = {
          inherit (esp-toolchain)
            rust rust-src
            minimal default complete
            toolchain
            xtensa-gcc
            ;
        };

        # Development shells
        devShells = {
          inherit (esp-toolchain.shells) default std;
        };

        # Legacy attributes
        legacyPackages = self.packages.${system};
      }
    )
    // {
      # Overlay
      overlays.default = final: prev: {
        esp-rs = import ./lib {
          inherit (final) pkgs lib;
          manifestFile = ./data/esp32.json;
        };
      };

      # Library
      lib = {
        mkToolchain = import ./lib/mk-toolchain.nix;
      };
    };
}
