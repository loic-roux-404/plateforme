{
  lib,
  pkgs,
  manifests ? []
} : 
{ 
  script = "mkdir -p /var/lib/rancher/k3s/server/manifests;" +
    lib.strings.concatMapStrings (manifest: 
      with manifest; 
      let namespaceExpr = if namespace != "" then "-n ${namespace}" else ""; in 
      ''
        cp -fp ${file} /var/lib/rancher/k3s/server/manifests;
        ${pkgs.k3s}/bin/kubectl wait --for='${condition}' ${toWait} ${namespaceExpr} --timeout=2m;
      ''
    ) manifests;
}
