# Function to create a nix-darwin system configuration, tailored specifically
# for macOS / Darwin environments.
inputs:

{
  name ? "builder",
  system ? "aarch64-darwin",
  currentSystemUser ? "loic",
  githubUser ? "loic-roux-404",
  overlays ? [ ],
  modules ? [ ],
  extraModules ? [ ],
  homeManagerModules ? [ ],
  specialArgs ? { },
}:

let
  darwinSystem = inputs.darwin.lib.darwinSystem;

  # Single nixpkgs-unstable import shared by every darwin module
  # (_module.args) and home-manager.nix (explicit call argument).
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
in
darwinSystem {
  inherit system;
  specialArgs = specialArgs // {
    inherit inputs;
  };

  modules = [
    # Global nixpkgs configuration & overlays
    {
      nixpkgs.overlays = overlays;
      nixpkgs.config.allowUnfree = true;
      nix.nixPath.nixpkgs = "${inputs.nixpkgs}";
    }
  ]
  # Integrate Rosetta builder for Linux emulation if input is present
  ++ (
    if (inputs ? nix-rosetta-builder) then
      [
        inputs.nix-rosetta-builder.darwinModules.default
        {
          nix-rosetta-builder.onDemand = true;
        }
      ]
    else
      [ ]
  )
  # Integrate Home-Manager for Darwin if input is present
  ++ (
    if (inputs ? home-manager) then
      [
        inputs.home-manager.darwinModules.home-manager
        (
          {
            pkgs,
            ...
          }:
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # claude-code replaces home-manager's managed symlinks (e.g.
            # known_marketplaces.json) with real files, so each switch must
            # back the file up before re-linking. A fixed extension works
            # once then aborts on collision; a timestamp never collides.
            # nix flake switch can be blocked if no timestamp used
            home-manager.backupCommand = toString (
              pkgs.writeShellScript "hm-backup" ''
                mv "$1" "$1.$(date +%Y%m%d-%H%M%S)"
              ''
            );
            home-manager.extraSpecialArgs = {
              inherit inputs;
              inherit unstablePkgs;
            };
            home-manager.sharedModules = homeManagerModules;
            home-manager.users.${currentSystemUser} = import ../nixos-darwin/home-manager.nix {
              inherit inputs;
              inherit unstablePkgs;
              currentSystem = system;
              currentSystemName = name;
              currentSystemUser = currentSystemUser;
              inherit githubUser;
              inherit homeManagerModules;
            };
          }
        )
      ]
    else
      [ ]
  )
  # Expose metadata & inputs to all modules
  ++ [
    {
      _module.args = {
        currentSystem = system;
        currentSystemName = name;
        currentSystemUser = currentSystemUser;
        unstablePkgs = unstablePkgs;
        inherit inputs;
      };
    }
  ]
  ++ modules
  ++ extraModules;
}
