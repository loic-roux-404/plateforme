{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Local LiteLLM gateway: OpenCode Zen + Z.ai GLM coding plan behind one
  # OpenAI- (/v1/chat/completions) and Anthropic-compatible (/v1/messages)
  # endpoint on 127.0.0.1:4000. No auth (localhost trust, same model as the
  # minio daemon). Clients: claude-code.nix, vscode-agent.nix, crush.nix.
  litellmPort = 4000;

  opencodeZenBase = "https://opencode.ai/zen/go/v1";
  zaiCodingBase = "https://api.z.ai/api/coding/paas/v4";

  # `openai/<model>` + api_base override is the universal OpenAI-compat
  # routing in litellm 1.75.5 (the `zai/` prefix may not exist there).
  #
  # Zen rejects header-less requests with 400 MissingSessionID
  # (x-opencode-session, https://opencode.ai/docs/go/#where-can-i-use-it):
  # it is a routing-affinity hint, not auth. The gateway is single-user, so
  # one static value is a legitimate session; litellm forwards
  # litellm_params.extra_headers verbatim on OpenAI-compat calls.
  zenSessionId = "5f3e1c2a-7b8d-4e6f-9a0b-1c2d3e4f5a6b";

  mkEntry = apiBase: apiKeyEnv: model: {
    model_name = model;
    litellm_params = {
      model = "openai/${model}";
      api_base = apiBase;
      api_key = "os.environ/${apiKeyEnv}";
    }
    // lib.optionalAttrs (apiBase == opencodeZenBase) {
      extra_headers."x-opencode-session" = zenSessionId;
    };
  };

  # Local alias that maps to a different upstream id (e.g. Claude Code's [1m]
  # 1M-context suffix, which neither Zen nor Z.ai parses on the wire — Z.ai
  # answers "Unknown Model" for glm-5.3[1m] but serves GLM-5.3).
  mkAlias =
    upstream: alias: (mkEntry zaiCodingBase "ZAI_API_KEY" upstream) // { model_name = alias; };

  # OpenCode Zen catalog (union of vscode-agent.nix + crush.nix).
  #
  # Every id here was verified with `curl` against
  # https://opencode.ai/zen/go/v1/chat/completions: chat-completions + tool
  # calling both work. Ids that only speak /v1/responses cannot be proxied
  # here — litellm forwards the chat-completions protocol and gets
  # ModelProtocolUnsupported. That rules out grok-4.x, gpt-*-luna,
  # claude-haiku-5-5 and every muse-* model, including muse-wonder-1.0,
  # which is also outside the Go plan (it only answers /zen/v1/responses).
  # See .agents/local-skills/zen-model-onboarding.
  zenModels = [
    "kimi-k3.1-pro" # frontier tier: planning / complex reasoning only
    "deepseek-v4.1-flash" # workhorse tier
    "qwen3.8-max"
    "qwen3.8-flash"
  ];

  # Z.ai coding catalog: exact-case ids referenced by .vscode/settings.json
  # and crush.nix (case-sensitive).
  glmModels = [
    "GLM-5.3"
    "GLM-5.3-FLASH"
  ];

  # Lowercase aliases for Claude Code env remaps (ANTHROPIC_DEFAULT_*_MODEL),
  # mapped onto the exact-case upstream ids above ([1m] = 1M-window
  # accounting on the Claude Code side only).
  glmAliases = [
    (mkAlias "GLM-5.3" "glm-5.3")
    (mkAlias "GLM-5.3" "glm-5.3[1m]")
    (mkAlias "GLM-5.3-FLASH" "glm-5.3-flash")
    (mkAlias "GLM-5.3-FLASH" "glm-5.3-flash[1m]")
  ];

  # Claude Code's [1m] suffix is client-side 1M-context accounting. Zen serves
  # 1M on the plain ids (vscode-agent.nix maxInputTokens) and does not parse
  # that selector, so each alias strips it before the upstream call.
  zenAliases =
    map
      (
        upstream:
        (mkEntry opencodeZenBase "OPENCODE_API_KEY" upstream)
        // {
          model_name = "${upstream}[1m]";
        }
      )
      [
        "deepseek-v4.1-flash"
        "kimi-k3.1-pro"
      ];

  litellmConfig = (pkgs.formats.yaml { }).generate "litellm-config.yaml" {
    model_list =
      map (mkEntry opencodeZenBase "OPENCODE_API_KEY") zenModels
      ++ map (mkEntry zaiCodingBase "ZAI_API_KEY") glmModels
      ++ glmAliases
      ++ zenAliases;
    litellm_settings.drop_params = true;
    # Deliberately no general_settings.master_key: localhost-only, no auth.
  };

  # Secrets only ever exist in env vars of this wrapper (HM launchd has no
  # `script` option and EnvironmentVariables is not shell-evaluated).
  litellmStart = pkgs.writeShellScript "litellm-start" ''
    set -euo pipefail
    export ZAI_API_KEY="$(cat ${config.sops.secrets.zai_api_key.path})"
    export OPENCODE_API_KEY="$(cat ${config.sops.secrets.opencode_api_key.path})"
    exec ${pkgs.litellm}/bin/litellm \
      --config ${litellmConfig} \
      --host 127.0.0.1 \
      --port ${toString litellmPort}
  '';
in
{
  # Consumed by litellm-start (moved here from vscode-agent.nix)
  sops.secrets.zai_api_key = { };
  sops.secrets.opencode_api_key = { };

  # User LaunchAgent (~/Library/LaunchAgents, gui/$(id -u) domain), like the
  # sops-nix agent. KeepAlive self-heals the boot race against sops-nix
  # secret rendering (respawn after launchd's 10s throttle until files exist).
  launchd.agents.litellm = {
    enable = true;
    config = {
      ProgramArguments = [ "${litellmStart}" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/Litellm/stdout";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/Litellm/stderr";
    };
  };

  # launchd opens the log paths before running the job: the directory must
  # already exist when the agent is bootstrapped.
  home.activation.litellmLogDir = lib.hm.dag.entryBefore [
    "setupLaunchAgents"
  ] "mkdir -p \"${config.home.homeDirectory}/Library/Logs/Litellm\"";
}
