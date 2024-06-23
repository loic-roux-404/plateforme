{ config, lib, pkgs, ... } : 

with config.k3s-paas;

let manifests = [{
  file = config.sops.templates."tailscale.yaml".path;
  toWait = "deployment/operator";
  namespace = "tailscale";
}];
in {
  imports = [ ./temporary-configuration.nix ];

  system.activationScripts.k3s-tailscale.text = "mkdir -p /var/lib/rancher/k3s/server/manifests;"
  + lib.strings.concatMapStrings (manifest: ''
    cp -fp ${manifest.file} /var/lib/rancher/k3s/server/manifests;
    ${pkgs.k3s}/bin/k3s kubectl rollout status ${manifest.toWait} -n ${manifest.file} --timeout=5m;
  '') manifests;

  systemd.user.services.k3s.Unit.After = [ "sops-nix.service" ];
  systemd.user.services.tailscale.Environment = {
    HTTP_PROXY = "http://localhost:1055/";
    http_proxy = "http://localhost:1055/";
  };
  systemd.user.services.tailscale.Unit.After = [ "sops-nix.service" ];

  sops.validateSopsFiles = false;
  sops.defaultSopsFormat = "yaml";
  sops.defaultSopsFile = "/home/${user.name}/secrets.yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets.tailscale = {};
  sops.secrets.password = {
    neededForUsers = true;
  };

  services.tailscale.authKeyFile = config.sops.secrets.tailscale.path;
  services.tailscale.extraUpFlags = ["--ssh" "--hostname=${config.networking.hostName}"];

  users.users.${user.name}.hashedPasswordFile = config.sops.secrets.password.path;
}
