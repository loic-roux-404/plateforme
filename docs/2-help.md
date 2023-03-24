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

## Sources

- [packer-kvm](https://github.com/goffinet/packer-kvm/blob/master/http/jammy/user-data)
- [coredns wildcard](https://mac-blog.org.ua/kubernetes-coredns-wildcard-ingress/)
