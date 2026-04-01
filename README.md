# ESP32 Flake

A Nix flake providing ESP32 Rust development environment, inspired by [nix-community/fenix](https://github.com/nix-community/fenix).

This flake provides development shells and tools for ESP32 development using Rust. **Note**: Due to the size and licensing of pre-built toolchains, this flake uses `espup` to manage toolchains rather than bundling them directly.

## Features

- **Development shells** for all ESP32 variants (Xtensa and RISC-V)
- **espup integration** for easy toolchain management
- **ESP-IDF support** for std development
- **Example project** included
- **NixOS/Home Manager modules** for system-wide configuration

## Quick Start

### 1. Enter Development Shell

```bash
# For ESP32 (original Xtensa-based)
nix develop .#esp32

# For ESP32-S3
nix develop .#esp32s3

# For ESP32-C3 (RISC-V based)
nix develop .#esp32c3

# All targets
nix develop
```

### 2. Install Toolchains

```bash
# Install toolchains for your target
espup install --targets esp32

# Or install all targets
espup install --targets all

# Source the environment
source $HOME/export-esp.sh
```

### 3. Build Example

```bash
cd example
cargo build --release
```

## Project Structure

```
esp32-flake/
├── flake.nix           # Main flake entry point
├── lib/                # Library functions and package definitions
│   ├── shells.nix      # Development shells
│   └── ...
├── example/            # Example ESP32 project
│   ├── Cargo.toml
│   ├── src/main.rs
│   └── .cargo/config.toml
├── overlay.nix         # Nixpkgs overlay
├── module.nix          # NixOS module
└── README.md
```

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
    espup
    esp-idf
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
    installEspIdf = true;
    installEspup = true;
  };
}
```

## Available Development Shells

| Shell | Target | Architecture |
|-------|--------|--------------|
| `esp32` | ESP32 | Xtensa LX6 |
| `esp32s2` | ESP32-S2 | Xtensa LX7 |
| `esp32s3` | ESP32-S3 | Xtensa LX7 + SIMD |
| `esp32c3` | ESP32-C3 | RISC-V RV32IMC |
| `esp32c6` | ESP32-C6 | RISC-V RV32IMAC |
| `esp32h2` | ESP32-H2 | RISC-V RV32IMAC |
| `esp32p4` | ESP32-P4 | RISC-V RV32IMACF |
| `default` | All targets | - |
| `std` | All targets + ESP-IDF | - |

## Creating a New Project

### no_std Project

```bash
# Enter the ESP32 shell
nix develop .#esp32

# Install toolchains
espup install --targets esp32
source $HOME/export-esp.sh

# Create project from template
cargo generate --git https://github.com/esp-rs/esp-template

# Build
cargo build --release

# Flash
cargo espflash flash --release --monitor
```

### std Project (with ESP-IDF)

```bash
# Enter std shell
nix develop .#std

# Install toolchains
espup install --targets esp32
source $HOME/export-esp.sh

# Create project
cargo generate --git https://github.com/esp-rs/esp-idf-template cargo

# Build and flash
cargo espflash flash --monitor
```

## Toolchain Management

### Installing espup

```bash
nix run github:yourusername/esp32-flake
```

### Updating toolchains

```bash
espup update
```

### Uninstalling toolchains

```bash
espup uninstall
```

## Example Project

The included example (`example/`) is a minimal blink LED program for ESP32:

```bash
nix develop .#esp32
espup install --targets esp32
source $HOME/export-esp.sh
cd example
cargo build --release
```

## Configuration Files

### `.cargo/config.toml`

```toml
[build]
target = "xtensa-esp32-none-elf"

[target.xtensa-esp32-none-elf]
linker = "xtensa-esp32-elf-gcc"
rustflags = [
    "-C", "link-arg=-Wl,-Tlinkall.x",
    "-C", "link-arg=-nostartfiles",
]

[unstable]
build-std = ["core"]
```

### `rust-toolchain.toml`

```toml
[toolchain]
channel = "nightly"
components = ["rust-src", "rustfmt", "clippy"]
```

## Troubleshooting

### "xtensa-esp32-elf-gcc not found"

Make sure you've run:
1. `espup install --targets esp32`
2. `source $HOME/export-esp.sh`

### "Permission denied" when flashing

Add your user to the `dialout` group:

```bash
sudo usermod -a -G dialout $USER
# Log out and back in
```

### Port not found

Check available ports:

```bash
ls -la /dev/ttyUSB*
# or
ls -la /dev/ttyACM*
```

### Wrong flash size

Specify when flashing:

```bash
cargo espflash flash --release --flash-size 4MB
```

## Supported Platforms

- x86_64-linux
- aarch64-linux
- x86_64-darwin
- aarch64-darwin

## How It Works

This flake follows the pattern established by [fenix](https://github.com/nix-community/fenix):

1. **Development shells** provide the environment and tools
2. **espup** manages toolchain installation (like rustup)
3. **Toolchains** are installed to `~/.rustup/toolchains/esp/`
4. **Environment** is set up via `$HOME/export-esp.sh`

Unlike fenix, which can redistribute Rust binaries, ESP32 toolchains are:
- Large (hundreds of MB each)
- Have specific licensing requirements
- Frequently updated

Therefore, this flake uses `espup` to fetch and install them on-demand.

## Future Enhancements

- [ ] Binary cache with pre-built toolchains (if licensing allows)
- [ ] Integration with devenv for easier project setup
- [ ] Automated CI/CD testing
- [ ] More example projects

## Acknowledgments

- [esp-rs](https://github.com/esp-rs) - ESP32 Rust ecosystem
- [fenix](https://github.com/nix-community/fenix) - Inspiration for this flake structure
- [espressif](https://github.com/espressif) - ESP32 toolchains and ESP-IDF

## License

MIT OR Apache-2.0
