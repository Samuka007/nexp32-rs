{
  lib,
  stdenv,
  fetchurl,
  xz,
}:
let
  version = "14.2.0_20260121";
  baseUrl = "https://github.com/espressif/crosstool-NG/releases/download/esp-${version}/xtensa-esp-elf-${version}";

  # Platform-specific hashes
  platformInfo = {
    x86_64-linux = {
      url = "${baseUrl}-x86_64-linux-gnu.tar.xz";
      hash = "sha256-2jHzbXnU6Z8k5VqQpx5l1WlHFPFhmZYL94hXJLcGpIw=";
    };
    aarch64-linux = {
      url = "${baseUrl}-aarch64-linux-gnu.tar.xz";
      hash = "";
    };
    x86_64-darwin = {
      url = "${baseUrl}-x86_64-apple-darwin.tar.xz";
      hash = "";
    };
    aarch64-darwin = {
      url = "${baseUrl}-aarch64-apple-darwin.tar.xz";
      hash = "sha256-pFDbSc6l8ZGpY0XFt/DhqWcanPEy/s/Z+x+vbCowY34=";
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
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
