# COMPILATION GUIDE

## How to Use This Flake

This ESP32 flake is designed to work with the `espup` tool to manage toolchains. Here's how to compile a real ESP32 project:

### Prerequisites

1. Nix with flakes enabled
2. An ESP32 development board (ESP32-DevKitC, NodeMCU-32S, etc.)
3. USB cable

### Step-by-Step Instructions

#### 1. Enter the Development Shell

```bash
# Clone or navigate to this flake
cd /path/to/esp32-flake

# Enter the ESP32 development shell
nix develop .#esp32
```

#### 2. Install the Toolchain

```bash
# Install Xtensa toolchain for ESP32
espup install --targets esp32

# This will download and install:
# - Xtensa Rust toolchain
# - Xtensa GCC toolchain
# - ESP32 target support

# Source the environment
source $HOME/export-esp.sh
```

#### 3. Verify Installation

```bash
# Check that cargo can find the Xtensa target
cargo --version
rustc --print target-list | grep xtensa

# You should see:
# xtensa-esp32-none-elf
# xtensa-esp32s2-none-elf
# xtensa-esp32s3-none-elf
```

#### 4. Build the Example

```bash
cd example

# Build for release (required for no_std)
cargo build --release

# The binary will be at:
# target/xtensa-esp32-none-elf/release/esp32-example
```

#### 5. Flash to ESP32

```bash
# Connect your ESP32 board via USB

# Find the port (usually /dev/ttyUSB0 on Linux)
ls /dev/ttyUSB*

# Flash the binary
cargo espflash flash --release --monitor /dev/ttyUSB0

# Or manually:
espflash flash target/xtensa-esp32-none-elf/release/esp32-example --monitor
```

### Troubleshooting Compilation

#### Error: "linker `xtensa-esp32-elf-gcc` not found"

**Cause**: Toolchain not installed or not in PATH

**Solution**:
```bash
# Make sure you're in the nix shell
nix develop .#esp32

# Re-run espup install
espup install --targets esp32

# Source the export file
source $HOME/export-esp.sh

# Verify
which xtensa-esp32-elf-gcc
```

#### Error: "cannot find -lc" or linker errors

**Cause**: Missing libc for Xtensa

**Solution**: This is expected for `no_std`. Make sure your `.cargo/config.toml` has:
```toml
rustflags = [
    "-C", "link-arg=-nostartfiles",
]
```

#### Error: "unknown target triple 'xtensa-esp32-none-elf'"

**Cause**: Rust doesn't have Xtensa support

**Solution**: 
```bash
# Verify espup installed the toolchain
ls $HOME/.rustup/toolchains/esp/bin/rustc

# Make sure it's in PATH
export PATH="$HOME/.rustup/toolchains/esp/bin:$PATH"
```

#### Error: Permission denied on /dev/ttyUSB0

**Solution**:
```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER

# Log out and back in
```

### Understanding the Build Process

1. **Nix Shell**: Provides tools (cargo, espup, cmake, python)
2. **espup**: Installs Rust with Xtensa patches and GCC toolchains
3. **Cargo**: Builds the Rust code
4. **Linker**: xtensa-esp32-elf-gcc links the binary
5. **espflash**: Flashes the binary to the ESP32

### Creating Your Own Project

```bash
# In the nix shell
nix develop .#esp32

# Generate from template
cargo generate --git https://github.com/esp-rs/esp-template

# Follow prompts:
# - Project name: my-project
# - Target: esp32
# - Advanced options: Y (to customize)

# Build
cd my-project
cargo build --release
```

### Using Other ESP32 Variants

For ESP32-S3:
```bash
nix develop .#esp32s3
espup install --targets esp32s3
source $HOME/export-esp.sh
# Update .cargo/config.toml target to xtensa-esp32s3-none-elf
```

For ESP32-C3 (RISC-V):
```bash
nix develop .#esp32c3
# ESP32-C3 uses standard Rust! No espup needed for basic support
# But still useful for the GCC toolchain
espup install --targets esp32c3
source $HOME/export-esp.sh
# Target: riscv32imc-unknown-none-elf
```

### VSCode Integration

1. Install the "rust-analyzer" extension
2. In the nix shell, run:
   ```bash
   rust-analyzer --version
   ```
3. Open VSCode from the nix shell:
   ```bash
   code .
   ```

### Next Steps

1. Check that `nix develop` works
2. Verify `espup install` completes successfully
3. Build the example
4. Flash to a real ESP32 board
5. See the LED blink!

## Known Issues

1. **First-time setup**: Initial espup install takes several minutes (downloads ~500MB)
2. **macOS**: May need additional Xcode command line tools
3. **Windows WSL**: USB passthrough can be tricky, use Windows native or Linux directly

## Getting Help

- [ESP-RS Book](https://esp-rs.github.io/book/)
- [esp-hal documentation](https://docs.rs/esp-hal/)
- [Matrix chat: #esp-rs:matrix.org](https://matrix.to/#/#esp-rs:matrix.org)
