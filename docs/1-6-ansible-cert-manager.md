# 1.6 Utiliser notre autorité avec cert-manager

---

Venons en à l'élement central de notre stack, `cert-manager`. Il va nous permettre de créer des certificats pour nos services kubernetes.

Cert-manager permet d'utiliser les protocoles acme embarqué dans des outils comme Pebble. Il permet de créer des certificats pour des services http, dns et mTLS.
On l'utilisera avec Pebble pour distribuer les certificats vers les **ingress** avec des ressources secrets contenant respectivement le certificat et la clé de déchiffrage. 

Pour résumer en schéma :

![stack](./images/ingress-cert-manager.jpg)

Tout d'abord on ajoute les variables et puis des constantes dans le fichier `vars.yml` que l'on utilise dans un souci de clarté :

Voici donc des constantes que l'on n'a probablement jamais avoir besoin de changer (toutefois on pourrait le faire si besoin avec un `set_fact`, mais ce n'est pas très propre)

```yaml linenums="1" title="playbook/roles/kubeapps/vars/main.yml"
# vars file for role-kubeapps
kubeapps_k8s_ingress_class: traefik
letsencrypt_staging: https://acme-staging-v02.api.letsencrypt.org/directory
letsencrypt_prod: https://acme-v02.api.letsencrypt.org/directory 

letsencrypt_envs:
  staging: "{{ letsencrypt_staging }}"
  prod: "{{ letsencrypt_prod }}"

letsencrypt_envs_ca_certs:
  staging: https://letsencrypt.org/certs/staging/letsencrypt-stg-root-x1.pem

```

> `letsencrypt_staging` et `letsencrypt_prod` sont anticipé pour l'utilisation de cert-manager sur un cloud.

> `letsencrypt_envs_ca_certs` est l'url que l'on ajoutera dans les containers pour activer tls entre eux sur un environnement de test en ligne.

Les défauts qui utilise les variables prédéfinie précédemment :

```yaml linenums="1" title="playbook/roles/kubeapps/defaults/main.yml"
---
# Kubeapps internal acme server
kubeapps_internal_acme_network_ip: ~
kubeapps_internal_acme_host: acme-internal.k3s.local

cert_manager_letsencrypt_env: prod
cert_manager_namespace: cert-manager
cert_manager_acme_url: "{{ letsencrypt_envs[cert_manager_letsencrypt_env] }}"
cert_manager_staging_ca_cert_url: "{{ letsencrypt_envs_ca_certs[cert_manager_letsencrypt_env] | d(none) }}"
cert_manager_email: ""
cert_manager_private_key_secret: test_secret
```

Que l'on surcharge tout de suite dans le playbook **converge.yml** :

```yaml linenums="10" title="playbook/roles/kubeapps/molecule/default/converge.yml"
    cert_manager_acme_url: https://{{ kubeapps_internal_acme_host }}:14000/dir
    cert_manager_staging_ca_cert_url: https://localhost:15000/roots/0

```

> `cert_manager_acme_url` doit toujours utilisé l'entrée dns que l'on a choisie juste avant et qui est par défaut `acme.k3s.local`. un nom d'hôte que l'on a choisi pour l'usage local de cert-manager.

> **WARN** Attention en production ou recette l'adresse email `cert_manager_email` doit appartenir à un domaine valide (gmail, hotmail, etc...)

#### Mettons en place une bonne pratique

L'objectif est d'éviter du comportement non souhaité lors de l'utilisation de cert-manager et donc de ne pas lancer l'installation de la suite des tâches s'il manque certaine configuration. Cert-manager est un composant cœur dans notre stack car il distribue les certificats pour certain service embarquant des protocoles d'authentification. Nous ne pourrons pas utiliser ces services s'il n'y a pas de certificats et de cryptage des échanges en TLS (v1.2+).

On crée donc un fichier `check.yml` dans le dossier `tasks/` de notre rôle pour vérifier les configurations.
Ici on veut être sûr que l'email est renseigné sinon lets-encrypt ne donnera pas de certificat. Enfin on veut dans le cas d'un Acme de recette / test qu'un fichier de certificat d'autorité (CA) soit présent dans le système.

```yaml linenums="1" title="playbook/roles/kubeapps/tasks/checks.yml"
- name: check email when cert-manager
  assert:
    that:
      - cert_manager_email | default(false)

- name: Stat acme ca cert path
  stat:
    path: "{{ kubeapps_internal_acme_ca_file }}"
  register: acmeca_result
  when: cert_manager_is_internal

- name: Assert cert is present
  assert:
    that:
      - acmeca_result.stat.exists
  when: cert_manager_is_internal


```

Puis on active ceci en premier dans le fichier wrapper `main.yml` :

```yaml linenums="3" title="playbook/roles/kubeapps/tasks/main.yml"
- import_tasks: checks.yml
  tags: [kubeapps]

```

**Puis on installe cert-manager** avec le module helm chart de k3s.

```yaml linenums="1" title="playbook/roles/kubeapps/templates/cert-manager-chart-crd.yml.j2"
apiVersion: v1
kind: Namespace
metadata:
  name: {{ cert_manager_namespace }}
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: cert-manager
  namespace: kube-system
spec:
  chart: cert-manager
  targetNamespace: {{ cert_manager_namespace }}
  repo: https://charts.jetstack.io
  valuesContent: |-
    installCRDs: true
```

`installCRDs: true` permet de rendre disponible des nouveaux types de manifests propre à l'outil, voici la commande pour vérifier qu'ils sont bien installés :

```bash
kubectl get crd
# Give
orders.acme.cert-manager.io            
certificates.cert-manager.io            
certificaterequests.cert-manager.io    
challenges.acme.cert-manager.io
clusterissuers.cert-manager.io
issuers.cert-manager.io
```

Ensuite créeons notre **issuer** qui va s'occuper de tout le cycle de vie d'un certificat demandé par un ingress au travers de l'annotation.

```yaml
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-acme-issuer
```

Voici le manifest de l'issuer de type acme 

> **Note** il existe d'autres types d'issuer pour d'autres protocoles comme vault pki, ca, etc...

```yaml linenums="19" title="playbook/roles/kubeapps/templates/cert-manager-chart-crd.yml.j2"
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-acme-issuer
spec:
  acme:
    skipTLSVerify: {{ kubeapps_internal_acme_network_ip is not none }}
    email: {{ cert_manager_email }}
    server: {{ cert_manager_acme_url }}
    privateKeySecretRef:
      name: acme-account-key
    solvers:
    - selector: {}
      http01:
        ingress:
          class: {{ kubeapps_k8s_ingress_class }}

```

> **Note** Vu que l'on passe par l'ingress pour injecter les point d'accès du challenge acme, il faut bien configuré l'issuer avec la bonne classe d'ingress.

> **Note** kind: `ClusterIssuer` permet de créer un issuer qui sera disponible dans tout le cluster. À l'inverse un `Issuer` est disponible dans un seul namespace.

Nous voilà prêt il ne reste que à appeler la création du manifest dans notre fichier wrapper `main.yml` :

```yaml linenums="16" title="playbook/roles/kubeapps/tasks/main.yml"

- include_tasks: manifests.yml
  # ...
  loop:
    # ...
    - { src: cert-manager-chart-crd.yml, deploy:  "{{ cert_manager_namespace }}" }

```

Tout cela ne va cependant pas être suffisant dans le cas du mTLS car on va avoir besoin de faire confiance à notre autorité de certification.

On peut maintenant tester le bon fonctionnement de cert-manager et aussi la partie précédente sur coredns avec `molecule test`

