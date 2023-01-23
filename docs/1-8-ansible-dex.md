# 1.8 Authentification et des habilitations

---

Il est inclus dans kubernetes deux façons d'authentifier les utilisateurs au cluster et ses resources api (`services`, `pods`, `secrets`...) :

- Les Services accounts utilisés pour authentifier des processus qui se lancent dans les pods. Ils s'utilisent avec un simple token et des droits rattachés.

- Users et Groups (comme pour linux). Ces ressources sont créé implicitement par un client Open-id Connect fourni sous réserve d'activation par kubernetes.
On optera pour cette méthode en utilisant comme serveur open id : **dex** idp qui consomme plusieurs fournisseurs d'accès externes (ou interne).


### 1. Configuration de notre organisation github et application oauth

Créer une nouvelle organisation [ici](https://github.com/account/organizations/new) :

- Sélectionner le "free plan"
- Choisissez un nom à l'organisation
- Renseignez votre email
- Cocher bien qu'elle vous appartient (rattaché à votre pseudo github)

> On peut créer une équipe particulière dans notre organisation qui pourra avoir accès à kubeapps. Le Lien vers le formulaire de création ressemble à ça : https://github.com/orgs/nom-de-ton-organisation/new-team.

Nommez-les comme vous voulez puis ajoutez la variable dans votre playbook de test (non conseillé en production, utilisez plutôt ansible-vault) :

```yaml linenums="14" title="playbook/roles/kubeapps/molecule/default/converge.yml"
    dex_github_client_org: "esgi-lyon"
    dex_github_client_team: "ops-team-test"
```

#### Créer l'application github

[créer votre application ici](https://github.com/organizations/<my-org>/settings/applications/new)

Configuré la comme ceci **pour l'instant** en utilisant les url en local qui ne fonctionnerons pas (pas de tls activé / ni online)

- Application name : `kubeapps-test`
- Homepage URL : `https://kubeapps.k3s.local`
- Authorization callback URL : `https://dex.k3s.local/callback`

Ensuite noté bien votre **Client Id** et générer un nouveau **Client secret** en plus.

#### Encrypter les secrets de l'application github

Nous allons crypter les Informations dangereuses dans un vault ansible que l'on pourra créer avec :

Dans votre rôle `playbook/roles/kubeapps`

```bash
ansible-vault create --vault-password-file $HOME/.ansible/.vault molecule/default/group_vars/molecule/secrets.yml
```

Renseigner un mot de passe dans le fichier `$HOME/.ansible/.vault`.

> **Warning** : Ce mot de passe est utilisé pour décrypter les secrets de votre playbook de test. Il est donc important de le garder secret d'où une localisation à l'extérieur du repo.

> **Warning** Il est aussi recommandé de le stocker en double dans un gestionnaire de mot de passe ou autre gestionnaire de secret perfectionné (Github action, Hashicorp vault...)

Vous devrez ensuite renseigner ces secrets afin de cacher les informations sensibles dans votre playbook de test.

```yaml linenums="1" title="playbook/roles/kubeapps/molecule/default/group_vars/molecule/secrets.yml"
cert_manager_email: test4@k3s.local

dex_github_client_id: "my-client-id-from-github-oauth-app"
dex_github_client_secret: "my-client-secret-from-github-oauth-app"

```

Si besoin vous pouvez éditer le fichier avec la commande suivante :

```bash
ansible-vault edit molecule/default/group_vars/molecule/secrets.yml --vault-password-file $HOME/.ansible/.vault
```

> Note : les **github secrets** de la CI/CD de github [https://github.com/domaine/repo/settings/secrets/actions](#) peuvent être une localisation idéale.

Vous aviez créé un mot de passe, mais ce n'est pas très pratique de devoir le retenir. Déplacez-le dans un fichier `${HOME}/.ansible/.vault` pour pouvoir ouvrir les fichiers de secrets cryptés plus facilement les prochaines fois. (argument de ligne de commande `--vault-password-file`)

```bash
echo 'my-pass' > $HOME/.ansible/.vault
```

> Warning : en bash `>` écrase le fichier et `>>` ajoute à la fin du fichier. L'idéal est d'utiliser la commande `tee` à la place de ces opérandes.

Puis on configure molecule pour utiliser le fichier de mot de passe et le groupe de variable **`molecule`** qui contient nos secrets. Il est implicitement défini quand on crée le dossier `group_vars/molecule`:

Dans votre configuration de plateforme de test molecule `node-0` :

```yaml linenums="12" title="playbook/roles/kubeapps/molecule/default/molecule.yml"
    groups:
      - molecule
```

Puis on configure le provisioner ansible pour utiliser le fichier de mot de passe :

```yaml linenums="22" title="playbook/roles/kubeapps/molecule/default/molecule.yml"
provisioner:
  name: ansible
  config_options:
    defaults:
      vault_password_file: ${HOME}/.ansible/.vault
```

Voilà, maintenant molecule importe les secrets et les rend disponible dans les variables ansible.

#### Installation et configuration

D'abord comme vu précédemment avec cert-manager on créer les variables par défaut requises par dex :

D'abord des informations globales comme l'espace de nom kubernetes et l'url par lequel on peut accéder au service.

```yaml linenums="16" title="playbook/roles/kubeapps/defaults/main.yml"
# HelmChart Custom Resource Definition for dex oidc connector
dex_namespace: dex
dex_hostname: dex.k3s.local
```

Ensuite on précise les informations de connexion à github ainsi que les celles qui permettrons au client de notre openid de se connecter. On laisse ces informations à null dans un but de documentation.

> On prend un raccourci avec le secret, mais dans l'inventaire ansible final on renseignera des secrets plus sécurisés.

```yaml
dex_client_id: kubeapps
dex_client_secret: ~
dex_github_client_id: ~
dex_github_client_secret: ~
dex_github_client_org: ~
dex_github_client_team: ~
```
> **INFO** Le client open id est ici kubeapps. Pour résumé après ce schéma, kubeapps se sert du **claim open id** `groups` (qui aura ici comme valeur `esgi-lyon:ops-team`) renvoyé par dex pour accéder aux ressources du cluster autorisées par son rôle.

Voici un schéma pour imager comment ce claim open id va servir à sécuriser l'attribution des droits en plus de la connection au cluster.

```
---|   |--------|        |------- |                      |----------|
   |   |kubeapps|-- ask->| dex    |--convert request---->| Github   |
k3s|<--|        |<-------| openid |                      | oauth2   |
---|   |--------|--------|--------|<-esgi-lyon:ops-team--|----------|
                         
```

> **Warning** Le `dex_client_secret` par défaut n'est pas du tout sécurisé et doit être changé en production

Ensuite, définissons un manifest utilisant helm pour installer facilement dex sur le cluster kubernetes. Implicitement seront créer des fichiers d'attributions de droit au cluster, le fichier de déploiement des pod et les services exposants des noms et adresses dans le cluster.

On commence par créer le namespace

```yaml linenums="1" title="playbook/roles/kubeapps/templates/dex-chart-crd.yml.j2"
apiVersion: v1
kind: Namespace
metadata:
  name: {{ dex_namespace }}
```

Puis on installe le chart helm de dex comme d'habitude avec ce genre de manifest :

```yaml linenums="6" title="playbook/roles/kubeapps/templates/dex-chart-crd.yml.j2"
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: dex
  namespace: kube-system
spec:
  chart: dex
  targetNamespace: {{ dex_namespace }}
  repo: https://charts.dexidp.io
```

Dans le `valuesContent` nous allons renseigner trois principaux objets de configuration :

**`config`** qui configure l'application web dex avec :
  - Le `issuer` est l'url de base de dex. Il est utilisé pour construire les urls de redirection et de callback.
  - Le connecteur github
  - Les informations de stockage, 
  - L'hôte et le port interne sur lequel le serveur web écoute et 
  - Le client openid pour donner le droit à kubeapps de consommer l'authentification de dex

Voici la configuration qui réutilise les variables de notre application oauth github et les credentials définies dans les defaults et le playbook converge.yml :

```yaml linenums="15" title="playbook/roles/kubeapps/templates/dex-chart-crd.yml.j2"
  valuesContent: |-
    config:
      issuer: "https://{{ dex_hostname }}"
      web:
        http: 0.0.0.0:5556
      storage:
        type: kubernetes
        config:
          inCluster: true
      connectors:
      - type: github
        id: github
        name: GitHub
        config:
          clientID: '{{ dex_github_client_id }}'
          clientSecret: '{{ dex_github_client_secret }}'
          redirectURI: "https://{{ dex_hostname }}/callback"
          orgs:
          - name: '{{ dex_github_client_org }}'
            teams: 
            - '{{ dex_github_client_team }}'
      oauth2:
        skipApprovalScreen: true
      staticClients:
      - id: "{{ dex_client_id }}"
        redirectURIs:
        - 'https://{{ kubeapps_hostname }}/oauth2/callback'
        name: 'Kubeapps'
        secret: "{{ dex_client_secret }}"
```

Ensuite on configure le ingress pour que dex soit accessible depuis l'extérieur du cluster. 

Pour cela on renseigne des d'hôtes pour lesquels les requêtes amènerons bien au **service** dex (port 5556).

Un **servive** kubernetes est toujours créer en accompagnement d'un **déploiement** et se voit automatiquement attribué une addresse ip interne. Ici le service sera de type `clusterIp`.

Voici la commande pour consulter le service et son adresse ip :

```bash
kubectl get svc -n dex -o yaml
```

qui nous donne le manifest complet avec tous les labels et annotations générés par helm et kubernetes :

```yaml
kind: Service
  metadata:
    annotations:
      meta.helm.sh/release-name: dex
      meta.helm.sh/release-namespace: dex
    creationTimestamp: "2022-12-10T17:12:50Z"
    labels:
      app.kubernetes.io/instance: dex
      app.kubernetes.io/managed-by: Helm
      app.kubernetes.io/name: dex
      app.kubernetes.io/version: 2.35.3
      helm.sh/chart: dex-0.12.1
    name: dex
    namespace: dex
    resourceVersion: "1159"
    uid: c88f2dcb-85d0-4f74-bdeb-4e53b964d5b5
  spec:
    clusterIP: 10.43.12.126
    clusterIPs:
    - 10.43.12.126
    ipFamilies:
    - IPv4
    ipFamilyPolicy: SingleStack
    ports:
    - appProtocol: http
      name: http
      port: 5556
      protocol: TCP
      targetPort: http
    - appProtocol: http
      name: telemetry
      port: 5558
      protocol: TCP
      targetPort: telemetry
    selector:
      app.kubernetes.io/instance: dex
      app.kubernetes.io/name: dex
    sessionAffinity: None
    type: ClusterIP
  status:
    loadBalancer: {}
```

Ensuite on met en place le ingress pour associer les noms d'hôtes à ce service pour le trafic externe. (reverse proxy)

On utilise ici le certificat délivré par cert-manager au travers d'un secret `{{ dex_hostname }}-tls` automatiquement créer par l'issuer cert-manager activé avec : `cert-manager.io/cluster-issuer: letsencrypt-acme-issuer`.

```yaml linenums="44" title="playbook/roles/kubeapps/templates/dex-chart-crd.yml.j2"
    ingress:
      enabled: true
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-acme-issuer
        kubernetes.io/ingress.class: "{{ kubeapps_k8s_ingress_class }}"
        traefik.frontend.passHostHeader: "true"
        traefik.ingress.kubernetes.io/router.tls: "true"
      hosts:
      - host: {{ dex_hostname }}
        paths:
          - path: /
            pathType: ImplementationSpecific
      tls:
        - secretName: {{ dex_hostname }}-tls
          hosts:
            - {{ dex_hostname }}
```

> Note: `traefik.ingress.kubernetes.io/router.tls: "true"` est nécessaire pour que traefik redirige les requêtes http vers https.

Enfin le plus important, il faut intégrer dex dans le flux d'authentification de kubernetes. Pour cela on active le plugin oidc avec de nouveau argument de configuration de k3s.

On ajoute donc les variables dans le fichier meta du rôle pour influencer l'installation de k3s avec ces variables. C'est la principale raison de l'utilisation de la pré-tâche `playbook/roles/kubeapps/tasks/pre-import-cert.yml` du certificat avant le rôle.

```yaml linenums="53" title="playbook/roles/kubeapps/meta/main.yml"
    vars:
      k3s_release_version: v1.21
      k3s_server:
        kube-apiserver-arg=authorization-mode: Node,RBAC
        kube-apiserver-arg=oidc-issuer-url: "https://{{ dex_hostname }}"
        kube-apiserver-arg=oidc-client-id: "{{ dex_client_id }}"
        kube-apiserver-arg=oidc-username-claim: email
        kube-apiserver-arg=oidc-groups-claim: groups

```

Open id configuré sur kubernetes nous sommes prêt à faire fonctionner kubeapps avec dex car ils peuvent maintenant communiquer en Tls entre eux et dex peut autoriser des connexion open id valides à contrôler k3s.

---
