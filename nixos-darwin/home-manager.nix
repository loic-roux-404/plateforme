{
  inputs,
  unstablePkgs,
  currentSystemUser,
  githubUser,
  homeManagerModules,
  ...
}:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  gopath = "${config.home.homeDirectory}/Developer/go";

  agent-lsp = pkgs.callPackage ../nixpkgs/agent-lsp.nix { };

  shellAliases = {
    gco = "git checkout";
    gcoam = "git add . && git commit --amend && git push --force-with-lease";
    gp = "git push";
    gst = "git status";
    ofinder = "open -a Finder.app";
    opreview = "open -a preview.app";
    rm = "trash";
    vi = "sudo vim";
  };

  # For our MANPAGER env var
  # https://github.com/sharkdp/bat/issues/1145
  manpager = (
    pkgs.writeShellScriptBin "manpager" ''
      sh -c 'col -bx | bat -l man -p'
    ''
  );
in
{
  #---------------------------------------------------------------------
  # SOPS secrets — age key derived from ~/.ssh/id_ed25519 (same model as
  # nixpkgs/paas-secrets/init-sops.sh, but declarative: sops-nix converts the SSH key
  # itself at activation). Key must have no passphrase.
  #---------------------------------------------------------------------

  sops = {
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
    defaultSopsFile = "${inputs.secrets}/darwin.yaml";
    secrets = {
      hyper_api_key = { };
    };
  };

  # Home-manager 22.11 requires this be set. We never set it so we have
  # to use the old state version.
  home.stateVersion = "18.09";

  # Disabled for now since we mismatch our versions. See flake.nix for details.
  home.enableNixpkgsReleaseCheck = false;

  # We manage our own Nushell config via Chezmoi
  home.shell.enableNushellIntegration = false;

  xdg.enable = true;

  #---------------------------------------------------------------------
  # Packages
  #---------------------------------------------------------------------

  # Packages I always want installed. Most packages I install using
  # per-project flakes sourced with direnv and nix-shell, so this is
  # not a huge list.
  home.packages = with pkgs; [
    bashInteractive
    zsh

    asciinema
    bat
    cachix
    eza
    fd
    gettext
    gh
    htop
    jq
    yq
    tree
    watch
    nil
    nixfmt
    nix-tree
    grpcurl
    coreutils
    e2fsprogs
    libvirt
    qemu

    # Common lsp
    gopls
    bash-language-server
    pyright

    terraform
    terraform-ls

    kubectl
    kubelogin-oidc
    kubernetes-helm

    # Node is required for Copilot.vim
    nodejs
    nodePackages.yaml-language-server
    nodePackages.typescript-language-server
    typescript
    pnpm

    docker-client
    docker-credential-helpers

    gh

    fish-lsp
    jdt-language-server

    # misc lsp
    taplo

    vscode-langservers-extracted
    dockerfile-language-server
    helm-ls

    # Agent tooling
    agent-lsp
    terraform-mcp-server
    unstablePkgs.rtk
  ];

  #---------------------------------------------------------------------
  # Env vars and dotfiles
  #---------------------------------------------------------------------

  home.sessionPath = [
    "${gopath}/bin"
    "$HOME/.local/bin"
  ];

  sops.secrets.gh_token = { };

  sops.templates."gh-token.env" = {
    content = "export GITHUB_PERSONAL_ACCESS_TOKEN=${config.sops.placeholder.gh_token}";
    path = "${config.home.homeDirectory}/.config/sops-nix/gh-token.env";
  };

  home.sessionVariables = {
    LANG = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    EDITOR = "zed --wait";
    PAGER = "less -FirSwX";
    MANPAGER = "${manpager}/bin/manpager";
    DOCKER_HOST = "tcp://127.0.0.1:2375";

    # See: https://github.com/NixOS/nixpkgs/issues/390751
    DISPLAY = "nixpkgs-390751";
  };

  home.file = {
    ".inputrc".source = ./home-manager/.inputrc;
  };

  #---------------------------------------------------------------------
  # Programs
  #---------------------------------------------------------------------

  programs.gpg.enable = true;

  programs.bash = {
    enable = true;
    shellOptions = [ ];
    historyControl = [
      "ignoredups"
      "ignorespace"
    ];
    initExtra = (builtins.readFile ./home-manager/.bashrc) + ''
      # GitHub token from sops (rendered at activation, see home-manager.nix)
      source ${config.sops.templates."gh-token.env".path};
    '';
    shellAliases = shellAliases;
  };

  programs.direnv = {
    enable = true;

    config = {
      whitelist = {
        prefix = [
          "$HOME/code/go/src/github.com/${githubUser}"
        ];

        exact = [ "$HOME/.envrc" ];
      };
    };
  };

  programs.fish = {
    enable = true;
    shellAliases = shellAliases;
    interactiveShellInit = lib.strings.concatStrings (
      lib.strings.intersperse "\n" ([
        "source ${config.sops.templates."gh-token.env".path}"
        "source ${inputs.theme-bobthefish}/functions/fish_prompt.fish"
        "source ${inputs.theme-bobthefish}/functions/fish_right_prompt.fish"
        "source ${inputs.theme-bobthefish}/functions/fish_title.fish"
        (builtins.readFile ./home-manager/config.fish)
        "set -g SHELL ${pkgs.fish}/bin/fish"
        ''
          if test -x /opt/homebrew/bin/brew
            eval (/opt/homebrew/bin/brew shellenv)
          else if test -x /usr/local/bin/brew
            eval (/usr/local/bin/brew shellenv)
          end
        ''
      ])
    );

    plugins =
      map
        (n: {
          name = n;
          src = inputs.${n};
        })
        [
          "theme-bobthefish"
        ];
  };

  programs.alacritty = {
    enable = true;

    settings = {
      env.TERM = "xterm-256color";

      key_bindings = [
        {
          key = "K";
          mods = "Command";
          chars = "ClearHistory";
        }
        {
          key = "V";
          mods = "Command";
          action = "Paste";
        }
        {
          key = "C";
          mods = "Command";
          action = "Copy";
        }
        {
          key = "Key0";
          mods = "Command";
          action = "ResetFontSize";
        }
        {
          key = "Equals";
          mods = "Command";
          action = "IncreaseFontSize";
        }
        {
          key = "Subtract";
          mods = "Command";
          action = "DecreaseFontSize";
        }
      ];
    };
  };

  sops.secrets.email = { };
  sops.templates."git-user-email.inc" = {
    path = "${config.home.homeDirectory}/.config/git/user-email.inc";
    content = ''
      [user]
      	email = ${config.sops.placeholder.email}
    '';
  };

  programs.git = {
    enable = true;
    signing = {
      key = "D48109FA56B4BDCF";
      signByDefault = true;
      format = null;
    };
    settings = {
      user.name = currentSystemUser;
      branch.autosetuprebase = "always";
      color.ui = true;
      core.askPass = ""; # needs to be empty to use terminal for ask pass
      credential.helper = "store"; # want to make this more secure
      github.user = githubUser;
      push.default = "tracking";
      init.defaultBranch = "main";
      aliases = {
        cleanup = "!git branch --merged | grep  -v '\\*\\|master\\|develop' | xargs -n 1 -r git branch -d";
        lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
        root = "rev-parse --show-toplevel";
      };
    };
    settings = {
      gpg.program = "${pkgs.gnupg}/bin/gpg2";
    };
    includes = [
      { path = config.sops.templates."git-user-email.inc".path; }
    ];
  };

  programs.go = {
    enable = true;
    env = {
      GOPATH = gopath;
      GOPRIVATE = [ "github.com/${githubUser}" ];
    };
  };

  programs.oh-my-posh = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = false;
    enableBashIntegration = false;
  };

}
