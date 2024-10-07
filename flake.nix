{
  description = "Nix configurations for a k8s paas build";

  inputs = {
    # Package sets
    nixpkgs.url = "github:NixOS/nixpkgs/24.05";
    nixpkgs-legacy.url = "github:NixOS/nixpkgs/23.11";
    nixpkgs-stable-darwin.url = "github:NixOS/nixpkgs/nixpkgs-24.05-darwin";
    srvos.url = "github:numtide/srvos";
    nixpkgs-srvos.follows = "srvos/nixpkgs";

    # Environment/system management
    darwin.url = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs-stable-darwin";

    nixpkgs-rke-patched.url = "github:crumohr/nixpkgs";

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

    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, srvos, darwin, nixos-generators, flake-utils, ... }@inputs:
    let
      inherit (self.lib) attrValues makeOverridable mkForce optionalAttrs singleton nixosSystem;
      nixpkgsDefaults = {
        config = {
          allowUnfree = true;
        };
      };
    in
    {
      lib = inputs.nixpkgs-srvos.lib.extend (_: _: {
        mkDarwinSystem = import ./nix-lib/mkDarwinSystem.nix inputs;
      });

      overlays = {
        pkgs-stable = _: prev: {
          pkgs-stable = import inputs.nixpkgs {
            inherit (prev.stdenv) system;
            inherit (nixpkgsDefaults) config;
          };
        };
        pkgs-unstable = _: prev: {
          pkgs-unstable = import inputs.nixpkgs-srvos {
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

      nixosModules = {
        sops = inputs.sops-nix.nixosModules.sops;
        common = srvos.nixosModules.common;
        server = srvos.nixosModules.server;
        home-manager = inputs.home-manager.nixosModules.home-manager;
        os = ./nixos/configuration.nix;
        config = ./nixos-options/default.nix;
        qcowCompressed = ./nixos/qcow-compressed.nix;
        allFormats = nixos-generators.nixosModules.all-formats;
      };

      nixosAllModules = rec {
        default = attrValues self.nixosModules;
        contabo = default ++ [ ./nixos/contabo.nix ];
        deploy = default ++ [ ./nixos/deploy.nix ];
        deployContabo = deploy ++ [ ./nixos/contabo.nix ];
      };

      darwinModules = {
        config = ./nixos-options/default.nix;
        os = ./nixos-darwin/configuration.nix;
      };

      darwinDefaultExtraModules = singleton ({ pkgs, ... } : {
        nixpkgs = nixpkgsDefaults;
        nix.registry.my.flake = inputs.self;
        environment.systemPackages = [ 
          pkgs.bashInteractive 
        ];
      });

      darwinConfigurations = {
        default = self.darwinConfigurations.builder;
        builder = makeOverridable self.lib.mkDarwinSystem ({
          modules = attrValues self.darwinModules;
          extraModules = self.darwinDefaultExtraModules;
        });

        builder-x86 = self.darwinConfigurations.builder.override {
          extraModules = self.darwinDefaultExtraModules ++ [ 
            ./nixos-darwin/configuration-x86.nix
          ];
        };

        # Need a bare darwinConfigurations.builder started before building this one.
        builder-docker = self.darwinConfigurations.builder.override {
          extraModules = attrValues {
            linux-docker-builder = ./nixos-darwin/linux-builder-docker.nix;
          };
        };

        # Config with small modifications needed/desired for CI with GitHub workflow
        githubCI = self.darwinConfigurations.default.override {
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
    }
    // flake-utils.lib.eachDefaultSystem (baseSystem:
    {
      packages.nixosConfigurations = let
        system = builtins.replaceStrings ["darwin"] ["linux"] baseSystem;
        oldLegacyPackages = import inputs.nixpkgs-legacy (nixpkgsDefaults // { inherit system; });
        specialArgs = {
          inherit oldLegacyPackages;
          nixpkgsRkePatched = import inputs.nixpkgs-rke-patched { inherit system; };
        };

      in {
        ## Libvirt configurations

        initial = nixosSystem {
          inherit system specialArgs;
          modules = self.nixosAllModules.default;
        };

        deploy = nixosSystem {
          inherit system specialArgs;
          modules = self.nixosAllModules.deploy;
        };

        ## Contabo-specific configurations

        initial-contabo = nixosSystem {
          inherit specialArgs;
          system = "x86_64-linux";
          modules = self.nixosAllModules.contabo;
        };

        deploy-contabo = nixosSystem {
          inherit specialArgs;
          system = "x86_64-linux";
          modules = self.nixosAllModules.deployContabo ++ [
            ./nixos/contabo-master-0.nix
          ];
        };

        ## Docker configurations

        container = nixosSystem {
          modules = self.nixosAllModules.default ++ [ 
            nixos-generators.nixosModules.docker
            ./nixos/docker.nix
          ];
        };
      };

      # Development shells
      # Shell environments for development
      # With `nix.registry.my.flake = inputs.self`, development shells can be created by running,
      # e.g., `nix develop my#python`.
      devShells = let 
        system = baseSystem;
        oldLegacyPackages = import inputs.nixpkgs-legacy (nixpkgsDefaults // { inherit system; });
        pkgs = import inputs.nixpkgs-srvos (nixpkgsDefaults // { inherit system; });
        stablePkgs = import inputs.nixpkgs (nixpkgsDefaults // { inherit system; });
       in
        {
          default = pkgs.mkShell {
            name = "default";
            packages = attrValues {
              inherit (pkgs) bashInteractive grpcurl jq coreutils e2fsprogs
              docker-client docker-credential-helpers 
              pebble cntb kubernetes-helm nil nix-tree;
              inherit (stablePkgs) nix terraform terragrunt nixos-rebuild
              sops ssh-to-age libvirt qemu;
              inherit (oldLegacyPackages) waypoint;
            };
            shellHook = ''
              export DOCKER_HOST=tcp://127.0.0.1:2375
            '' + builtins.readFile ./nix-flake/init-sops.sh;
          };

          builder-docker = pkgs.mkShell {
            name = "docker";
            packages = attrValues {
              inherit (pkgs) nil bashInteractive docker-client;
            };
            shellHook = ''
              set -e
              nix build .#darwinConfigurations.builder-docker.system
              ./result/sw/bin/darwin-rebuild switch --flake .#builder-docker
              export DOCKER_HOST=tcp://127.0.0.1:2375
            '';
          };

          builder = pkgs.mkShell {
            name = "builder";
            packages = attrValues {
              inherit (pkgs) nil bashInteractive;
            };
            shellHook = ''
              set -e
              nix build .#darwinConfigurations.''${VARIANT:-builder}.system
              ./result/sw/bin/darwin-rebuild switch --flake .#''${VARIANT:-builder}
            '';
          };
        };
    });
}
# vim: foldmethod=marker  
