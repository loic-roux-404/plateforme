{
  pkgs, lib, ...
}: {
  nix.settings.extra-platforms = [ "x86_64-linux" ];
  nix.linux-builder = {
    package = pkgs.darwin.linux-builder-x86_64;
    ephemeral = lib.mkDefault true;
    systems = ["x86_64-linux"];
    config = lib.mkDefault ({ lib, ... }: {
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
      nixpkgs.hostPlatform = lib.mkForce "x86_64-linux";
      security.sudo.wheelNeedsPassword = false;
      users.users.builder.extraGroups = [ "wheel" ];
    });
  };
}
