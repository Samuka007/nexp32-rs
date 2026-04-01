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

in
components // profiles // {
  # Expose manifest info
  inherit manifest;

  # Profiles
  inherit profiles;

  # Convenience aliases (fenix-style)
  toolchain = profiles.complete or profiles.default or profiles.minimal;
  rust-xtensa = profiles.complete or profiles.default;
  complete-toolchain = profiles.complete;
  minimal-toolchain = profiles.minimal;

  # Custom component selector (fenix-style)
  withComponents = names:
    combine "rust-esp-${manifest.version}-custom"
      (attrVals names components);

  # Development shells
  shells = import ./shells.nix {
    inherit pkgs lib;
    inherit (profiles) complete;
  };
}
