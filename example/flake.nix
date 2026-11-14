{
  description = "Example private wrapper: plateforme flake + your SOPS secrets";

  inputs = {
    # Public plateforme flake — the product. Pinned here; set PLATFORM_DIR
    # to a plateforme checkout (see Makefile) to build its working tree
    # instead of the lockfile pin.
    plateforme.url = "github:loic-roux-404/plateforme";
  };

  outputs =
    { self, plateforme }:
    let
      # EDIT THESE TWO: your macOS short user name (`whoami`) and GitHub
      # login. They parametrize home-manager and git (mkDarwinSystem
      # defaults to the plateforme author's identity otherwise).
      user = "jane";
      githubUser = "jane-doe";
    in
    {
      darwinConfigurations = builtins.mapAttrs (
        name: system:
        system.override {
          secretsSopsFile = "${self}/darwin.yaml";
          currentSystemUser = user;
          inherit githubUser;
          # `modules` is safe to replace on every variant (extraModules
          # stays per-variant, e.g. builder-x86 keeps configuration-x86).
          modules = plateforme.lib.attrValues plateforme.darwinModules ++ [
            {
              # AI stack off: the litellm gateway + claude-code + vscode
              # chat models need opencode_api_key / zai_api_key in
              # darwin.yaml. Delete this line to re-enable, and add the
              # two keys (see secrets-skeleton/darwin.yaml).
              paas.aiStack.enable = false;
            }
          ];
        }
      ) plateforme.darwinConfigurations;
    };
}
