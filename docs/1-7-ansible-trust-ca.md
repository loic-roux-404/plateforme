<div style="display: flex; width: 100%; text-align: center;">
<h3 style="width: 20%">

[Précédent](1-6-ansible-cert-manager.md)
</h3>

<div style="width: 40%"></div>

<h3 style="width: 45%">

[Suivant - Authentification et des habilitations](1-8-ansible-dex.md)
</h3>
</div>

---

### 1-7 Faire confiance à notre autorité de certification

On a deux endroits où l'on va faire confiance à notre autorité de certification.

- Sur notre machine et dans les différents pods ou mTLS 
- Sur le navigateur

#### Sur notre machine dans les différents pods ou mTLS 

Les serveurs acceptent les certificats de notre autorité de certification et se font donc suffisament confiance entre eux pour établir une connection TLS.

Pour que en interne nos serveur se fassent confiance nous avons besoin de récupérer le certificat racine de notre autorité de certification et de l'ajouter dans le trust store de nos serveurs. De plus il faut que ce certificat soit présent avant le démarrage de k3s pour valider les requètes de dex et kubeapps.

On utilise l'url du serveur staging `cert_manager_staging_ca_cert_url` qui est ici définit sur pebble pour récupérer ce certificat avant de jouer tous les rôles.

[playbook/roles/kubeapps/tasks/pre-import-cert.yml](../playbook/roles/kubeapps/tasks/pre-import-cert.yml)

```yaml

- name: Download certificate file
  uri:
    url: "{{ cert_manager_staging_ca_cert_url }}"
    validate_certs: "{{ kubeapps_internal_acme_network_ip is none }}"
    return_content: True
  register: ca_file

- name: Trust cert inside current machine
  ansible.builtin.copy:
    dest: "{{ kubeapps_internal_acme_ca_file }}"
    content: "{{ ca_file.content }}"

```

Ensuite il nous faut stocker dans des facts ansible le contenu du certificat et des définitions de volumes que l'on va injecter dans nos containers.

[playbook/roles/kubeapps/tasks/pre-import-cert.yml](../playbook/roles/kubeapps/tasks/pre-import-cert.yml#L13)

```yaml
- set_fact:
    kubeapps_internal_acme_ca_content: "{{ ca_file.content }}"
    kubeapps_internal_acme_ca_extra_volumes:
    - name: acme-internal-ca-share
      configMap: 
        name: acme-internal-ca-share
    kubeapps_internal_acme_ca_extra_volumes_mounts:
      - name: acme-internal-ca-share
        mountPath: "{{ kubeapps_internal_acme_ca_in_volume_crt }}"
        subPath: ca.crt

```

Il faut ensuite absolument utiliser cette tâche avant le rôle sinon k3s va s'initialiser sans le certificat de letsencrypt digne de confiance et ne validera aucune connextion en TLS. (en particulier dex qui lui permet de controller le cluster avec l'api)

[playbook/roles/kubeapps/molecule/default/converge.yml](../playbook/roles/kubeapps/molecule/default/converge.yml#L41)

```yaml
    - name: Import acme certificates
      include_tasks: "../../tasks/pre-import-cert.yml"
```

Nous introduisons ensuite la variable `cert_manager_is_internal` qui nous permet de savoir si nous utilisons un acme spécial autre celui que le letsecrypt de production. Effectivement les acme locaux et staging ne sont pas référencés comme digne de confiance sur l'internet global.

[playbook/roles/kubeapps/defaults/main.yml](../playbook/roles/kubeapps/defaults/main.yml#L14)

```yaml
cert_manager_is_internal: "{{ (cert_manager_staging_ca_cert_url | d('')) != '' }}"

```

> L'idée est que si un url fournissant un certifiat est donné avec `cert_manager_staging_ca_cert_url` alors on considère que l'on est dans un environnement utilisant un lets encrypt de test ou recette.

Nous avons alors besoin de plusieurs choses pour importer notre certificat racine dans le "truststore" de nos serveurs.

Une ressource kube configmap (ou secret) pour stocker le certificat racine que l'on a récupéré dans les étapes précédentes dans une variable `kubeapps_internal_acme_ca_content`.

[playbook/roles/kubeapps/templates/trust-bundle-config-crd.yml.j2](../playbook/roles/kubeapps/templates/trust-bundle-config-crd.yml.j2)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: acme-internal-root-ca
  namespace: "{{ cert_manager_namespace }}"
data:
  ca.crt: |
    {{ kubeapps_internal_acme_ca_content | indent(4) }}

```

> `indent` sert à rajouter les espace à chaque lignes du certificat pour qu'il soit bien formatté dans le fichier yaml.

**Cependant** nous remarquon avec `kubectl get cm -A` que la ressource n'est présente que dans le namespace `cert-manager` or nous avons besoin de la récupérer dans les autres namespaces.

C'est pourquoi nous allons utiliser un module `trust-manager` fourni par jetstack pour partager cette ressource.

Pour commencer nous allons installer le helm chart de `trust-manager` avec le template `playbook/trust-manager.yml.j2` :

[playbook/roles/kubeapps/templates/trust-manager-chart-crd.yml.j2](../playbook/roles/kubeapps/templates/trust-manager-chart-crd.yml.j2)
```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: trust-manager
  namespace: kube-system
spec:
  version: 0.3.0
  chart: trust-manager
  targetNamespace: {{ cert_manager_namespace }}
  repo: https://charts.jetstack.io

```

> Warning : on fixe bien la version du chart car l'équipe de développement précise qu'ils apporterons des changements non rétrocompatible dans les prochaines versions.

Puis on ajoute dans après notre configmap le trust-bundle dans un nouveau fichier pour partagé le certificat. Notre configmap s'organise avec le nom `acme-internal-ca-share` et une sous variable précisant le fichier `ca.crt`:

[playbook/roles/kubeapps/templates/trust-bundle-config-crd.yml.j2](../playbook/roles/kubeapps/templates/trust-bundle-config-crd.yml.j2)

```yaml
---
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: acme-internal-ca-share
spec:
  sources:
  - configMap:
      name: "acme-internal-root-ca"
      key: "ca.crt"
  target:
    configMap:
      key: "ca.crt"

```

Ensuite, **il est essentiel** d'appeler dans l'ordre tous ces manifests que l'on vient de créer :

> **Warning** On les lance bien après l'installation et configuration de notre issuer `cert-manager` pour éviter des erreurs de dépendances manquantes.

[playbook/roles/kubeapps/tasks/main.yml](playbook/roles/kubeapps/tasks/main.yml#L17)
```yaml
    - src: trust-manager-chart-crd.yml
      deploy: trust-manager 
      ns: "{{ cert_manager_namespace }}"
      condition: "{{ cert_manager_is_internal }}"
    - src: trust-bundle-config-crd.yml
      condition: "{{ cert_manager_is_internal }}"
```

Une fois cette configuration stocké nous allons pouvoir l'injecter dans les pods avec des `volumes`.

Ces voluemes sont des espace de stockage qui seront monté dans les pods et qui seront accessible par les containers.

Voici les objets volumes définie dans le fichier **vars.yml** de notre role kubeapps afin d'éviter qu'ils soient vide. Ils seront override si un `cert_manager_staging_ca_cert_url` est présent car on injectera l'autorité dans les pods.

[playbook/roles/kubeapps/vars/main.yml](../playbook/roles/kubeapps/vars/main.yml#L7)

```yaml
# Mounted in acme internal
kubeapps_internal_acme_ca_in_volume_crt: /etc/ssl/certs/acmeca.crt
kubeapps_internal_acme_ca_extra_volumes: []
kubeapps_internal_acme_ca_extra_volumes_mounts: []

```

> **Note** `/etc/ssl/certs/` est le répertoire par défaut des certificats sur les images linux, ils sont très souvent supportés par les framework et langages de programmation. Ainsi on fera confiance à toute requètes https vers un serveur configurés avec un certificat signé par celle-ci.

Voici un exemple d'utilisation des volumes dans kubernetes :

Import du volume pour le rendre disponible au montage :

```yaml
podname:
  extraVolumes:
    {{ kubeapps_internal_acme_ca_extra_volumes | to_nice_yaml | indent(4) }}

```

Montage du volume dans le container :

```yaml
podsubcontainer:
  extraVolumeMounts:
    {{ kubeapps_internal_acme_ca_extra_volumes_mounts | to_nice_yaml | indent(4) }}
```

Les volumes sont **vide par défaut**, on les renseigne seulement à la fin de la tâche internal-acme lancée en mode cert-manager interne. Voici la suite du `set_fact` (l.25) dans cette tâche :

[playbook/roles/kubeapps/tasks/pre-import-cert.yml](../playbook/roles/kubeapps/tasks/pre-import-cert.yml#L18)

```yaml
    kubeapps_internal_acme_ca_extra_volumes:
    - name: acme-internal-ca-share
      configMap: 
        name: acme-internal-ca-share
    kubeapps_internal_acme_ca_extra_volumes_mounts:
    - name: acme-internal-ca-share
      mountPath: "{{ kubeapps_internal_acme_ca_in_volume_crt }}"
      subPath: ca.crt

```

#### Sur notre navigateur :

Une autorité de certification est toujours initiée à partir d'une paire cryptographique faite d'une clé privée et d'un certificat contenant une clé publique. Comme pour d'autres protocole comme ssh ou même etherum il faut accepter le certificat racine de l'autorité contenant la clé publique.

Vous pouvez le récupérer avec cette commande :

```bash
curl -k https://localhost:15000/roots/0 > ~/Downloads/pebble-ca.pem
```

**Mac :**

- Open Keychain Access
- File > import items...
- Select ~/Downloads/pebble-ca.pem
- Right click on minica root ca choose get info
- Open Trust and select Always Trust on When using this certificate

**Sur Linux** :

```
sudo cp ~/Downloads/pebble-ca.pem /usr/local/share/ca-certificates/pebble-ca.pem
sudo chmod 644 /usr/local/share/ca-certificates/pebble-ca.pem
sudo update-ca-certificates
```

***Relancez la page sur votre navigateur**

---

<div style="display: flex; width: 100%; text-align: center;">
<h3 style="width: 30%">

[Recommencer](#1-7-Faire-confiance-à-notre-autorité-de-certification)
</h3>

<div style="width: 40%"></div>

<h3 style="width: 30%">

[Suivant - Authentification et des habilitations](1-8-ansible-dex.md)
</h3>
</div>
