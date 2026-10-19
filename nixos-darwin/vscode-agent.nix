{
  config,
  ...
}:

let
  # All models are served by the local LiteLLM gateway (litellm.nix), which
  # proxies OpenCode Zen and the Z.ai GLM coding plan. The proxy runs without
  # a master key (localhost-only), so a static dummy bearer is enough; the
  # real provider keys live in the litellm agent's environment.
  #
  # The former x-opencode-session header (microsoft/vscode#334186 workaround)
  # is gone: VS Code now talks to litellm, not the zen gateway directly.
  proxyUrl = "http://127.0.0.1:4000/v1/chat/completions";
  proxyHeaders = {
    Authorization = "Bearer litellm-local";
  };
in
{
  sops = {
    templates."chatLanguageModels.json" = {
      path = "${config.home.homeDirectory}/Library/Application Support/Code/User/chatLanguageModels.json";
      content = builtins.toJSON [

        {
          name = "LiteLLM";
          vendor = "customendpoint";
          apiKey = "litellm-local";
          apiType = "chat-completions";
          models = [
            {
              id = "qwen3.8-max";
              name = "Qwen3.8 Max";
              reasoningEffortFormat = "chat-completions";
              supportsReasoningEffort = [
                "low"
                "medium"
              ];
              url = proxyUrl;
              toolCalling = true;
              vision = true;
              maxInputTokens = 1048576;
              maxOutputTokens = 16384;
              streaming = true;
              thinking = true;
              modelOptions = {
                temperature = 0.15;
                top_p = 0.9;
              };
              requestHeaders = proxyHeaders;
            }
            {
              id = "deepseek-v4.1-flash";
              name = "DeepSeek V4.1 Flash";
              supportsReasoningEffort = [
                "low"
                "high"
                "max"
              ];
              reasoningEffortFormat = "chat-completions";
              url = proxyUrl;
              toolCalling = true;
              vision = true;
              maxInputTokens = 1048576;
              maxOutputTokens = 16384;
              streaming = true;
              thinking = true;
              modelOptions = {
                temperature = 0.15;
                top_p = 0.9;
              };
              requestHeaders = proxyHeaders;
            }
            {
              id = "qwen3.8-flash";
              name = "Qwen3.8 Flash";
              supportsReasoningEffort = [
                "low"
                "medium"
                "xhigh"
              ];
              reasoningEffortFormat = "chat-completions";
              url = proxyUrl;
              toolCalling = true;
              vision = true;
              maxInputTokens = 1048576;
              maxOutputTokens = 131072;
              streaming = true;
              thinking = true;
              modelOptions = {
                temperature = 1.0;
                top_p = 0.95;
              };
              requestHeaders = proxyHeaders;
            }
            {
              id = "GLM-5.3-FLASH";
              name = "GLM-5.3 Flash";
              supportsReasoningEffort = [
                "low"
                "high"
                "max"
              ];
              reasoningEffortFormat = "chat-completions";
              url = proxyUrl;
              toolCalling = true;
              vision = false;
              maxInputTokens = 1048576;
              maxOutputTokens = 128000;
              streaming = true;
              thinking = true;
              modelOptions = {
                temperature = 1.0;
                top_p = 0.95;
              };
              requestHeaders = proxyHeaders;
            }
            {
              id = "GLM-5.3";
              name = "GLM-5.3";
              supportsReasoningEffort = [
                "low"
                "high"
                "max"
              ];
              reasoningEffortFormat = "chat-completions";
              url = proxyUrl;
              toolCalling = true;
              vision = false;
              maxInputTokens = 1048576;
              maxOutputTokens = 128000;
              streaming = true;
              thinking = true;
              modelOptions = {
                temperature = 1.0;
                top_p = 0.95;
              };
              requestHeaders = proxyHeaders;
            }
          ];
        }
      ];
    };
  };
}
