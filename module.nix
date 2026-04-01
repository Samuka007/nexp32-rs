# NixOS and home-manager module for ESP32 development
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.esp-rs;
  
in
{
  options.programs.esp-rs = {
    enable = mkEnableOption "ESP32 Rust development environment";
    
    targets = mkOption {
      type = types.listOf (types.enum [ 
        "esp32" 
        "esp32s2" 
        "esp32s3" 
        "esp32c2" 
        "esp32c3" 
        "esp32c6" 
        "esp32h2" 
        "esp32p4" 
        "all" 
      ]);
      default = [ "all" ];
      description = "ESP32 targets to enable";
    };
    
    installEspIdf = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to install ESP-IDF for std development";
    };
    
    installEspup = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install espup tool";
    };
  };
  
  config = mkIf cfg.enable {
    # Install required packages
    environment.systemPackages = with pkgs; 
      [ 
        # Toolchains based on targets
        (if elem "all" cfg.targets || any (t: elem t [ "esp32" "esp32s2" "esp32s3" ]) cfg.targets
          then esp32-toolchain
          else null)
        
        (if elem "all" cfg.targets || any (t: elem t [ "esp32c2" "esp32c3" "esp32c6" "esp32h2" "esp32p4" ]) cfg.targets
          then riscv32-esp-elf
          else null)
        
        # LLVM
        llvm-esp
        
        # Rust with Xtensa support
        rust-xtensa
      ]
      ++ optional cfg.installEspup espup
      ++ optional cfg.installEspIdf esp-idf
      ++ [
        # Common tools
        cmake
        ninja
        python3
        git
        cargo-espflash
      ];
    
    # Set up environment variables
    environment.sessionVariables = {
      LLVM_ESP_PATH = "${pkgs.llvm-esp}";
      LIBCLANG_PATH = "${pkgs.llvm-esp}/lib";
    };
    
    # Set up cargo environment for ESP32 targets
    environment.etc."cargo/config.toml" = mkIf (elem "all" cfg.targets) {
      text = ''
        [target.xtensa-esp32-none-elf]
        linker = "xtensa-esp32-elf-gcc"
        
        [target.xtensa-esp32s2-none-elf]
        linker = "xtensa-esp32s2-elf-gcc"
        
        [target.xtensa-esp32s3-none-elf]
        linker = "xtensa-esp32s3-elf-gcc"
        
        [target.riscv32imc-unknown-none-elf]
        linker = "riscv32-esp-elf-gcc"
        
        [target.riscv32imac-unknown-none-elf]
        linker = "riscv32-esp-elf-gcc"
      '';
    };
  };
}
