{
  config,
  inputs,
  pkgs,
  ...
}:

let
  # nixpkgs 25.11 ships claude-code 2.0.x which lacks plugin-based LSP
  unstablePkgs = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.system;
    config.allowUnfree = true;
  };

  # GLM coding subscription, Anthropic-compatible endpoint (same plan as
  # providers.zai in crush.nix / vscode-agent.nix, but /v1/messages flavoured).
  # Model ids follow the official Z.ai Claude Code setup guide:
  # https://docs.z.ai/devpack/overview — [1m] selects the 1M-context variant.
  glmBaseUrl = "https://api.z.ai/api/anthropic";

  glmFlagship = "glm-5.3[1m]";
  glmFlash = "glm-5.3-flash[1m]";
in
{
  programs.claude-code = {
    enable = true;

    package = unstablePkgs.claude-code;

    settings = {
      model = glmFlagship;
      fallbackModel = [ glmFlash ];

      env = {
        ANTHROPIC_BASE_URL = glmBaseUrl;
        # Map the /model aliases onto the GLM coding plan
        ANTHROPIC_DEFAULT_OPUS_MODEL = glmFlagship;
        ANTHROPIC_DEFAULT_SONNET_MODEL = glmFlagship;
        ANTHROPIC_DEFAULT_HAIKU_MODEL = glmFlash;
        CLAUDE_CODE_SUBAGENT_MODEL = "glm-5.3-flash";
        # 1M-context plan settings from the Z.ai guide
        CLAUDE_CODE_AUTO_COMPACT_WINDOW = "1000000";
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
        API_TIMEOUT_MS = "3000000";
      };

      # Credential read at runtime from the sops secret (never lands in the
      # store). Output is sent as both Authorization: Bearer and x-api-key.
      apiKeyHelper = "cat \"${config.sops.secrets.zai_api_key.path}\"";

      includeCoAuthoredBy = false;

      # rtk token-optimizer hook. Declarative equivalent of the JSON that
      # `rtk init -g --auto-patch` injects into ~/.claude/settings.json —
      # done here because that file is home-manager-managed (read-only store
      # symlink), so rtk cannot patch it in place.
      hooks.PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "rtk hook claude";
            }
          ];
        }
      ];

      permissions = {
        allow = [
          "Bash(rtk:*)"
          "Bash(git status:*)"
          "Bash(git diff:*)"
          "Bash(git log:*)"
          "Bash(git show:*)"
          "Bash(nix eval:*)"
          "Bash(nix build:*)"
          "Bash(nix flake check:*)"
          "Bash(nixfmt:*)"
          "Bash(terragrunt plan:*)"
          "Bash(terragrunt output:*)"
          "Bash(make login)"
        ];
        deny = [
          # SOPS ciphertext and local tfstate (plaintext secrets inside)
          "Read(./secrets/**)"
          "Read(./.terragrunt/**)"
          "Read(./.env)"
          "Bash(sops -d:*)"
          "Bash(sops decrypt:*)"
          # Host switches stay operator-driven (repo constraint)
          "Bash(darwin-rebuild switch:*)"
          "Bash(nixos-rebuild switch:*)"
        ];
      };
    };

    # Same chrome-devtools MCP as crush.nix / .vscode/mcp.json
    mcpServers = {
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

    # Claude Code LSP is extension-driven (no root_markers like crush), so
    # helm-ls (would clash with yaml-language-server on .yaml) and
    # docker-langserver (Dockerfile has no dot-extension) are left out.
    lspServers = {
      nix = {
        command = "nil";
        extensionToLanguage = {
          ".nix" = "nix";
        };
      };
      fish = {
        command = "fish-lsp";
        extensionToLanguage = {
          ".fish" = "fish";
        };
      };
      go = {
        command = "gopls";
        args = [ "serve" ];
        extensionToLanguage = {
          ".go" = "go";
        };
      };
      typescript = {
        command = "typescript-language-server";
        args = [ "--stdio" ];
        extensionToLanguage = {
          ".ts" = "typescript";
          ".tsx" = "typescriptreact";
          ".js" = "javascript";
          ".jsx" = "javascriptreact";
        };
      };
      java = {
        command = "jdtls";
        extensionToLanguage = {
          ".java" = "java";
        };
      };
      python = {
        command = "pyright-langserver";
        args = [ "--stdio" ];
        extensionToLanguage = {
          ".py" = "python";
        };
      };
      terraform = {
        command = "terraform-ls";
        args = [ "serve" ];
        extensionToLanguage = {
          ".tf" = "terraform";
          ".tfvars" = "terraform";
        };
      };
      yaml = {
        command = "yaml-language-server";
        args = [ "--stdio" ];
        extensionToLanguage = {
          ".yaml" = "yaml";
          ".yml" = "yaml";
        };
      };
      toml = {
        command = "taplo";
        args = [
          "lsp"
          "stdio"
        ];
        extensionToLanguage = {
          ".toml" = "toml";
        };
      };
      bash = {
        command = "bash-language-server";
        args = [ "start" ];
        extensionToLanguage = {
          ".sh" = "shellscript";
          ".bash" = "shellscript";
        };
      };
      json = {
        command = "vscode-json-language-server";
        args = [ "--stdio" ];
        extensionToLanguage = {
          ".json" = "json";
        };
      };
    };

    marketplaces.ponytail = "${inputs.ponytail}";
    plugins = [
      "${inputs.ponytail}"
      "${inputs.caveman}"
    ];

    context = ''
      # Global context

      - Repos in this org carry an `AGENTS.md` — read it before working in a repo.
      - Prefer prefixing shell commands with `rtk` when available.
      - Secrets are SOPS-encrypted; never print decrypted values.
      - Use caveman mode full when available.
    '';
  };
}
