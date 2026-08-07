{
  config,
  ...
}:
let
  lowCostModels = [
    {
      id = "kimi-k3";
      name = "Kimi K3";
    }
    {
      id = "kimi-k2.7-code";
      name = "Kimi k2.7 Code";
    }
    {
      id = "deepseek-v4-flash";
      name = "DeepSeek v4 Flash";
    }
  ];

  # API keys come from sops-nix (secrets/darwin.yaml). Crush expands
  # $(...) in config values at load time, so we shell out to cat the
  # decrypted secret. No plaintext key ever reaches the Nix store.
  hyperApiKey = "$(cat ${config.sops.secrets.hyper_api_key.path})";
  opencodeApiKey = "$(cat ${config.sops.secrets.opencode_api_key.path})";
in
{
  programs.crush = {
    enable = true;
    settings = {
      providers = {
        opencode = {
          id = "opencode";
          name = "OpenCode";
          base_url = "https://opencode.ai/zen/go/v1/chat/completions";
          api_key = opencodeApiKey;
          type = "openai-compat";
          models = lowCostModels;
        };
        # hyper = {
        #   id = "hyper";
        #   name = "Hyper";
        #   base_url = "https://hyper.charm.land/v1/chat/completions";
        #   api_key = hyperApiKey;
        #   type = "openai-compat";
        #   models = lowCostModels;
        # };
      };
      mcp = {
        chrome-devtools = {
          type = "stdio";
          command = "npx";
          args = [
            "-y"
            "chrome-devtools-mcp@latest"
            "--isolated"
            "--experimentalPageIdRouting"
            "--screenshotFormat=webp"
            "--screenshotQuality=75"
            "--screenshotMaxWidth=1600"
            "--screenshotMaxHeight=1200"
            "--memoryDebugging"
          ];
        };
      };

      lsp = {
        nix = {
          command = "nil";
          filetypes = [ "nix" ];
          root_markers = [ "flake.nix" ];
        };
        fish = {
          command = "fish-lsp";
          filetypes = [ "fish" ];
        };
        go = {
          command = "gopls";
          filetypes = [
            "go"
            "mod"
          ];
          root_markers = [
            "go.mod"
            "go.work"
          ];
        };
        typescript = {
          command = "typescript-language-server";
          args = [ "--stdio" ];
          filetypes = [
            "js"
            "jsx"
            "ts"
            "tsx"
          ];
          root_markers = [
            "package.json"
            "tsconfig.json"
          ];
        };
        java = {
          command = "jdtls";
          filetypes = [ "java" ];
          root_markers = [
            "pom.xml"
            "build.gradle"
            "settings.gradle"
          ];
        };
        python = {
          command = "pyright-langserver";
          args = [ "--stdio" ];
          filetypes = [ "py" ];
          root_markers = [
            "pyproject.toml"
            "requirements.txt"
          ];
        };
        terraform = {
          command = "terraform-ls";
          args = [ "serve" ];
          filetypes = [
            "tf"
            "tfvars"
          ];
          root_markers = [ ".terraform" ];
        };
        yaml = {
          command = "yaml-language-server";
          args = [ "--stdio" ];
          filetypes = [
            "yaml"
            "yml"
          ];
        };
        toml = {
          command = "taplo";
          args = [
            "lsp"
            "stdio"
          ];
          filetypes = [ "toml" ];
        };
        bash = {
          command = "bash-language-server";
          args = [ "start" ];
          filetypes = [
            "sh"
            "bash"
          ];
        };
        json = {
          command = "vscode-json-language-server";
          args = [ "--stdio" ];
          filetypes = [ "json" ];
        };
        docker = {
          command = "docker-langserver";
          args = [ "--stdio" ];
          filetypes = [ "dockerfile" ];
        };
        helm = {
          command = "helm-ls";
          args = [ "serve" ];
          filetypes = [
            "helm"
            "yaml"
          ];
          root_markers = [ "Chart.yaml" ];
        };
        markdown = {
          command = "marksman";
          args = [ "server" ];
          filetypes = [
            "md"
            "markdown"
          ];
        };
      };
      options = {
        #context_paths = [ "$NIX_PATH" ];
        tui = {
          compact_mode = true;
        };
        debug = false;
      };
    };
  };
}
