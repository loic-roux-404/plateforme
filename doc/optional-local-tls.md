### E. Tls sur kubernetes en local

La tâche **Mkcert** va nous permettre d'activer en local le https en TLS. Cela va nous permettre d'avoir une expérience encore plus proche de la réalité de la production.

Pour l'installer :

- **Linux** :

> Renseigner bien `arm64` à la place de `amd64` si vous possèder ce genre de processeur

```sh
wget https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64
sudo mv mkcert-v1.4.4-linux-amd64 /usr/local/bin/mkcert && chmod +x /usr/local/bin/mkcert
```

- **Mac** : `brew install mkcert`

Ensuite générons les certificats pour activer https sur tous les domaines finissant par `k3s.localhost`

```
mkdir certs/
echo 'certs/*
!.gitkeep' >> .gitignore # we don't want to commit auto-signed certs
mkcert -install
mkcert -cert-file certs/local-cert.pem -key-file certs/local-key.pem "k3s.localhost" "*.k3s.localhost" 
```

https://blog.stephane-robert.info/post/homelab-ingress-k3s-certificats-self-signed/
