#### Add self signed cert to accepted

> Mac OS

```sh
echo | openssl s_client -servername kubeapps.svc.test -connect kubeapps.k3s.local:443 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > certificate.crt

# For mac users
sudo security authorizationdb read com.apple.trust-settings.admin > /tmp/security.plist; 
sudo security authorizationdb write com.apple.trust-settings.admin allow; 
sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain $(pwd)/certificate.crt; 
sudo security authorizationdb write com.apple.trust-settings.admin < /tmp/security.plist;
rm -f /tmp/security.plist
rm -f $(pwd)/certificate.crt

```
