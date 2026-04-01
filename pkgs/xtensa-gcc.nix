{
  lib,
  stdenv,
  fetchurl,
  xz,
}: let
  version = "esp-14.2.0_20260121";

  # Platform-specific URLs and hashes
  platformInfo = {
    x86_64-linux = {
      url = "https://github.com/espressif/crosstool-NG/releases/download/${version}/xtensa-esp-elf-${version}-x86_64-linux-gnu.tar.xz";
      hash = "sha256-2jHzbXnU6Z8k5VqQpx5l1WlHFPFhmZYL94hXJLcGpIw=";
    };
    aarch64-linux = {
      url = "https://github.com/espressif/crosstool-NG/releases/download/${version}/xtensa-esp-elf-${version}-aarch64-linux-gnu.tar.xz";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    x86_64-darwin = {
      url = "https://github.com/espressif/crosstool-NG/releases/download/${version}/xtensa-esp-elf-${version}-x86_64-apple-darwin.tar.xz";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    aarch64-darwin = {
      url = "https://github.com/espressif/crosstool-NG/releases/download/${version}/xtensa-esp-elf-${version}-aarch64-apple-darwin.tar.xz";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
  };

  platform = stdenv.hostPlatform.system;
  info = platformInfo.${platform} or (throw "Unsupported system: ${platform}");
in

stdenv.mkDerivation {
  pname = "xtensa-esp32-elf";
  version = version;

  src = fetchurl {
    inherit (info) url hash;
  };

  nativeBuildInputs = [ xz ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out
    cp -r . $out/
    chmod -R +x $out/bin/ 2>/dev/null || true
  '';

  dontStrip = true;

  meta = with lib; {
    description = "GCC toolchain for Xtensa ESP32";
    homepage = "https://github.com/espressif/crosstool-NG";
    license = licenses.gpl3;
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
  };
}
