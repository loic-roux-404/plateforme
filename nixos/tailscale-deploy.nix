{ config, pkgs, ... }: 

{
  services.tailscale.authKeyFile = config.sops.secrets.tailscaleNodeKey.path;
  services.tailscale.extraUpFlags = ["--ssh" "--accept-dns" ];

  sops.secrets.tailscaleNodeKey = {};
  sops.secrets.tailscaleNodeHostname = {};
  sops.secrets.tailscaleOauthClientId = {};
  sops.secrets.tailscaleOauthClientSecret = {};

  sops.templates."tailscale.yaml".content = ''
    apiVersion: helm.cattle.io/v1
    kind: HelmChart
    metadata:
      name: tailscale
      namespace: kube-system
    spec:
      repo: https://pkgs.tailscale.com/helmcharts
      chart: tailscale-operator
      targetNamespace: tailscale
      valuesContent: |
        operatorConfig:
          hostname: "k8s-operator-${config.sops.placeholder.tailscaleNodeHostname}"
        oauth:
          clientId: ${config.sops.placeholder.tailscaleOauthClientId}
          clientSecret: ${config.sops.placeholder.tailscaleOauthClientSecret}
        apiServerProxyConfig:
          mode: "true"
      waitForJobs: true
      waitForHelm: true
  '';

  system.activationScripts.tailscaleNamespace.text = (pkgs.callPackage ./install-k3s-manifest.nix { 
    inherit pkgs;
    manifest = {
      file = pkgs.writeText "tailscale-namespace.yaml" ''
        apiVersion: v1
        kind: Namespace
        metadata:
          name: tailscale
      '';
      condition = "jsonpath={.status.phase}=Active";
      toWait = "namespace/tailscale";
      namespace = "";
    };
  }).script;
  system.activationScripts.tailscaleOperator.deps = [ "renderSecrets" "tailscaleNamespace" ];
  system.activationScripts.tailscaleOperator.text = (pkgs.callPackage ./install-k3s-manifest.nix { 
    inherit pkgs;
    manifest = {
      file = config.sops.templates."tailscale.yaml".path;
      toWait = "deployment.apps/operator";
      namespace = "tailscale";
      condition = "condition=Available";
    };
  }).script;
}
