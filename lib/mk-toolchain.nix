{
  callPackage,
  fetchurl,
  lib,
  stdenv,
  zlib,
  autoPatchelfHook,
  patchelf,
  xz,
  curl,
}:

suffix:
{
  date,
  component,
  source,
}:

let
  inherit (lib) optionalString optionals;
  isRustSrc = component == "rust-src";
in

stdenv.mkDerivation {
  pname = "${component}${suffix}";
  version = source.date or date;

  src = fetchurl {
    inherit (source) url hash;
  };

  nativeBuildInputs = [ xz ] ++ optionals (stdenv.isLinux && !isRustSrc) [ autoPatchelfHook ];

  buildInputs = optionals (!isRustSrc) [
    stdenv.cc.cc.lib
    zlib
  ];

  dontConfigure = true;
  dontBuild = true;
  # Disable strip on Darwin to avoid removing .rmeta sections from rlib files
  # See: https://github.com/NixOS/nixpkgs/issues/218712
  dontStrip = stdenv.isDarwin || isRustSrc;

  installPhase = ''
    case "${component}" in
      rust-src)
        mkdir -p $out/lib/rustlib/src/rust
        if [ -d "rust-src/lib/rustlib/src/rust" ]; then
          cp -r rust-src/lib/rustlib/src/rust/* $out/lib/rustlib/src/rust/
        else
          cp -r . $out/lib/rustlib/src/rust/
        fi
        ;;

      *)
        patchShebangs install.sh
        CFG_DISABLE_LDCONFIG=1 ./install.sh --prefix=$out
        rm $out/lib/rustlib/{components,install.log,manifest-*,rust-installer-version,uninstall.sh} 2>/dev/null || true
        chmod -R +x $out/bin/ 2>/dev/null || true
        ;;
    esac
  '';

  postFixup = optionalString (stdenv.isLinux && !isRustSrc) ''
    if [ -d "$out/bin" ]; then
      for file in $(find $out/bin -type f 2>/dev/null); do
        if isELF "$file"; then
          patchelf \
            --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
            --set-rpath "${zlib}/lib:$out/lib" \
            "$file" 2>/dev/null || true
        fi
      done
    fi

    if [ -d "$out/lib" ]; then
      for file in $(find $out/lib -name "*.so*" -type f 2>/dev/null); do
        patchelf --set-rpath "${zlib}/lib:$out/lib" "$file" 2>/dev/null || true
      done
    fi
  '';

  meta = {
    description = "ESP32 ${component} toolchain";
    platforms = lib.platforms.all;
  };
}
