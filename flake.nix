{
  description = "Nix configurations for a k8s paas build";

  inputs = {
    # Package sets
    nixpkgs.url = "github:NixOS/nixpkgs/25.11";
    nixpkgs-legacy.url = "github:NixOS/nixpkgs/25.05";
    srvos.url = "github:numtide/srvos";
    nixpkgs-srvos.follows = "srvos/nixpkgs";

    # Environment/system management
    darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "srvos/nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "srvos/nixpkgs";
    };

    # Flake utilities
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";

    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs =
    {
      self,
      srvos,
      darwin,
      nixos-generators,
      flake-utils,
      ...
    }@inputs:
    let
      inherit (self.lib)
        attrValues
        makeOverridable
        mkForce
        optionalAttrs
        singleton
        nixosSystem
        ;
      nixpkgsDefaults = {
        config = {
          allowUnfree = true;
        };
      };
    in
    {
      lib = inputs.nixpkgs-srvos.lib.extend (
        _: _: {
          mkDarwinSystem = import ./nix-lib/mkDarwinSystem.nix inputs;
        }
      );

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
        apple-silicon =
          _: prev:
          optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
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

      darwinDefaultExtraModules = singleton (
        { pkgs, ... }:
        {
          nixpkgs = nixpkgsDefaults;
          nix.registry.my.flake = inputs.self;
          environment.systemPackages = [
            pkgs.bashInteractive
          ];
        }
      );

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
      };
    }
    // flake-utils.lib.eachDefaultSystem (baseSystem: {
      packages.nixosConfigurations =
        let
          system = builtins.replaceStrings [ "darwin" ] [ "linux" ] baseSystem;
          srvosPackages = import inputs.nixpkgs-srvos (nixpkgsDefaults // { inherit system; });
          srvosPackagesX64 = import inputs.nixpkgs-srvos (nixpkgsDefaults // { system = "x86_64-linux"; });
          legacyPackages = import inputs.nixpkgs-legacy (nixpkgsDefaults // { inherit system; });
          legacyPackagesX64 = import inputs.nixpkgs-legacy (nixpkgsDefaults // { system = "x86_64-linux"; });
          specialArgs = {
            inherit srvosPackages legacyPackages;
          };
          specialArgsX64 = {
            srvosPackages = srvosPackagesX64;
            legacyPackages = legacyPackagesX64;
          };
        in
        {
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
            specialArgs = specialArgsX64;
            system = "x86_64-linux";
            modules = self.nixosAllModules.contabo;
          };

          deploy-contabo = nixosSystem {
            specialArgs = specialArgsX64;
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
      devShells =
        let
          system = baseSystem;
          pkgs = import inputs.nixpkgs-srvos (nixpkgsDefaults // { inherit system; });
        in
        {
          default = pkgs.mkShell {
            name = "default";
            packages = attrValues {
              inherit (pkgs)
                bashInteractive
                grpcurl
                jq
                coreutils
                e2fsprogs
                pebble
                cntb
                kubectl
                kubelogin-oidc
                kubernetes-helm
                nix
                nil
                nix-tree
                nixos-rebuild
                terraform
                terragrunt
                sops
                ssh-to-age
                libvirt
                qemu
                ;
            };
            shellHook = ''
              export DOCKER_HOST='tcp://127.0.0.1:2375'
            ''
            + builtins.readFile ./nix-flake/init-sops.sh;
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
              export DOCKER_HOST='tcp://127.0.0.1:2375'
              echo 'Docker Builder configured in arm mode'
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
              sudo ./result/sw/bin/darwin-rebuild switch --flake .#''${VARIANT:-builder}
            '';
          };
        };
    });
}
