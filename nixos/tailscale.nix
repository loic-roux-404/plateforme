{ config, ... }: {
  sops.secrets.tailscale_oauth_client_id = {};
  sops.secrets.tailscale_oauth_client_secret = {};
  sops.templates."tailscale.yaml".content = ''
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
