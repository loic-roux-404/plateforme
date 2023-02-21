# 5. Allez plus loin

### FAQ

J'ai essayé plusieurs fois le provision de la vm avec des configurations différentes me forçant ainsi à apply / destroy la stack plusieurs fois. Cependant, maintenant je n'arrive plus à accéder à l'url avec une **erreur dns** ?

Il s'agit probablement du cache dns qui vous renvoi l'entrée ip d'une ancienne vm car le time to live n'a pas encore expiré. Pour cela dans chrome nous devons nettoyer ce cache pour faire comme si nous n'étions jamais aller sur le site.
Dans votre navigateur chrome [chrome://net-internals/#dns]() faites "un clear host cache" et réessayez.

Aussi on peut utiliser un flush cache global si cela ne fonctionne toujorus pas :
 
- [pour le dns de google](https://developers.google.com/speed/public-dns/cache?hl=fr)
- [pour le dns de cloudflare](https://1.1.1.1/purge-cache/)

> Pour faire des tests en cas réel, il est préférable d'utiliser des entrées `dex_hostname` et `kubeapps_hostname` différentes que vous n'utilisez pas pour un environnement (staging ou production).

### Kubernetes sur Vscode

Pour consolider le deboggage de notre environnement de dev ops nous pouvons intégrer notre cluster kubernetes dans l'IDE vscode.

Nous allons chercher la kubeconfig dans notre container qui embarque K3s et le cluster.
Récupérez l'identifiant du container avec :

```sh
docker ps | grep node-0 | awk '{print $1}'
# ex de retour 61a74719f7c4
```

Copier la kube config k3s avec :

```sh
docker cp 61a74719f7c4:/etc/rancher/k3s/k3s.yaml ~/.kube/config
```

Si vous n'avez pas kubectl en local :

- [Pour mac](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/)
- [Pour Wsl / Linux](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

On check ensuite avec `kubectl cluster-info` qui devrait nous donner les informations du node k3s.

##### Ensuite sur `vscode` utilisez ces paramètres utilisateur pour voir et utiliser le cluster

> Pour afficher le chemin vers home `cd ~ && pwd && cd -`

> [.vscode/settings.json](.vscode/settings.json)
```json
    "vs-kubernetes": {
        "vs-kubernetes.knownKubeconfigs": [
            "<Chemin-vers-home>/.kube/config"
        ],
        "vs-kubernetes.kubeconfig": "<Chemin-vers-home>/.kube/config"
    }
```

Et voilà vous avez accès à une interface pour contrôler votre cluster directement depuis vscode. Utiliser cette configuration `json` autant que vous voulez dans les repository de vos applications pour avoir une expérience au plus proche de la production.

# Sources

- [ansible docs](https://docs.ansible.com/)
- [base kubernetes](https://blog.bytebytego.com/p/ep35-what-is-kubernetes) Alex Xu
- [start kubeapps](https://github.com/vmware-tanzu/kubeapps/blob/main/site/content/docs/latest/tutorials/getting-started.md#step-3-start-the-kubeapps-dashboard)
- [oauth kubeapps](https://github.com/vmware-tanzu/kubeapps/blob/main/site/content/docs/latest/howto/OIDC/OAuth2OIDC-oauth2-proxy.md#manual-deployment)
_ [cert-manager annotation](https://cert-manager.io/docs/usage/ingress/#supported-annotations)
- [doc lets encrypt](https://letsencrypt.org/docs/)
- [pebble doc cert recover](https://github.com/letsencrypt/pebble#ca-root-and-intermediate-certificates)
- [open id docs from okta](https://developer.okta.com/docs/concepts/oauth-openid/)
- [dex k8s](https://dexidp.io/docs/kubernetes/)
- [dex github](https://dexidp.io/docs/connectors/github/)
- [k8s dns](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [dns debug kubernetes](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)
- [kubernetes open id doc](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)
- [terraform github](https://registry.terraform.io/providers/integrations/github/latest/docs)
- [terrform azure](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
- [doc azure](https://learn.microsoft.com/fr-fr/azure/)
- [helm chart releaser](https://github.com/helm/chart-releaser)
- [Github copilot](https://github.com/features/copilot)
- [Microservices et architecture monolithique](shorturl.at/FRTW5)
- [Postgres with Docker](https://geshan.com.np/blog/2021/12/docker-postgres/)
- [Communication microservices](https://blog.logrocket.com/methods-for-microservice-communication/)
