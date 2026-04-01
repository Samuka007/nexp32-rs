{ pkgs, lib, manifestFile }:

let
  inherit (pkgs) callPackage;
  inherit (lib) mapAttrs filterAttrs attrVals;

  # Load manifest
  manifest = builtins.fromJSON (builtins.readFile manifestFile);

  # Use our combine (copied from fenix, simplified)
  combine = callPackage ./combine.nix { };

  # Build individual components (fenix-style for Rust components)
  mkToolchain = callPackage ./mk-toolchain.nix { };

  # Build all components from manifest
  components = mapAttrs
    (name: component:
      let
        source = component.${pkgs.system} or (throw "Component ${name} not available for ${pkgs.system}");
      in
      mkToolchain "-esp-${manifest.version}" {
        date = manifest.date;
        component = name;
        inherit source;
      }
    )
    (filterAttrs (n: v: v ? ${pkgs.system}) manifest.components);

  # Build profiles by combining components (fenix-style)
  mkProfile = name:
    let
      componentList = manifest.profiles.${name};
      componentPaths = attrVals componentList components;
    in
    combine "rust-esp-${manifest.version}-${name}" componentPaths;

  profiles = mapAttrs (n: v: mkProfile n) manifest.profiles;

  # Build standalone tools (GCC, etc.) - not part of Rust toolchain
  tools = mapAttrs
    (name: tool:
      let
        source = tool.${pkgs.system} or (throw "Tool ${name} not available for ${pkgs.system}");
      in
      pkgs.stdenv.mkDerivation {
        pname = name;
        version = tool.version or manifest.version;
        src = pkgs.fetchurl {
          inherit (source) url hash;
        };
        nativeBuildInputs = [ pkgs.xz ];
        dontConfigure = true;
        dontBuild = true;
        installPhase = ''
          mkdir -p $out
          cp -r . $out/
          chmod -R +x $out/bin/ 2>/dev/null || true
        '';
        dontStrip = true;
      }
    )
    (manifest.tools or {});

in
components // profiles // tools // {
  # Expose manifest info
  inherit manifest;

  # Profiles
  inherit profiles;

  # Tools
  inherit tools;

  # Convenience aliases (fenix-style)
  toolchain = profiles.complete or profiles.default or profiles.minimal;
  rust-xtensa = profiles.complete or profiles.default;
  complete-toolchain = profiles.complete;
  minimal-toolchain = profiles.minimal;
  xtensa-gcc = tools.xtensa-esp32-elf or (throw "xtensa-gcc not available");

  # Custom component selector (fenix-style)
  withComponents = names:
    combine "rust-esp-${manifest.version}-custom"
      (attrVals names components);

  # Development shells (include GCC for linker)
  shells = import ./shells.nix {
    inherit pkgs lib;
    inherit (profiles) complete;
    inherit (tools) xtensa-esp32-elf;
  };
}
