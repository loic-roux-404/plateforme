{
  file,
  ...
} : 

{ 
  script = ''
    mkdir -p /var/lib/rancher/k3s/server/manifests;
    cp -fp ${file} /var/lib/rancher/k3s/server/manifests;
  '';
}
