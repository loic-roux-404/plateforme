{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  # rtk-proxy: BUSL-1.1 release artifact separate from the Apache-2.0 rtk
  # CLI (nixpkgs `rtk`, home-manager.nix). Foreground server on
  # 127.0.0.1:8080; state lives in ~/Library/Application Support/rtk/
  # llm-proxy/. rtk finds it via PATH (profile bin dir shared with rtk);
  # it cannot sit next to rtk's immutable store path.
  # Release archives use Rust target triples, not nix system names.
  releaseTarget = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
  }.${pkgs.stdenv.hostPlatform.system};

  rtk-proxy = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "rtk-proxy";
    version = "1.2.0";

    src = pkgs.fetchurl {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-proxy-${releaseTarget}.tar.gz";
      hash = {
        "aarch64-darwin" = "sha256-VLdeaNHB8rC+qmMnaC4vIVtAZOCmmyOz828vELs2lRI=";
        "x86_64-darwin" = "sha256-M0s3VaZF9/ZnRE8G0LXC5akKW87lcaZKA0xxgdIltPU=";
      }.${pkgs.stdenv.hostPlatform.system};
    };

    # Flat tarball (no top-level dir): stdenv errors without an explicit
    # sourceRoot.
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      install -Dm755 rtk-proxy $out/bin/rtk-proxy
      runHook postInstall
    '';

    meta = with lib; {
      description = "RTK local LLM API proxy daemon";
      homepage = "https://www.rtk-ai.app/docs/proxy/overview/";
      license = licenses.unfree; # BUSL-1.1
      platforms = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      mainProgram = "rtk-proxy";
    };
  };
in
# Same gate as litellm.nix (example-wrapper users opt out of the AI stack).
lib.mkIf (osConfig.paas.aiStack.enable or true) {
  home.packages = [ rtk-proxy ];

  # User LaunchAgent like litellm: the proxy is single-user and keeps its
  # state/db under the user's home. This agent is the single owner of the
  # daemon — do not also run `rtk llm-proxy service`/`start` self-management
  # (KeepAlive would fight it / duplicate). `rtk llm-proxy stop` respawns
  # by design; deactivate the agent to stop it for good.
  launchd.agents.rtk-proxy = {
    enable = true;
    config = {
      ProgramArguments = [
        "${rtk-proxy}/bin/rtk-proxy"
        "start"
      ];
      # Chain behind litellm (litellm.nix litellmPort = 4000): rtk-proxy
      # normalises traffic, litellm stays the only provider-facing proxy
      # (AGENTS.md invariant).
      EnvironmentVariables = {
        RTK_PROXY_ANTHROPIC_UPSTREAM = "http://127.0.0.1:4000";
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/RtkProxy/stdout";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/RtkProxy/stderr";
    };
  };

  # launchd opens the log paths before running the job: the directory must
  # already exist when the agent is bootstrapped.
  home.activation.rtkProxyLogDir = lib.hm.dag.entryBefore [ "setupLaunchAgents" ] ''
    mkdir -p "${config.home.homeDirectory}/Library/Logs/RtkProxy"
  '';

  home.activation.rtkProxyRestart = lib.hm.dag.entryAfter [ "setupLaunchAgents" ] ''
    /bin/launchctl kickstart -k gui/$(/usr/bin/id -u)/org.nix-community.home.rtk-proxy \
      && echo "rtk-proxy: daemon restarted" \
      || echo "rtk-proxy: kickstart failed; rerun: launchctl kickstart -k gui/\$(/usr/bin/id -u)/org.nix-community.home.rtk-proxy" >&2
  '';
}
