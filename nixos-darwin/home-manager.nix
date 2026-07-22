{ inputs, ... }:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  gopath = "${config.home.homeDirectory}/Developer/go";

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
    asciinema
    bat
    cachix
    eza
    fd
    gettext
    gh
    htop
    jq
    tree
    watch

    gopls
    zigpkgs."0.15.2"

    gemini-cli

    # Node is required for Copilot.vim
    nodejs
    pnpm

    docker-client
    docker-credential-helpers
    zed-editor
  ];

  #---------------------------------------------------------------------
  # Env vars and dotfiles
  #---------------------------------------------------------------------

  home.sessionPath = [
    "${gopath}/bin"
  ];

  home.sessionVariables = {
    LANG = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    EDITOR = "nvim";
    PAGER = "less -FirSwX";
    MANPAGER = "${manpager}/bin/manpager";
    DOCKER_HOST = "tcp://127.0.0.1:2375";

    #OPENAI_API_KEY = "op://Private/OpenAPI_Personal/credential";

    # See: https://github.com/NixOS/nixpkgs/issues/390751
    DISPLAY = "nixpkgs-390751";
  };

  home.file = {
    ".inputrc".source = ./home-manager/.inputrc;
  };

  #---------------------------------------------------------------------
  # Programs
  #---------------------------------------------------------------------

  programs.gpg.enable = false;

  programs.bash = {
    enable = true;
    shellOptions = [ ];
    historyControl = [
      "ignoredups"
      "ignorespace"
    ];
    initExtra = builtins.readFile ./home-manager/.bashrc;
    shellAliases = shellAliases;
  };

  programs.direnv = {
    enable = true;

    config = {
      whitelist = {
        prefix = [
          "$HOME/code/go/src/github.com/loic-roux-404"
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
        "source ${inputs.theme-bobthefish}/functions/fish_prompt.fish"
        "source ${inputs.theme-bobthefish}/functions/fish_right_prompt.fish"
        "source ${inputs.theme-bobthefish}/functions/fish_title.fish"
        (builtins.readFile ./home-manager/config.fish)
        "set -g SHELL ${pkgs.fish}/bin/fish"
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

  programs.git = {
    enable = true;
    signing = {
      key = "D48109FA56B4BDCF";
      signByDefault = true;
    };
    settings = {
      user.name = "Loic Roux";
      branch.autosetuprebase = "always";
      color.ui = true;
      core.askPass = ""; # needs to be empty to use terminal for ask pass
      credential.helper = "store"; # want to make this more secure
      github.user = "loic-roux-404";
      push.default = "tracking";
      init.defaultBranch = "main";
      aliases = {
        cleanup = "!git branch --merged | grep  -v '\\*\\|master\\|develop' | xargs -n 1 -r git branch -d";
        lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
        root = "rev-parse --show-toplevel";
      };
    };
  };

  programs.go = {
    enable = true;
    env = {
      GOPATH = gopath;
      GOPRIVATE = [ "github.com/loic-roux-404" ];
    };
  };

  programs.oh-my-posh = {
    enable = true;
  };
}
