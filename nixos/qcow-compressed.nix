{ lib, pkgs, config, modulesPath, ...} : {
  imports = [
    "${toString modulesPath}/profiles/qemu-guest.nix"
  ];
  system.build.qcow = lib.mkForce (import "${toString modulesPath}/../lib/make-disk-image.nix" {
    inherit lib config pkgs;
    diskSize = 16384;
    format = "qcow2-compressed";
    partitionTableType = "hybrid";
  });
}
