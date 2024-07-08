{ config, pkgs, lib, ... }: 

let manifests = [
  {
    file = config.sops.templates."tailscale.yaml".path;
    toWait = "deployment.apps/operator";
    namespace = "tailscale";
    condition = "condition=Available";
  } 
  {
    file = pkgs.writeText "tailscale-namespace.yaml" ''
      apiVersion: v1
      kind: Namespace
      metadata:
        name: tailscale
    '';
    condition = "jsonpath={.status.phase}=Active";
    toWait = "namespace/tailscale";
    namespace = "";
  }
];
in {
  services.tailscale.authKeyFile = config.sops.secrets.tailscale.path;
  services.tailscale.extraUpFlags = ["--ssh" "--hostname=${config.networking.hostName}"];

  system.activationScripts.tailscaleOperator.deps = [ "renderSecrets" ];
  system.activationScripts.tailscaleOperator.text = (pkgs.callPackage ./install-k3s-manifest.nix { 
    inherit lib pkgs manifests;
  }).script;

  sops.secrets.tailscale = {};
  sops.secrets.tailscale_oauth_client_id = {};
  sops.secrets.tailscale_oauth_client_secret = {};

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
        oauth:
          clientId: ${config.sops.placeholder.tailscale_oauth_client_id}
          clientSecret: ${config.sops.placeholder.tailscale_oauth_client_secret}
        apiServerProxyConfig:
          mode: "true"
      waitForJobs: true
      waitForHelm: true
  '';
}
