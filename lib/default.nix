{ pkgs, lib }:

let
  # Toolchain versions with correct hashes
  toolchains = {
    x86_64-linux = {
      xtensa = {
        version = "esp-14.2.0_20260121";
        url = "https://github.com/espressif/crosstool-NG/releases/download/esp-14.2.0_20260121/xtensa-esp-elf-14.2.0_20260121-x86_64-linux-gnu.tar.xz";
        sha256 = "sha256-2jHzbXnU6Z8k5VqQpx5l1WlHFPFhmZYL94hXJLcGpIw=";
      };
      riscv = {
        version = "esp-14.2.0_20260121";
        url = "https://github.com/espressif/crosstool-NG/releases/download/esp-14.2.0_20260121/riscv32-esp-elf-14.2.0_20260121-x86_64-linux-gnu.tar.xz";
        sha256 = "sha256-s/zksE3RWp8O0cIJtaLzicBO/5LtheTMDrwnW32V6Vo=";
      };
      llvm = {
        version = "esp-21.1.3_20260304";
        url = "https://github.com/espressif/llvm-project/releases/download/esp-21.1.3_20260304/clang-esp-21.1.3_20260304-x86_64-linux-gnu.tar.xz";
        sha256 = "sha256-IPyu9+AhXl+d9TI4rTSKtmlwJ7O5UtMAxVgNunrITMU=";
      };
      rust = {
        version = "1.94.0.2";
        url = "https://github.com/esp-rs/rust-build/releases/download/v1.94.0.2/rust-1.94.0.2-x86_64-unknown-linux-gnu.tar.xz";
        sha256 = "sha256-bOG2jBJtHuDBfUWejEg7kXaAAfzpzCz4lfbGiMMmKxU=";
      };
      rust-src = {
        version = "1.94.0.2";
        url = "https://github.com/esp-rs/rust-build/releases/download/v1.94.0.2/rust-src-1.94.0.2.tar.xz";
        sha256 = "sha256-A8J1ScXW8c39Tw/6KKYsC6+XnCgkGewSGnfxttKxz4c=";
      };
    };
  };

  currentSystem = pkgs.stdenv.hostPlatform.system;
  currentToolchains = toolchains.${currentSystem} or (throw "Unsupported system: ${currentSystem}");

  # Helper to patch ELF binaries for NixOS
  patchToolchain =
    name: src: installPhase:
    pkgs.stdenv.mkDerivation {
      inherit name src;

      nativeBuildInputs = [
        pkgs.xz
        pkgs.patchelf
      ];

      buildInputs = [
        pkgs.stdenv.cc.cc.lib
        pkgs.zlib
        pkgs.glib
      ];

      dontConfigure = true;
      dontBuild = true;
      dontPatchELF = false;
      dontStrip = true;

      inherit installPhase;

      # Manual patchelf after install to fix rpath for all binaries
      postFixup = ''
        # Fix all ELF binaries in bin directories
        for dir in $out/bin $out/libexec $out/xtensa-esp-elf/bin; do
          if [ -d "$dir" ]; then
            for file in $(find "$dir" -type f 2>/dev/null); do
              ${pkgs.patchelf}/bin/patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file" 2>/dev/null || true
              ${pkgs.patchelf}/bin/patchelf --set-rpath "$out/lib:${pkgs.stdenv.cc.cc.lib}/lib" "$file" 2>/dev/null || true
            done
          fi
        done

        # Fix shared libraries
        for file in $(find $out/lib -name "*.so*" -type f 2>/dev/null); do
          ${pkgs.patchelf}/bin/patchelf --set-rpath "$out/lib:${pkgs.stdenv.cc.cc.lib}/lib" "$file" 2>/dev/null || true
        done
      '';

      meta = {
        description = "ESP32 ${name} toolchain";
        platforms = [ "x86_64-linux" ];
      };
    };

in
rec {
  # ============ Toolchain Packages ============

  xtensa-esp32-elf =
    patchToolchain "xtensa-esp32-elf"
      (pkgs.fetchurl {
        url = currentToolchains.xtensa.url;
        sha256 = currentToolchains.xtensa.sha256;
      })
      ''
        mkdir -p $out
        # source root is already xtensa-esp-elf/, copy everything
        cp -r . $out/
        chmod -R +x $out/bin/ 2>/dev/null || true
      '';

  riscv32-esp-elf =
    patchToolchain "riscv32-esp-elf"
      (pkgs.fetchurl {
        url = currentToolchains.riscv.url;
        sha256 = currentToolchains.riscv.sha256;
      })
      ''
        mkdir -p $out
        # source root is already riscv32-esp-elf/, copy everything
        cp -r . $out/
        chmod -R +x $out/bin/ 2>/dev/null || true
      '';

  llvm-esp =
    patchToolchain "llvm-esp"
      (pkgs.fetchurl {
        url = currentToolchains.llvm.url;
        sha256 = currentToolchains.llvm.sha256;
      })
      ''
        mkdir -p $out
        for dir in */; do
          if [ -d "$dir" ]; then
            cp -r "$dir"/* $out/ 2>/dev/null || true
          fi
        done
        cp -r ./* $out/ 2>/dev/null || true
        chmod -R +x $out/bin/ 2>/dev/null || true

        mkdir -p $out/nix-support
        cat > $out/nix-support/setup-hook <<'EOF'
          export LLVM_ESP_PATH="@out@"
          export LIBCLANG_PATH="@out@/lib"
        EOF
        substituteInPlace $out/nix-support/setup-hook --subst-var out
      '';

  # Rust toolchain components (like fenix's mk-toolchain approach)
  # Rust tarballs have a different structure - use install.sh like fenix does
  rust-xtensa-base = pkgs.stdenv.mkDerivation {
    pname = "rust-xtensa-base";
    version = currentToolchains.rust.version;
    src = pkgs.fetchurl {
      url = currentToolchains.rust.url;
      sha256 = currentToolchains.rust.sha256;
    };

    nativeBuildInputs = [
      pkgs.xz
      pkgs.autoPatchelfHook
    ];

    buildInputs = [
      pkgs.stdenv.cc.cc.lib
      pkgs.zlib
    ];

    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;

    installPhase = ''
      # Use the install.sh script that comes with rust tarballs (fenix pattern)
      patchShebangs install.sh
      CFG_DISABLE_LDCONFIG=1 ./install.sh --prefix=$out

      # Remove installer artifacts
      rm $out/lib/rustlib/{components,install.log,manifest-*,rust-installer-version,uninstall.sh} 2>/dev/null || true

      chmod -R +x $out/bin/ 2>/dev/null || true
    '';

    meta = {
      description = "Rust compiler with Xtensa support";
      homepage = "https://github.com/esp-rs/rust-build";
    };
  };

  # rust-src component
  rust-src-xtensa = pkgs.stdenv.mkDerivation {
    pname = "rust-src-xtensa";
    version = currentToolchains.rust-src.version;
    src = pkgs.fetchurl {
      url = currentToolchains.rust-src.url;
      sha256 = currentToolchains.rust-src.sha256;
    };

    nativeBuildInputs = [ pkgs.xz ];
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      mkdir -p $out/lib/rustlib/src/rust

      echo "Listing contents:"
      ls -la

      # The tarball extracts with source root = rust-src-nightly/
      # and the content is in rust-src/lib/rustlib/src/rust/
      if [ -d "rust-src/lib/rustlib/src/rust" ]; then
        echo "Found rust-src directory, copying..."
        cp -r rust-src/lib/rustlib/src/rust/* $out/lib/rustlib/src/rust/
        echo "Contents after copy:"
        ls -la $out/lib/rustlib/src/rust/
      else
        echo "ERROR: rust-src directory not found!"
        echo "Current directory contents:"
        ls -la
        find . -type d -name "rust*" 2>/dev/null || true
      fi
    '';

    meta = {
      description = "Rust source code for ESP32";
      homepage = "https://github.com/esp-rs/rust-build";
    };
  };

  # Combine them like fenix does - using install to copy binaries (not symlink)
  rust-xtensa = pkgs.symlinkJoin {
    name = "rust-xtensa-${currentToolchains.rust.version}";
    paths = [
      rust-xtensa-base
      rust-src-xtensa
    ];

    nativeBuildInputs = [ pkgs.patchelf ];

    postBuild = ''
      # Copy binaries instead of symlinking (fenix pattern)
      for file in $(find $out/bin -xtype f -maxdepth 1 2>/dev/null); do
        install -m755 $(realpath "$file") $out/bin/
      done

      # Copy librustc_driver-* as well (critical for sysroot)
      for file in $(find $out/lib -name "librustc_driver-*" 2>/dev/null); do
        install $(realpath "$file") "$file"
      done

      # Fix rpath of rustc to include $out/lib while preserving other paths
      # This makes rustc find rust-src in the combined package
      old_rpath=$(patchelf --print-rpath $out/bin/rustc 2>/dev/null || echo "")
      if [ -n "$old_rpath" ]; then
        # Replace the base path with $out but keep other paths
        new_rpath=$(echo "$old_rpath" | sed "s|${rust-xtensa-base}|$out|g")
        patchelf --set-rpath "$new_rpath" $out/bin/rustc || true
      fi

      # Also fix other binaries that might have hardcoded paths
      for binary in rustdoc cargo cargo-clippy cargo-fmt; do
        file="$out/bin/$binary"
        if [ -f "$file" ]; then
          old_rpath=$(patchelf --print-rpath "$file" 2>/dev/null || echo "")
          if [ -n "$old_rpath" ]; then
            new_rpath=$(echo "$old_rpath" | sed "s|${rust-xtensa-base}|$out|g")
            patchelf --set-rpath "$new_rpath" "$file" || true
          fi
        fi
      done

      # Fix rpath for libraries
      for file in $(find $out/lib -name "*.so" -type f 2>/dev/null); do
        old_rpath=$(patchelf --print-rpath "$file" 2>/dev/null || echo "")
        if [ -n "$old_rpath" ]; then
          new_rpath=$(echo "$old_rpath" | sed "s|${rust-xtensa-base}|$out|g")
          patchelf --set-rpath "$new_rpath" "$file" || true
        fi
      done

      # Verify rust-src is in the right place
      if [ -d "$out/lib/rustlib/src/rust/library" ]; then
        echo "✓ rust-src installed in combined toolchain"
      fi
    '';

    passthru = {
      inherit rust-xtensa-base rust-src-xtensa;
    };
  };

  esp-idf = pkgs.callPackage ./esp-idf.nix { };

  # ============ Combined Toolchains ============

  complete-toolchain = pkgs.symlinkJoin {
    name = "esp32-complete-toolchain";
    paths = [
      xtensa-esp32-elf
      riscv32-esp-elf
      llvm-esp
      rust-xtensa
    ];
  };

  minimal-toolchain = pkgs.symlinkJoin {
    name = "esp32-minimal-toolchain";
    paths = [
      xtensa-esp32-elf
      riscv32-esp-elf
      rust-xtensa
    ];
  };

  # ============ Development Shells ============

  shells = import ./shells.nix {
    inherit pkgs lib;
    inherit
      xtensa-esp32-elf
      riscv32-esp-elf
      llvm-esp
      rust-xtensa
      esp-idf
      ;
    # espup = null;
  };

  combine =
    toolchains:
    pkgs.symlinkJoin {
      name = "esp32-combined-toolchain";
      paths = toolchains;
    };
}
