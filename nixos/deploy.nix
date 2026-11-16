{ lib, config, pkgs, ... } :

with config.paas;
{
  # Pebble root CA (local env, public cert, tracked at nixos/pebble-root-ca.pem):
  # imported into the host trust store so apiserver OIDC discovery accepts the
  # pebble-issued dex ingress cert. Must be a BUILD-time file — buildcatrust
  # reads certificateFiles during nixos-rebuild build, before any sops secret
  # exists on the node (a sops path here fails the rebuild).
  # Refresh after a pebble CA rotation:
  #   curl -sk https://192.168.2.1:15000/roots/0 > nixos/pebble-root-ca.pem
  security.pki.certificateFiles =
    lib.mkIf config.paas.kube.importLocalAcmeCa
      [ ./pebble-root-ca.pem ];

  # networking.hostName = "localhost-0";

  users.users.${user.name}.hashedPasswordFile = config.sops.secrets.password.path;
  users.users.root.hashedPasswordFile = config.sops.secrets.password.path;

  sops.validateSopsFiles = false;
  sops.defaultSopsFormat = "yaml";
  sops.defaultSopsFile = "/home/${user.name}/secrets.yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" "${config.sops.secrets.nodePrivateKey.path}" ];

  sops.secrets = {
    nodeIp = {};
    nodePrivateKey = {
      neededForUsers = true;
    };
    paasDomain = {};
    password = { neededForUsers = true; };
    dexClientId = {};
    githubActionsDexClientId = {};
  };

  services.rke2.configPath = lib.mkForce config.sops.templates."config.yaml".path;

  # rke2 reads its config only at start: without this the phase-2 switch
  # (bootstrap → oidc attr) updates the rendered file but the apiserver keeps
  # running with the old config. Trigger on a store path derived from the
  # template CONTENT (restartTriggers compare paths, not file contents).
  systemd.services.rke2-server.restartTriggers = [
    (pkgs.writeText "rke2-server-config" config.sops.templates."config.yaml".content)
  ];

  networking = {
    useNetworkd = true;
    nameservers = [ 
      "1.1.1.1" 
      "1.0.0.1"
      "2606:4700:4700::1111" 
      "2606:4700:4700::1001" 
      "8.8.8.8" 
      "8.8.4.4" 
      "001:4860:4860::8844" 
      "2001:4860:4860::8888"
    ];
  };

  # Structured apiserver authn (dex JWT). Gated: on a fresh local node the
  # issuer is unreachable (dex ships with the paas layer) and a failing OIDC
  # authenticator breaks ALL pod service-account token authn (rke2-canal
  # CrashLoopBackOff, node NotReady). Local bootstrap uses the
  # `deploy-bootstrap` flake attr with the flag off, then re-deploys `deploy`.
  sops.templates."apiserver-auth-config.yaml" =
    lib.mkIf config.paas.kube.apiserverOidcAuthn
      { content = ''
          apiVersion: apiserver.config.k8s.io/v1beta1
          kind: AuthenticationConfiguration
          jwt:
            - issuer:
                url: https://dex.${config.sops.placeholder.paasDomain}
                audiences:
                  - ${config.sops.placeholder.dexClientId}
                  - ${config.sops.placeholder.githubActionsDexClientId}
                audienceMatchPolicy: MatchAny
${lib.optionalString config.paas.kube.importLocalAcmeCa (
  "                certificateAuthority: |\n"
  + lib.concatMapStrings (l: "                  ${l}\n")
    (lib.splitString "\n" (lib.trim (builtins.readFile ./pebble-root-ca.pem)))
)}
              claimMappings:
                username:
                  prefix: ""
                  claim: email
                groups:
                  prefix: ""
                  claim: groups
        ''; };

  sops.templates."config.yaml".content = ''
    with-node-id: true
    # MUST be explicit: the initial image boots rke2 with cluster-domain
    # ${dns.name} (legacy defaultKubeDistribConfigPath). Dropping it here made
    # kube-controller-manager mint SA tokens with iss svc.${dns.name} while the
    # apiserver only trusted svc.cluster.local → "invalid bearer token" for
    # every pod token (calico CNI 401, sandboxes stuck ContainerCreating).
    cluster-domain: ${dns.name}
    advertise-address: ${config.sops.placeholder.nodeIp}
    node-external-ip: "${config.sops.placeholder.nodeIp}"
    cluster-cidr: ${kube.podCIDR}
    service-cidr: ${kube.serviceCIDR}
    node-taint:
      - "CriticalAddonsOnly=true:NoExecute"
    tls-san:
      - "${kube.serviceIp}"
      # - "${config.networking.hostName}" perhaps re enable once wireguard is ready.
      - "${config.sops.placeholder.nodeIp}"
      - "${config.sops.placeholder.paasDomain}"
    ${lib.optionalString config.paas.kube.apiserverOidcAuthn ''
      kube-apiserver-extra-mount:
         - '${config.sops.templates."apiserver-auth-config.yaml".path}:/etc/apiserver-auth-config.yaml:ro'
      kube-apiserver-arg=authentication-config: "/etc/apiserver-auth-config.yaml"
    ''}
  '';
}
