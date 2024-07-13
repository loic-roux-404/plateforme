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
    sleep 30;
    ${pkgs.k3s}/bin/kubectl wait --for='${condition}' ${toWait} ${namespaceExpr} --timeout=2m;
  '';
}
