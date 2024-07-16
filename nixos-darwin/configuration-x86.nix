{
  pkgs, lib, ...
}: {
  nix.linux-builder = {
    package = lib.mkDefault pkgs.darwin.linux-builder-x86_64;
    ephemeral = lib.mkDefault true;
    systems = ["x86_64-linux"];
    config = lib.mkDefault ({ lib, ... }: { 
      nixpkgs.hostPlatform = lib.mkForce "x86_64-linux";
    });
  };
}
