{ ... } : {
  system.activationScripts.tailscaleEnsureNotInstalled.text = ''
    kubectl delete ns tailscale || true
  '';
}
