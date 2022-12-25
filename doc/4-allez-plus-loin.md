## Allez plus loin

### FAQ

J'ai essayé plusieurs fois le provision de la vm avec des configurations différentes me forçant ainsi à apply / destroy la stack plusieurs fois. Cependant, maintenant je n'arrive plus à accèder à l'url avec une **erreur dns** ?

Il s'agit probablement du cache dns qui vous renvoi l'entrée ip d'une ancienne vm car le time to live n'a pas encore expiré. Pour cela dans chrome nous devons nettoyer ce cache pour faire comme si nous n'étions jamais aller sur le site.
Dans [chrome://net-internals/#dns]([chrome://net-internals/#dns]) faites un clear host cache et réessayez.

> Pour faire des tests en cas réel, il est préférable d'utiliser des entrées `dex_hostname` et `kubeapps_hostname` différentes que vous n'utlisez pas pour un environement (staging ou production).

### Exercice

Pour vérifier que vous avez bien compris, vous devez maintenant créer l'image packer d'un nouvel environnement staging. (Par défaut packer utilise le rôle configuré sur l'environnement `prod`). Utilisez cet environnement avec terraform pour provisionner une vm dans un nouveau groupe de ressource.

Il faudra bien veillez à créer les variables manquantes dans packer (nom image) et terraform (data source import image) pour que on puisse encore provisionner une machine de production.

# Sources

- [start](https://github.com/vmware-tanzu/kubeapps/blob/main/site/content/docs/latest/tutorials/getting-started.md#step-3-start-the-kubeapps-dashboard)
- [oauth](https://github.com/vmware-tanzu/kubeapps/blob/main/site/content/docs/latest/howto/OIDC/OAuth2OIDC-oauth2-proxy.md#manual-deployment)
_ https://cert-manager.io/docs/usage/ingress/#supported-annotations
_ https://medium.com/@int128/kubectl-with-openid-connect-43120b451672
- [pebble doc cert recover](https://github.com/letsencrypt/pebble#ca-root-and-intermediate-certificates)
