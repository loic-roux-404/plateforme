inputs:

{ system ? "aarch64-darwin"
# `nix-darwin` modules to include
, modules ? [ ]
# Additional `nix-darwin` modules to include, useful when reusing a configuration with
# `lib.makeOverridable`.
, extraModules ? [ ]
, specialArgs ? {}
}:

inputs.darwin.lib.darwinSystem {
  inherit system;
  inherit specialArgs;
  modules = modules ++ extraModules ++ [
    ({ config, ... }: {
      nix.nixPath.nixpkgs = "${inputs.nixpkgs-stable-darwin}";
    })
  ];
}
