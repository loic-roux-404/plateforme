{ lib, ... }: {
  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings = {
    hosts = [ "tcp://0.0.0.0:2375" ];
  };
  networking.firewall.enable = lib.mkForce false;
  virtualisation.forwardPorts = lib.mkForce [
    { from = "host"; guest.port = 22; host.port = 31022; }
    { from = "host"; guest.port = 2375; host.port = 2375; }
  ];
  virtualisation.rosetta.enable = true;
  nix.settings.extra-platforms = [ "x86_64-linux" ];
  security.sudo.wheelNeedsPassword = false;
  users.users.builder.extraGroups = lib.mkForce [ "docker" "wheel" ];
}
