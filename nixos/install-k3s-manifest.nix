{
  file,
  ...
} : 

{ 
  script = ''
    mkdir -p /var/lib/rancher/k8s/server/manifests;
    cp -fp ${file} /var/lib/rancher/k8s/server/manifests;
  '';
}
