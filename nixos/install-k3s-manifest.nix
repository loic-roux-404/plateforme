{
  pkgs,
  manifest,
  ...
} : 
with manifest;
let namespaceExpr = if namespace != "" then "-n ${namespace}" else ""; 
in { 
  script = ''
    mkdir -p /var/lib/rancher/k3s/server/manifests;
    cp -fp ${file} /var/lib/rancher/k3s/server/manifests;
    sleep 15;
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    ${pkgs.kubectl}/bin/kubectl wait --for='${condition}' ${toWait} ${namespaceExpr} --timeout=2m;
  '';
}
