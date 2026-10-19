{
  ...
}:
let
  lowCostModels = [
    {
      id = "qwen3.8-max";
      name = "Qwen3.8 Max";
    }
    {
      id = "deepseek-v4.1-flash";
      name = "DeepSeek V4.1 Flash";
    }
    {
      id = "gemini-3.8-flash";
      name = "Gemini 3.8 Flash";
    }
    {
      id = "GLM-5.3";
      name = "GLM 5.3";
    }
        {
      id = "GLM-5.3-FLASH";
      name = "GLM 5.3 Flash";
    }
  ];
in
{
  programs.crush = {
    enable = true;
    settings = {
      providers = {
        # Local LiteLLM gateway (litellm.nix) fronting OpenCode Zen and the
        # Z.ai GLM coding plan; no master key on localhost, dummy bearer.
        litellm = {
          id = "litellm";
          name = "LiteLLM";
          base_url = "http://127.0.0.1:4000/v1";
          api_key = "litellm-local";
          type = "openai-compat";
          models = lowCostModels;
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
