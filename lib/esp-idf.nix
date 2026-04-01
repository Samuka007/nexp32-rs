{
  pkgs,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "esp-idf";
  version = "5.2.1";

  src = fetchFromGitHub {
    owner = "espressif";
    repo = "esp-idf";
    rev = "v${version}";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Placeholder
    fetchSubmodules = true;
  };

  nativeBuildInputs = with pkgs; [
    python3
    python3Packages.pip
    python3Packages.virtualenv
    git
    cmake
    ninja
  ];

  buildPhase = ''
    # Install ESP-IDF tools
    export IDF_TOOLS_PATH=$out

    # Run install script
    ./install.sh
  '';

  installPhase = ''
    mkdir -p $out
    cp -r . $out/

    # Create activation script
    mkdir -p $out/bin
    cat > $out/bin/esp-idf-env << 'EOF'
      #!/bin/sh
      export IDF_PATH="${placeholder "out"}"
      export IDF_TOOLS_PATH="${placeholder "out"}/tools"
      . "${placeholder "out"}"/export.sh
    EOF
    chmod +x $out/bin/esp-idf-env
  '';

  meta = with pkgs.lib; {
    description = "Espressif IoT Development Framework";
    homepage = "https://github.com/espressif/esp-idf";
    license = licenses.asl20;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
  };
}
