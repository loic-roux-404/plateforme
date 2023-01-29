# 1.5 Mise en place des communications réseau du cluster

---

Pour détailler sur cette partie essentielle à la bonne compréhension des applications distribuées sur kubernetes on parlera du **dns**.

Dans notre stack on a besoin de deux serveurs de nom, soit un interne **coredns** disponible uniquement dans kubernetes et ses ressources et un serveur de nom global (qui peut être celui d'internet et le réseau local).

### Dnsmasq pour résoudre les noms de domaines en local

L'objectif va être de pouvoir utiliser des domaines de test en local. Par exemple on veut utiliser `dex.k3s.local` pour accéder à l'authentification de notre cluster kubernetes.

L'installation sur **mac** est un peu différente de celle de Linux là voici pour commencer :

- `brew install dnsmasq` (si vous n'avez pas encore Homebrew c'est [ici pour l'installer](https://brew.sh/index_fr))

- Créer le répertoire des configurations `mkdir -pv $(brew --prefix)/etc/`

- Préparer une variable pointant vers la config dnsmasq :

```sh
export DNSMASQ_CNF_DIR="$(brew --prefix)/etc/dnsmasq.conf"
```

Pour **Linux** :

- Commencer par désactiver le résolveur par défaut qui écoute sur le port `53`
```sh
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved
```

- Supprimer la configuration du résolveur par défaut

```sh
ls -lh /etc/resolv.conf
sudo rm /etc/resolv.conf
```

- Installer le package : `sudo apt install -y dnsmasq`

- Préparer une variable pointant vers la config dnsmasq pour l'étape suivante :

```sh
export DNSMASQ_CNF_DIR="/etc/dnsmasq.conf"
```

Pour **Linux** et **Mac** mettons ainsi tout en place :

- On précise bien que l'on veut résoudre toute les requètes vers le domaine `.dev` avec l'adresse IP 127.0.0.1 : 

```sh
echo 'port=53' >> $DNSMASQ_CNF_DIR
echo 'address=/.k3s.local/127.0.0.1' >> $DNSMASQ_CNF_DIR
```

- On ajoute un resolveur avec :

```sh
sudo mkdir -v /etc/resolver
echo "nameserver 127.0.0.1" | sudo tee -a /etc/resolver/local
```

Redémarrer dnsmasq :

- Linux : `sudo systemctl restart dnsmasq`
- Mac : `sudo brew services restart dnsmasq`

Vérifier que tout fonctionne avec `scutil --dns` qui devrait donner :

```txt
resolver ...
  domain   : local
  nameserver[0] : 127.0.0.1
```

### Edition de coredns pour utiliser les url externes

Par défaut notre réseau est privée dans kubernetes, on ne peut accéder qu'aux serveurs de nom les plus répandus comme google (8.8.8.8) ou cloudflare (1.1.1.1) et celui de `coredns`. Cela veut dire que l'on accède seulement à internet et à nos pods mais nous avons ici besoin d'accéder à pebble situé sur le réseau local.

> **Note** : **Coredns** est l'outil qui fait office d'un des services coeurs de kubernetes au même titre que kube-controller-manager par exemple. Ici il va donc s'agir du composant kube-dns.

On va donc se préparer à surcharger la configuration par défaut de coredns en appliquant un simple manifest de type `ConfigMap`. Ce type permet de simplement définir des variables ou le contenu d'un fichier. Ici on va décrire le contenu d'un fichier `Corefile` qui va être monté au travers d'un volume au container coredns.

Voici la configuration par défaut :

```yaml linenums="1" title="playbook/roles/kubeapps/templates/core-dns-config-crd.yml.j2"

apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
          lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
          ttl 30
        }
        prometheus :9153
        forward . 1.1.1.1
        cache 30
        loop
        reload
        loadbalance
    }
```

Le ingress **en local** n'est pas accessible depuis nos pods, nous allons donc avoir besoin de son ip pour l'associer aux différents noms de domaines que l'on va utiliser. (`dex.k3s.local` / `kubeapps.k3s.local`).

Nous allons ainsi créer une nouvelle suite de tâche pour déduire les adresses réseau requises pour coredns.

On crée un fichier `tasks/internal-acme.yml` présentant ce code pour récupérer l'addresse ip de l'ingress à l'aide du module `k8s_info` d'ansible :

```yaml linenums="1" title="playbook/roles/kubeapps/tasks/internal-acme.yml"
---
- name: Get Ingress service infos
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Service
    name: traefik
    kubeconfig: /etc/rancher/k3s/k3s.yaml
    wait: yes
    namespace: kube-system
  register: ingress_infos

- name: check ingress service infos available
  assert:
    that:
      - ingress_infos.resources | length > 0

- name: Set localhost ip to find local acme
  set_fact:
    kubeapps_ingress_controller_ip: "{{ ingress_infos.resources[0].spec.clusterIP }}"


```

Puis on l'utilise dans nos tâches seulement quand on précise que l'on utilise un acme interne ou spécifique (par exemple on peut utiliser un acme staging externe) :

```yaml linenums="1" title="playbook/roles/kubeapps/tasks/main.yml"
- import_tasks: internal-acme.yml
  when: kubeapps_internal_acme_network_ip is not none
  tags: [kubeapps]

```

Maintenant la variable `kubeapps_ingress_controller_ip` est disponible et prête à être associé à une entrée dns. Cette variable nous sert à détecter que nous sommes bien en local

Venons en donc à la définition des noms d'hôte des applications 

> Ils seront déployés dans les étapes suivantes donc n'essayer pas d'y accéder pour l'instant.

En sachant que le principe de base d'un dns est d'associé une adresse ip à un nom de domaine, nous allons simplement associés les deux addresses `k3s.local` hériteé de notre dns local (dnsmasq) vers le ingress. Ainsi le trafic interne comme externe en direction de ces adresses arrivera bien au même endroit.

> **WARN** Nous faisons cela en réseau local, mais si notre serveur est en ligne nous ne serons pas obligé de le faire car on passera par des dns centraux (typiquement google, cloudflare...) capable de résoudre notre nom de domaines public et ses sous domaines.

Avant de surcharger la configuration de coredns on va juste définir les variables avec les noms de domaines que l'on va utiliser.

> **Note**: Il n'est pas obligé de faire cela tout de suite en sachant que le fichier sera redonné en entier dans une prochaine partie.

```yaml linenums="1" title="playbook/roles/kubeapps/defaults/main.yml"
kubeapps_user: "{{ ansible_user | d('root') }}"
kubeapps_internal_acme_host: acme-internal.k3s.local
dex_hostname: dex.k3s.local
kubeapps_hostname: kubeapps.k3s.local

```

> `kubeapps_user` est définit à `ansible_user` une variable selon les conventions précisée dans un playbook de production dans le fichier host. Par défaut on le met à `root` si la variable n'existe pas.

[playbook/roles/kubeapps/templates/core-dns-config-crd.yml.j2](playbook/roles/kubeapps/templates/core-dns-config-crd.yml.j2#L28)

```conf linenums="28" title="playbook/roles/kubeapps/templates/core-dns-config-crd.yml.j2"
    {% set ingress_hosts_internals = [dex_hostname, kubeapps_hostname] | join(" ") -%}

    {{ ingress_hosts_internals }} {
      hosts {
        {{ kubeapps_ingress_controller_ip }} {{ ingress_hosts_internals }}
        fallthrough
      }
      whoami
    }
```

Enfin on configure l'addresse de notre acme interne pour que l'étape suivante puisse bien accèder à nos urls et que l'outil cert-manager puisse accèder à ce serveur acme.

```conf linenums="32" title="playbook/roles/kubeapps/templates/core-dns-config-crd.yml.j2"

    {{ kubeapps_internal_acme_host }} {
      hosts {
        {{ kubeapps_internal_acme_network_ip }} {{ kubeapps_internal_acme_host }}
        fallthrough
      }
      whoami
    }

```

Ainsi nous sommes prêt à faire fonctionner notre acme en local pour les tests. Cependant dans des environnement disponible sur internet nous n'allons pas activé cette partie. Nous réutilisons donc la variable `kubeapps_ingress_controller_ip` créer dynamiquement dans `internal-acme.yml` pour installer ou non le manifest kubernetes.

```yaml linenums="15" title="playbook/roles/kubeapps/tasks/main.yml"
  loop:
    - src: core-dns-config-crd.yml
      condition: "{{ kubeapps_ingress_controller_ip is defined }}"
   
```

---
