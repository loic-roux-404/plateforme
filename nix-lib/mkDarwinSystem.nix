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
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.sharedModules = homeManagerModules;
          home-manager.users.${currentSystemUser} = import ../nixos-darwin/home-manager.nix {
            inherit inputs;
            unstablePkgs = import inputs.nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
            currentSystem = system;
            currentSystemName = name;
            currentSystemUser = currentSystemUser;
            inherit githubUser;
            inherit homeManagerModules;
          };
        }
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
        inherit inputs;
      };
    }
  ]
  ++ modules
  ++ extraModules;
}
