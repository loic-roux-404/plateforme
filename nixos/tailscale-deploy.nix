{ config, pkgs, lib, ... }: 

let manifests = [{
  file = config.sops.templates."tailscale.yaml".path;
  toWait = "deployment/operator";
  namespace = "tailscale";
}];
in {
  services.tailscale.authKeyFile = config.sops.secrets.tailscale.path;
  services.tailscale.extraUpFlags = ["--ssh" "--hostname=${config.networking.hostName}"];

  system.activationScripts.tailscaleOperator.deps = [ "renderSecrets" ];
  system.activationScripts.tailscaleOperator.text = "mkdir -p /var/lib/rancher/k3s/server/manifests;" +
    lib.strings.concatMapStrings (manifest: ''
      cp -fp ${manifest.file} /var/lib/rancher/k3s/server/manifests;
          ${pkgs.k3s}/bin/k3s kubectl rollout status ${manifest.toWait} -n ${manifest.file} --timeout=5m;
    '') manifests;

  sops.secrets.tailscale = {};
  sops.secrets.tailscale_oauth_client_id = {};
  sops.secrets.tailscale_oauth_client_secret = {};
  sops.templates."tailscale.yaml".content = ''
    ---
    apiVersion: v1
    kind: Namespace
    metadata:
      name: tailscale

    ---
    apiVersion: helm.cattle.io/v1
    kind: HelmChart
    metadata:
      name: tailscale
      namespace: kube-system
    spec:
      chart: https://pkgs.tailscale.com/helmcharts/tailscale-operator
      targetNamespace: tailscale
      set:
        oauth.clientId: ${config.sops.placeholder.tailscale_oauth_client_id}
        oauth.clientSecret: ${config.sops.placeholder.tailscale_oauth_client_secret}
        apiServerProxyConfig.mode: "true"
      waitForJobs: true
      waitForHelm: true
  '';
}
