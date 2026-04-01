# TTGO ESP32 Rust Examples

Rust implementations of TTGO T-Display example projects, ported from Arduino to modern Rust embedded stack using [esp-hal](https://github.com/esp-rs/esp-hal).

## Overview

This directory contains Rust reimplementations of example projects for the **TTGO T-Display** ESP32 development board. The examples demonstrate various peripherals and features using the modern `no_std` Rust embedded ecosystem.

### Original Arduino Examples

The original Arduino examples are preserved in the `../lab/` directory:
- `ttgo_gps.ino` - GPS module reader
- `ttgo_webserver.ino` - WiFi AP with web server  
- `ttgo_chatterbox/` - Chat server over WiFi

## Examples

### Basic Examples

| Example | Description | Hardware |
|---------|-------------|----------|
| `hello_world` | Basic project template with esp-hal | - |
| `ttgo_blink` | LED blinking on GPIO 2 | Onboard LED |
| `ttgo_rgb` | Color pattern simulation using LED blink patterns | Onboard LED |
| `ttgo_button` | Button input handling with LED control | BOOT (GPIO 0) + User (GPIO 35) buttons |

### Advanced Examples

| Example | Description | Hardware | Stack |
|---------|-------------|----------|-------|
| `ttgo_gps` | GPS NMEA parser with AXP192 power management | GPS Module (UART + I2C) | - |
| `ttgo_chatterbox` | Chat server | WiFi | smoltcp (manual HTTP) |
| `ttgo_chatterbox2` | Chat server | WiFi | embassy-net + picoserve |

## Quick Start

This flake provides **pure Nix** Xtensa toolchains - no `espup` required!

```bash
# Enter development shell (from repo root)
cd ..
nix develop .#esp32

# Build examples
cargo build --release

# Flash specific example
cargo espflash flash --release -p ttgo_blink --monitor
```

### Supported Targets

This fork focuses on **Xtensa-based ESP32 chips**:

- `xtensa-esp32-none-elf` - ESP32 (Original)
- `xtensa-esp32s2-none-elf` - ESP32-S2 (Single-core, WiFi only)
- `xtensa-esp32s3-none-elf` - ESP32-S3 (Dual-core, WiFi + BLE, AI acceleration)

*Note: RISC-V based ESP32-C3/C6/H2/P4 are not supported in this fork.*

## Example Details

### ttgo_blink

Basic LED blinking example demonstrating GPIO output.

```bash
cargo run --release -p ttgo_blink
```

### ttgo_button

Two-button input example:
- **BOOT button (GPIO 0)**: Speed up LED blinking
- **User button (GPIO 35)**: Slow down LED blinking

### ttgo_gps

GPS reader with:
- UART communication (GPIO 34/12 at 9600 baud)
- AXP192 power management via I2C (GPIO 21/22)
- NMEA sentence parsing (GGA and VTG)

Output format:
```
Latitude  : 39.9042
Longitude : 116.4074
Satellites: 8
Altitude  : 45.2 M
Time      : 12:34:56
Speed     : 5.3 kmph
```

### ttgo_chatterbox

WiFi AP chat server using **smoltcp**:
- SSID: `ChatBox-00110577`
- IP: `192.168.1.1`
- Manual HTTP request parsing
- In-memory message storage (50 messages max)

### ttgo_chatterbox2

Modern async chat server using **embassy-net + picoserve**:
- Same functionality as ttgo_chatterbox
- Clean async/await syntax
- Type-safe HTTP routing with picoserve
- Multiple concurrent connections (8 worker tasks)

**Architecture:**
```
embassy-executor (async runtime)
    └── embassy-net (TCP/IP stack)
            └── picoserve (HTTP server framework)
                    └── Your route handlers
```

## Hardware Requirements

### TTGO T-Display Pinout

| Pin | Function | Description |
|-----|----------|-------------|
| GPIO 0 | BOOT button | Active low |
| GPIO 2 | Onboard LED | Active high |
| GPIO 21 | I2C SDA | AXP192, display |
| GPIO 22 | I2C SCL | AXP192, display |
| GPIO 34 | UART RX | GPS module |
| GPIO 12 | UART TX | GPS module |
| GPIO 35 | User button | Active low |

### GPS Module Connection (for ttgo_gps)

| TTGO | GPS Module |
|------|-----------|
| 3.3V | VCC |
| GND  | GND |
| GPIO 34 | TX |
| GPIO 12 | RX |

## Technology Stack

### Core Dependencies

- **[esp-hal](https://github.com/esp-rs/esp-hal)** (~1.0) - Hardware abstraction layer
- **[esp-println](https://github.com/esp-rs/esp-println)** (0.13) - Debug output
- **[esp-bootloader-esp-idf](https://github.com/esp-rs/esp-bootloader-esp-idf)** (0.4) - Bootloader support

### Network Stacks

- **ttgo_chatterbox**: [smoltcp](https://github.com/smoltcp-rs/smoltcp) (0.12) - Manual TCP/IP
- **ttgo_chatterbox2**: 
  - [embassy-net](https://github.com/embassy-rs/embassy) (0.8) - Async TCP/IP
  - [picoserve](https://github.com/sammhicks/picoserve) (0.18) - HTTP framework
  - [embassy-executor](https://github.com/embassy-rs/embassy) (0.9) - Async runtime

## Build Configuration

### Target

All examples target `xtensa-esp32-none-elf`:

```toml
# .cargo/config.toml
[build]
target = "xtensa-esp32-none-elf"

[unstable]
build-std = ["core", "alloc"]
```

### Features

Most examples use:
- `esp-hal/unstable` - Required for current API
- `esp32` - Target chip

## Troubleshooting

### Build Errors

**"can't find crate for `test`"**
- Expected in `no_std` environments
- Use `cargo build --release` instead of `cargo check`

**Permission denied when flashing**
```bash
sudo usermod -a -G dialout $USER
# Log out and back in
```

### Runtime Issues

**WiFi examples not connecting**
- Check that WiFi AP is created (search for SSID on phone/laptop)
- Ensure stable 3.3V power supply

**GPS not working**
- AXP192 must be initialized to power GPS module
- Check UART baudrate (9600 default)

## Resources

- [esp-rs Documentation](https://docs.esp-rs.org/)
- [esp-hal Examples](https://github.com/esp-rs/esp-hal/tree/main/examples)
- [Rust on ESP Book](https://docs.esp-rs.org/book/)
- [TTGO T-Display Schematic](https://github.com/Xinyuan-LilyGO/TTGO-T-Display)

## License

MIT OR Apache-2.0

## Acknowledgments

- [esp-rs](https://github.com/esp-rs) - Rust on ESP team
- [esp-hal](https://github.com/esp-rs/esp-hal) contributors
- Original Arduino examples from TTGO community
