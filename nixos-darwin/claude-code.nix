{
  inputs,
  pkgs,
  unstablePkgs,
  ...
}:

let
  # nixpkgs 25.11 ships claude-code 2.0.x which lacks plugin-based LSP, so the
  # package always comes from nixpkgs-unstable. Upstream releases move fast, so
  # the *pinned revision* of that input (not the branch) decides the version:
  # run `make claude-update` to bump the lock entry and pick up the newest one.

  # Local LiteLLM gateway (litellm.nix) serving the /v1/messages Anthropic
  # flavor for the GLM coding plan and OpenCode Zen models. Model ids follow
  # the official Z.ai Claude Code setup guide:
  # https://docs.z.ai/devpack/overview — [1m] selects the 1M-context variant.
  glmBaseUrl = "http://127.0.0.1:4000";

  glmFlagship = "glm-5.3[1m]";
  glmFlash = "glm-5.3-flash";

  # OpenCode Zen ids (litellm.nix zenModels) + Claude Code [1m] suffix. The
  # gateway strips the suffix before the upstream call (litellm.nix
  # zenAliases), so Zen sees the plain id while Claude Code accounts a 1M
  # window instead of its 200k default.
  #
  # Tiering, measured with .agents/local-skills/zen-model-onboarding:
  #   frontier  kimi-k3.1-pro      — complex planning / reasoning ONLY.
  #                                  Strongest reasoner measured, but it
  #                                  thinks 60-240s and can burn a 16k budget
  #                                  on reasoning alone, so it is reached only
  #                                  through plan mode (model = "opusplan").
  #   workhorse deepseek-v4.1-flash — most of the challenging work
  #   subagent  deepseek-v4.1-flash — quick commands, raw output, minimal
  #                                  reflection (subagents re-read context per
  #                                  task, so fast+terse beats deep here).
  #
  # Only chat-completions models are reachable: litellm forwards that
  # protocol upstream, so Responses-only ids (muse-*, grok-4.x, gpt-*-luna, …)
  # cannot be served at all and are not in the gateway.
  frontier = "kimi-k3.1-pro[1m]";
  deepseekFlash = "deepseek-v4.1-flash[1m]";
  deepseekFlash200k = "deepseek-v4.1-flash";
in
{
  programs.claude-code = {
    enable = true;

    package = unstablePkgs.claude-code;

    settings = {
      # "opusplan" alias: plan mode → Opus class, everything else → Sonnet
      # class. Combined with the env remaps below: planning/complex reasoning
      # runs kimi-k3.1-pro, execution runs deepseek-v4.1-flash — the workhorse
      # does most of the work and the slow reasoner stays off the hot path.
      model = "opusplan";
      fallbackModel = [ glmFlagship glmFlash ];

      env = {
        ANTHROPIC_BASE_URL = glmBaseUrl;
        # Map the /model aliases onto the Zen + GLM tiers
        ANTHROPIC_DEFAULT_OPUS_MODEL = frontier;
        ANTHROPIC_DEFAULT_SONNET_MODEL = glmFlagship;
        ANTHROPIC_DEFAULT_HAIKU_MODEL = deepseekFlash200k;
        CLAUDE_CODE_SUBAGENT_MODEL = deepseekFlash200k;
        # 1M-context plan settings from the Z.ai guide
        CLAUDE_CODE_AUTO_COMPACT_WINDOW = "1000000";
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
        API_TIMEOUT_MS = "3000000";
      };

      # Proxy runs without a master key (localhost-only), so any non-empty
      # credential is accepted; sent as both Authorization: Bearer and
      # x-api-key.
      apiKeyHelper = "echo litellm-local";

      includeCoAuthoredBy = false;

      # Activated via plugin-id@marketplace-id (see marketplaces below). Works
      # everywhere settings.json is read, including the VS Code extension —
      # unlike the `plugins` option, whose --plugin-dir wrapper only applies
      # when launching the wrapped CLI binary.
      enabledPlugins = {
        "caveman@caveman" = true;
        "ponytail@ponytail" = true;
      };

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

    marketplaces = {
      ponytail = "${inputs.ponytail}";
      caveman = "${inputs.caveman}";
    };

    context = ''
      # Global context

      - Repos in this org carry an `AGENTS.md` — read it before working in a repo.
      - Prefer prefixing shell commands with `rtk` when available.
      - Secrets are SOPS-encrypted; never print decrypted values.
      - Use caveman mode full when available.
    '';
  };
}
