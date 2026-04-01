#!/usr/bin/env bash
# Script to setup ESP32 toolchain using espup
# This is called from the devShell to ensure toolchains are available

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up ESP32 Rust toolchain...${NC}"

# Check if toolchains are already installed
XTENSA_DIR="$HOME/.rustup/toolchains/esp/xtensa-esp-elf"
if [ -d "$XTENSA_DIR" ]; then
    echo -e "${GREEN}Xtensa toolchain already installed at: $XTENSA_DIR${NC}"
else
    echo -e "${YELLOW}Xtensa toolchain not found. Installing via espup...${NC}"
    
    # Install using espup
    if command -v espup >/dev/null 2>>1; then
        espup install --targets esp32,esp32s2,esp32s3,esp32c2,esp32c3,esp32c6
    else
        echo -e "${RED}Error: espup not found in PATH${NC}"
        echo "Please ensure you're in the correct nix shell"
        exit 1
    fi
fi

# Source the export file if it exists
EXPORT_FILE="$HOME/export-esp.sh"
if [ -f "$EXPORT_FILE" ]; then
    echo -e "${GREEN}Sourcing environment from $EXPORT_FILE${NC}"
    source "$EXPORT_FILE"
else
    echo -e "${YELLOW}Warning: Export file not found at $EXPORT_FILE${NC}"
    echo "You may need to run: espup install"
fi

# Setup cargo environment
echo -e "${GREEN}ESP32 toolchain setup complete!${NC}"
echo ""
echo "Available targets:"
rustup target list --installed 2>/dev/null | grep -E "xtensa|riscv32" || echo "  (No ESP32 targets installed yet)"
