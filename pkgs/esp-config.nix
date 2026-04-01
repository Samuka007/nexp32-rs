{ lib
, rustPlatform
, fetchCrate
, pkg-config
, openssl
, stdenv
, darwin
, libiconv
}:

rustPlatform.buildRustPackage rec {
  pname = "esp-config";
  version = "0.6.1";

  src = fetchCrate {
    inherit pname version;
    sha256 = "sha256-ZL5O9UZAYFBuj5dEbNZfTNqRsgNr7Y8jzQKlPUZ+iso=";
  };
  
  buildFeatures = [ "tui" ];

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ] ++ lib.optionals stdenv.isDarwin [
    libiconv
    darwin.apple_sdk.frameworks.Security
  ];

  cargoHash = "sha256-7QPS780N3sxsNTLg8TOC/npIq34pTQnsl1aZWHlMgL4=";

  meta = with lib; {
    description = "Configure projects using esp-hal and related packages";
    homepage = "https://github.com/esp-rs/esp-config";
    license = with licenses; [ mit asl20 ];
    maintainers = with maintainers; [ ];
    mainProgram = "esp-config";
  };
}
