{
  config,
  ...
}:
{

  sops = {
    secrets = {
      opencode_api_key = { };
    };

    templates."chatLanguageModels.json" = {
      path = "${config.home.homeDirectory}/Library/Application Support/Code/User/chatLanguageModels.json";
      content = builtins.toJSON [

        {
          name = "OpenCode";
          vendor = "customendpoint";
          apiKey = "\${input:chat.lm.secret.opencode}";
          apiType = "chat-completions";
          models = [
            {
              id = "kimi-k3";
              name = "Kimi K3";
              url = "https://opencode.ai/zen/go/v1/chat/completions";
              toolCalling = true;
              vision = true;
              maxInputTokens = 1048576;
              maxOutputTokens = 16384;
              reasoningEffortFormat = "chat-completions";
              supportsReasoningEffort = [
                "low"
                "medium"
                "high"
              ];
              streaming = true;
              thinking = true;
              modelOptions = {
                temperature = 0.1;
                top_p = 0.95;
              };
              requestHeaders = {
                Authorization = "Bearer ${config.sops.placeholder.opencode_api_key}";
              };
            }
            {
              id = "qwen3.8-max";
              name = "Qwen3.8 Max";
              reasoningEffortFormat = "chat-completions";
              supportsReasoningEffort = [
                "low"
                "medium"
              ];
              url = "https://opencode.ai/zen/go/v1/chat/completions";
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
              requestHeaders = {
                Authorization = "Bearer ${config.sops.placeholder.opencode_api_key}";
              };
            }
            {
              id = "deepseek-v4-flash";
              name = "DeepSeek v4 Flash";
              supportsReasoningEffort = [
                "low"
                "medium"
              ];
              reasoningEffortFormat = "chat-completions";
              url = "https://opencode.ai/zen/go/v1/chat/completions";
              toolCalling = true;
              vision = false;
              maxInputTokens = 1048576;
              maxOutputTokens = 8192;
              streaming = true;
              thinking = true;
              modelOptions = {
                temperature = 0.15;
                top_p = 0.9;
              };
              requestHeaders = {
                Authorization = "Bearer ${config.sops.placeholder.opencode_api_key}";
              };
            }
          ];
        }
      ];
    };
  };
}
