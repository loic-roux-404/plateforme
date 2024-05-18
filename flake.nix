{
  description = "Nix Darwin configuration for my systems (from https://github.com/malob/nixpkgs)";

  inputs = {
    # Package sets
    nixpkgs-stable.url = "github:NixOS/nixpkgs/23.11";
    nixpkgs-stable-darwin.url = "github:NixOS/nixpkgs/nixpkgs-23.11-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    srvos.url = "github:numtide/srvos";
    nixpkgs-srvos.follows = "srvos/nixpkgs";

    # Environment/system management
    darwin.url = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "srvos/nixpkgs";

    home-manager = { 
      url = "github:nix-community/home-manager/master"; 
      inputs.nixpkgs.follows = "srvos/nixpkgs"; 
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "srvos/nixpkgs";
    };

    # Flake utilities
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
    flake-utils.url = "github:numtide/flake-utils";

  };

  outputs = { self, srvos, darwin, nixos-generators, flake-utils, ... }@inputs:
    let
      inherit (self.lib) attrValues makeOverridable mkForce optionalAttrs singleton;
      nixpkgsDefaults = {
        config = {
          allowUnfree = true;
        };
      };
    in
    {
      lib = inputs.nixpkgs-srvos.lib.extend (_: _: {
        mkDarwinSystem = import ./lib/mkDarwinSystem.nix inputs;
      });

      overlays = {
        pkgs-stable = _: prev: {
          pkgs-stable = import inputs.nixpkgs-stable {
            inherit (prev.stdenv) system;
            inherit (nixpkgsDefaults) config;
          };
        };
        pkgs-unstable = _: prev: {
          pkgs-unstable = import inputs.nixpkgs-unstable {
            inherit (prev.stdenv) system;
            inherit (nixpkgsDefaults) config;
          };
        };
        apple-silicon = _: prev: optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
          # Add access to x86 packages system is running Apple Silicon
          pkgs-x86 = import inputs.nixpkgs-unstable {
            system = "x86_64-darwin";
            inherit (nixpkgsDefaults) config;
          };
        };

        tweaks = _: _: {
          # Add temporary overrides here
        };
      };

      darwinModules = {
        config = ./nixos-config/default.nix;
        os = ./nixos-darwin/configuration.nix;
      };

      nixosModules = {
        common = srvos.nixosModules.common;
        server = srvos.nixosModules.server;
        home-manager = inputs.home-manager.nixosModules.home-manager;
        os = ./nixos/configuration.nix;
        config = ./nixos-config/default.nix;
      };

      darwinConfigurations = {
        # Minimal macOS configurations to bootstrap systems
        bootstrap-x86 = makeOverridable darwin.lib.darwinSystem {
          system = "x86_64-darwin";
          modules = [ ./nixos/darwin.nix { nixpkgs = nixpkgsDefaults; } ];
        };
        bootstrap-arm = self.darwinConfigurations.bootstrap-x86.override {
          system = "aarch64-darwin";
        };

        # My Apple Silicon macOS laptop config
        k3s-paas-host = makeOverridable self.lib.mkDarwinSystem ({
          modules = attrValues self.darwinModules ++ singleton {
            nixpkgs = nixpkgsDefaults;
            nix.registry.my.flake = inputs.self;
          };
          extraModules = singleton {};
        });

        # Config with small modifications needed/desired for CI with GitHub workflow
        githubCI = self.darwinConfigurations.k3s-paas-host.override {
          system = "x86_64-darwin";
          username = "runner";
          nixConfigDirectory = "/Users/runner/work/nixpkgs/nixpkgs";
          extraModules = singleton {
            environment.etc.shells.enable = mkForce false;
            environment.etc."nix/nix.conf".enable = mkForce false;
            homebrew.enable = mkForce false;
          };
        };
      };

    } // flake-utils.lib.eachDefaultSystem (system: 
    let
      linux = builtins.replaceStrings ["darwin"] ["linux"] system;
      legacyPackages = import inputs.nixpkgs-srvos (nixpkgsDefaults // { inherit system; });
      stableLegacyPackages = import inputs.nixpkgs-stable (nixpkgsDefaults // { inherit system; });
    in {
      # Re-export `nixpkgs-stable` with overlays.
      # This is handy in combination with setting `nix.registry.my.flake = inputs.self`.
      # Allows doing things like `nix run my#prefmanager -- watch --all`
      inherit legacyPackages;
      inherit stableLegacyPackages;

      nixosConfigurations = rec {
        default = qcow;

        qcow = makeOverridable nixos-generators.nixosGenerate {
          system = linux;
          modules = attrValues self.nixosModules;
          format = "qcow";
        };

        contabo = self.nixosConfigurations.${system}.qcow.override {
          modules = attrValues self.nixosModules ++ [
            ./nixos/contabo.nix
          ];
        };

        vm-nogui = self.nixosConfigurations.${system}.qcow.override {
          modules = attrValues self.nixosModules ++ [
            ./nixos/qemu.nix
            {
              virtualisation.host.pkgs = self.legacyPackages.${system};
              virtualisation.vlans = [ 1 ];
            }
          ];
          format = "vm-nogui";
        };

        docker = self.nixosConfigurations.${system}.qcow.override {
          modules = attrValues self.nixosModules ++ [ 
            ./nixos/docker.nix
          ];
          format = "docker";
        };
      };

      # Development shells
      # Shell environments for development
      # With `nix.registry.my.flake = inputs.self`, development shells can be created by running,
      # e.g., `nix develop my#python`.
      devShells = let 
        pkgs = self.legacyPackages.${system};
        stablePkgs = self.stableLegacyPackages.${system};
       in
        {
          default = pkgs.mkShell {
            name = "default";
            packages = attrValues {
              inherit (pkgs) bashInteractive kubectl nil pebble jq grpcurl
              e2fsprogs coreutils libvirt qemu tailscale kubernetes-helm docker-client;
              inherit (stablePkgs) terraform nix-tree waypoint mitmproxy;
            };
            shellHook = ''
              export DOCKER_HOST=tcp://127.0.0.1:2375
            '';
          };

          builder = pkgs.mkShell {
            name = "builder";
            packages = attrValues {
              inherit (pkgs) nil bashInteractive;
            };  
            shellHook = (if pkgs.system == "aarch64-darwin" then ''
              nix build .#darwinConfigurations.k3s-paas-host.system
              ./result/sw/bin/darwin-rebuild switch --flake .#k3s-paas-host
            '' else "");
          };
        };
    });
}
# vim: foldmethod=marker  
