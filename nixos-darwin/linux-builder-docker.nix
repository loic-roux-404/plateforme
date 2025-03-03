{ pkgs, ... }: {
  nix.linux-builder.package = pkgs.darwin.linux-builder;
  nix.linux-builder.ephemeral = false;
  nix.linux-builder.config = ({ lib, ... }: {
    virtualisation.docker.enable = true;
    virtualisation.docker.daemon.settings = {
      hosts = [ "tcp://0.0.0.0:2375" ];
    };
    networking.firewall.enable = lib.mkForce false;
    networking.firewall.allowedTCPPorts = [ 2375 ];
    virtualisation.forwardPorts = lib.mkForce [
      { from = "host"; guest.port = 22; host.port = 31022; }
      { from = "host"; guest.port = 2375; host.port = 2375; }
    ];
    security.sudo.wheelNeedsPassword = false;
    users.users.builder.extraGroups = lib.mkForce [ "docker" "wheel" ];
  });
}
