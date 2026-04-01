{
  pkgs,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  toolchainVersions,
}:

let
  versionInfo = toolchainVersions.espup;
in
rustPlatform.buildRustPackage rec {
  pname = "espup";
  version = versionInfo.version;

  src = fetchFromGitHub {
    owner = "esp-rs";
    repo = "espup";
    rev = "v${version}";
    sha256 = versionInfo.sha256;
  };

  cargoSha256 = versionInfo.sha256; # This needs separate prefetching

  nativeBuildInputs = with pkgs; [
    pkg-config
  ];

  buildInputs =
    with pkgs;
    [
      openssl
      zlib
    ]
    ++ pkgs.lib.optionals stdenv.isDarwin [
      pkgs.darwin.apple_sdk.frameworks.Security
      pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
    ];

  # Skip tests that require network
  doCheck = false;

  meta = with pkgs.lib; {
    description = "Tool for installing and maintaining Espressif Rust ecosystem";
    homepage = "https://github.com/esp-rs/espup";
    license = licenses.mit;
    platforms = platforms.all;
    maintainers = [ ];
  };
}
