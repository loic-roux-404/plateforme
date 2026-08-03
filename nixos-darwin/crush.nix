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
          base_url = "https://hyper.charm.land/v1/";
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
      lsp = {
        go = {
          command = "gopls";
          enabled = true;
        };
        nix = {
          command = "nil";
          enabled = true;
        };
        bash = {
          command = "bash-language-server";
          enabled = true;
        };
        python = {
          command = "pyright-langserver";
          enabled = true;
        };
        terraform = {
          command = "terraform-ls";
          enabled = true;
        };
        yaml = {
          command = "yaml-language-server";
          enabled = true;
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
