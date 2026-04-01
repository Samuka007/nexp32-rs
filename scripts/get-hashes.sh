#!/usr/bin/env bash
# Script to fetch SHA256 hashes for ESP32 toolchains
# Run this with: bash get-hashes.sh

set -e

echo "Fetching SHA256 hashes for ESP32 toolchains..."
echo ""

# Detect system
SYSTEM=$(uname -m)-$(uname -s | tr '[:upper:]' '[:lower:]')

# Map to toolchain naming
if [[ "$SYSTEM" == "x86_64-linux" ]]; then
    PLATFORM="x86_64-linux-gnu"
elif [[ "$SYSTEM" == "aarch64-linux" ]]; then
    PLATFORM="aarch64-linux-gnu"
elif [[ "$SYSTEM" == "x86_64-darwin" ]]; then
    PLATFORM="x86_64-apple-darwin"
elif [[ "$SYSTEM" == "arm64-darwin" ]]; then
    PLATFORM="aarch64-apple-darwin"
else
    echo "Unsupported system: $SYSTEM"
    exit 1
fi

echo "Detected platform: $PLATFORM"
echo ""

# Toolchain versions
CTNG_VERSION="esp-13.2.0_20240530"
LLVM_VERSION="esp-17.0.1_20240419"
RUST_VERSION="1.79.0.0"

# Function to fetch hash
fetch_hash() {
    local url=$1
    local name=$2
    
    echo "Fetching $name..."
    echo "URL: $url"
    
    if command -v nix-prefetch-url >/dev/null 2>>1; then
        # Using nix-prefetch-url
        local hash=$(nix-prefetch-url "$url" 2>&1 | grep -E "^[a-z0-9]{52}$" || true)
        if [ -n "$hash" ]; then
            echo "SHA256: sha256-$hash"
        else
            echo "Failed to get hash via nix-prefetch-url"
        fi
    elif command -v curl >/dev/null 2>>1; then
        # Fallback: download and compute sha256
        echo "Downloading to compute hash (this may take a while)..."
        local tmpfile=$(mktemp)
        curl -L -o "$tmpfile" "$url" 2>&1 | tail -1
        
        if command -v sha256sum >/dev/null 2>>1; then
            local hash=$(sha256sum "$tmpfile" | cut -d' ' -f1)
            echo "SHA256: sha256-$(echo $hash | xxd -r -p | base64)"
        elif command -v shasum >/dev/null 2>>1; then
            local hash=$(shasum -a 256 "$tmpfile" | cut -d' ' -f1)
            echo "SHA256: sha256-$(echo $hash | xxd -r -p | base64)"
        fi
        
        rm -f "$tmpfile"
    else
        echo "Error: Neither nix-prefetch-url nor curl available"
        exit 1
    fi
    echo ""
}

# Xtensa GCC toolchain
XTENSA_URL="https://github.com/espressif/crosstool-NG/releases/download/${CTNG_VERSION}/xtensa-esp-elf-${CTNG_VERSION}-${PLATFORM}.tar.xz"
fetch_hash "$XTENSA_URL" "Xtensa GCC Toolchain"

# RISC-V GCC toolchain
RISCV_URL="https://github.com/espressif/crosstool-NG/releases/download/${CTNG_VERSION}/riscv32-esp-elf-${CTNG_VERSION}-${PLATFORM}.tar.xz"
fetch_hash "$RISCV_URL" "RISC-V GCC Toolchain"

# LLVM with Xtensa support
LLVM_URL="https://github.com/espressif/llvm-project/releases/download/${LLVM_VERSION}/llvm-${LLVM_VERSION}-${PLATFORM}.tar.xz"
fetch_hash "$LLVM_URL" "LLVM ESP"

# Rust with Xtensa support
RUST_URL="https://github.com/esp-rs/rust-build/releases/download/v${RUST_VERSION}/rust-${RUST_VERSION}-${PLATFORM}.tar.xz"
fetch_hash "$RUST_URL" "Rust Xtensa"

echo "================================"
echo "Hash fetching complete!"
echo "================================"
echo ""
echo "Now update lib/default.nix with these hashes"
