{
  ...
}:
{
  programs.crush = {
    enable = true;
    settings = {
      providers = {
        hyper = {
          id = "hyper";
          name = "Hyper";
          base_url = "https://hyper.charm.land/v1/chat/completions";
          type = "openai-compat";
          models = [
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
        };
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
        };
        fish = {
          command = "fish-lsp";
        };
        go = {
          command = "gopls";
        };
        java = {
          command = "jdtls";
        };
        python = {
          command = "pyright";
        };
        terraform = {
          command = "terraform-ls";
        };
        yaml = {
          command = "yaml-language-server";
        };
        toml = {
          command = "taplo";
        };
        bash = {
          command = "bash-language-server";
        };
        json = {
          command = "vscode-json-language-server";
        };
        docker = {
          command = "docker-langserver";
        };
        helm = {
          command = "helm-ls";
        };
        markdown = {
          command = "marksman";
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
