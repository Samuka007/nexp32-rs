# ESP32 Flake

A Nix flake providing ESP32 Rust development environment, inspired by [nix-community/fenix](https://github.com/nix-community/fenix).

This flake provides **pure Nix** development shells and tools for ESP32 development using Rust. Unlike other approaches, this flake bundles the toolchains directly as Nix packages - no `espup` required!

## Features

- **Pure Nix toolchains** - No external downloads or `espup` needed
- **Xtensa support** - Full LLVM and Rust support for ESP32 (Xtensa LX6/LX7)
- **RISC-V support** - ESP32-C3, ESP32-C6, ESP32-H2, ESP32-P4
- **ESP-IDF support** - For `std` development
- **Multiple dev shells** - Target-specific environments
- **NixOS/Home Manager modules** - System-wide configuration

## Quick Start

```bash
# Enter development shell for ESP32
nix develop .#esp32

# All tools are ready:
cargo build --release
espflash flash target/xtensa-esp32-none-elf/release/myapp --monitor
```

## Available Shells

| Shell | Target | Architecture | Features |
|-------|--------|--------------|----------|
| `esp32` | ESP32 | Xtensa LX6 | WiFi + BLE, Dual-core |
| `esp32s2` | ESP32-S2 | Xtensa LX7 | WiFi only, Single-core |
| `esp32s3` | ESP32-S3 | Xtensa LX7 + SIMD | WiFi + BLE, Dual-core, AI acceleration |
| `default` | All Xtensa targets | - | - |
| `std` | All Xtensa + ESP-IDF | - | std support |

## What's Included

Each shell provides:

- **Rust toolchain** with Xtensa/RISC-V support
- **GCC toolchain** (`xtensa-esp32-elf-gcc` or `riscv32-esp-elf-gcc`)
- **LLVM/Clang** with Xtensa patches
- **espflash** - Flashing tool
- **ldproxy** - Linker proxy for ESP-IDF
- **cargo-espflash** - Cargo integration (in std shell)

## Usage

### Using in your project

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    esp32-flake.url = "github:yourusername/esp32-flake";
  };

  outputs = { self, nixpkgs, esp32-flake }:
    let
      system = "x86_64-linux";
    in
    {
      devShells.${system}.default = esp32-flake.devShells.${system}.esp32;
    };
}
```

### Using as an overlay

```nix
# configuration.nix
{ pkgs, ... }: {
  nixpkgs.overlays = [
    (import /path/to/esp32-flake/overlay.nix)
  ];
  
  environment.systemPackages = with pkgs; [
    esp-rs.xtensa-esp32-elf
    esp-rs.rust-xtensa
  ];
}
```

### Using the NixOS module

```nix
# configuration.nix
{ pkgs, ... }: {
  imports = [ /path/to/esp32-flake/module.nix ];
  
  programs.esp-rs = {
    enable = true;
    targets = [ "esp32" "esp32c3" ];
  };
}
```

## Creating a New Project

### no_std Project

```bash
nix develop .#esp32
cargo generate --git https://github.com/esp-rs/esp-template
cargo build --release
```

### std Project (with ESP-IDF)

```bash
nix develop .#std
cargo generate --git https://github.com/esp-rs/esp-idf-template cargo
cargo build
```

## Examples

See the `example/` directory for sample projects demonstrating various ESP32 features.

## How It Works

This flake builds ESP32 toolchains from source as pure Nix packages:

1. **GCC Toolchains** - Built from Espressif's GCC forks
2. **LLVM** - Built with Xtensa backend patches
3. **Rust** - Built with Xtensa target support

All toolchains are cached in the Nix store and managed by Nix.

## Troubleshooting

### "Permission denied" when flashing

Add your user to the `dialout` group:

```bash
sudo usermod -a -G dialout $USER
# Log out and back in
```

### Port not found

Check available ports:

```bash
ls -la /dev/ttyUSB*  # or /dev/ttyACM*
```

### Build fails with linker errors

Ensure you're using the correct shell for your target:

```bash
nix develop .#esp32   # For ESP32 (Xtensa)
nix develop .#esp32c3 # For ESP32-C3 (RISC-V)
```

## Supported Platforms

- x86_64-linux
- aarch64-linux
- x86_64-darwin
- aarch64-darwin

## License

MIT OR Apache-2.0

## Acknowledgments

- [esp-rs](https://github.com/esp-rs) - ESP32 Rust ecosystem
- [fenix](https://github.com/nix-community/fenix) - Inspiration for flake structure
- [espressif](https://github.com/espressif) - ESP32 toolchains and ESP-IDF
