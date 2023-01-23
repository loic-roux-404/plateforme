# 1.7 Faire confiance à notre autorité de certification

---

On a deux endroits où l'on va faire confiance à notre autorité de certification.

- Sur notre machine et dans les différents pods ou mTLS 
- Sur le navigateur

#### Sur notre machine dans les différents pods ou mTLS 

Les serveurs acceptent les certificats de notre autorité de certification et se font donc suffisamment confiance entre eux pour établir une connexion TLS.

Pour qu'en interne nos serveur se fassent confiance, nous avons besoin de récupérer le certificat racine de notre autorité de certification et de l'ajouter dans le trust store de nos serveurs. De plus il faut que ce certificat soit présent avant le démarrage de k3s pour valider les requêtes de dex et kubeapps.

On utilise l'url du serveur staging `cert_manager_staging_ca_cert_url` qui est ici défini sur pebble pour récupérer ce certificat avant de jouer tous les rôles.

```yaml linenums="1" title="playbook/roles/kubeapps/tasks/pre-import-cert.yml"

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

Ensuite, il nous faut stocker dans des facts ansible le contenu du certificat et des définitions de volumes que l'on va injecter dans nos containers.

```yaml linenums="13" title="playbook/roles/kubeapps/tasks/pre-import-cert.yml"
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

Il faut ensuite absolument utiliser cette tâche avant le rôle sinon k3s va s'initialiser sans le certificat de Lets_encrypt digne de confiance et ne validera aucune connextion en TLS. (en particulier dex qui lui permet de controller le cluster avec l'api)

```yaml linenums="41" title="playbook/roles/kubeapps/molecule/default/converge.yml"
    - name: Import acme certificates
      include_tasks: "../../tasks/pre-import-cert.yml"
```

Nous introduisons ensuite la variable `cert_manager_is_internal` qui nous permet de savoir si nous utilisons un Acme spécial autre celui que le Lets-encrypt de production. Effectivement les acme locaux et staging ne sont pas référencés comme digne de confiance sur l'internet global.

```yaml linenums="14" title="playbook/roles/kubeapps/defaults/main.yml"
cert_manager_is_internal: "{{ (cert_manager_staging_ca_cert_url | d('')) != '' }}"

```

> L'idée est que si un url fournissant un certificat est donné avec `cert_manager_staging_ca_cert_url` alors on considère que l'on est dans un environnement utilisant un Lets-encrypt de test ou recette.

Nous avons alors besoin de plusieurs choses pour importer notre certificat racine dans le "trust-store" de nos serveurs.

Une ressource Kubernetes `configmap` (ou `secret`) pour stocker le certificat racine que l'on a récupéré dans les étapes précédentes dans une variable `kubeapps_internal_acme_ca_content`.

```yaml linenums="1" title="playbook/roles/kubeapps/templates/trust-bundle-config-crd.yml.j2"
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

**Cependant,** nous remarquon avec `kubectl get cm -A` que la ressource n'est présente que dans le namespace `cert-manager` or nous avons besoin de la récupérer dans les autres namespaces.

C'est pourquoi nous allons utiliser un module `trust-manager` fourni par jetstack pour partager cette ressource.

Pour commencer nous allons installer le helm chart de `trust-manager` avec le template `playbook/trust-manager.yml.j2` :

```yaml linenums="1" title="playbook/roles/kubeapps/templates/trust-manager-chart-crd.yml.j2"
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

> Warning : on fixe bien la version du chart car l'équipe de développement précise qu'ils apporteront des changements non rétrocompatibles dans les prochaines versions.

Puis on ajoute dans après notre `configmap` le trust-bundle dans un nouveau fichier pour partagé le certificat. Notre configmap s'organise avec le nom `acme-internal-ca-share` et une sous variable précisant le fichier `ca.crt`:

```yaml linenums="1" title="playbook/roles/kubeapps/templates/trust-bundle-config-crd.yml.j2"
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

```yaml linenums="17" title="playbook/roles/kubeapps/tasks/main.yml"
    - src: trust-manager-chart-crd.yml
      deploy: trust-manager 
      ns: "{{ cert_manager_namespace }}"
      condition: "{{ cert_manager_is_internal }}"
    - src: trust-bundle-config-crd.yml
      condition: "{{ cert_manager_is_internal }}"
```

Une fois cette configuration stocké nous allons pouvoir l'injecter dans les pods avec des `volumes`.

Ces volumes sont des espaces de stockage qui seront monté dans les pods et qui seront accessible par les containers.

Voici les objets volumes définis dans le fichier **vars.yml** de notre role kubeapps afin d'éviter qu'ils soient vide. Ils seront override si un `cert_manager_staging_ca_cert_url` est présent, car on injectera l'autorité dans les pods.

```yaml linenums="7" title="playbook/roles/kubeapps/vars/main.yml"
# Mounted in acme internal
kubeapps_internal_acme_ca_in_volume_crt: /etc/ssl/certs/acmeca.crt
kubeapps_internal_acme_ca_extra_volumes: []
kubeapps_internal_acme_ca_extra_volumes_mounts: []

```

> **Note** `/etc/ssl/certs/` est le répertoire par défaut des certificats sur les images linux, ils sont très souvent supportés par les frameworks et langages de programmation. Ainsi on fera confiance à n'importe quelle requête https vers un serveur configurés avec le certificat signé par celle-ci.

Voici un exemple d'utilisation des volumes dans kubernetes :

Import du volume pour le rendre disponible au montage :

```yaml
podnameexample:
  extraVolumes:
    {{ kubeapps_internal_acme_ca_extra_volumes | to_nice_yaml | indent(4) }}

```

Montage du volume dans le container :

```yaml
podsubcontainerexample:
  extraVolumeMounts:
    {{ kubeapps_internal_acme_ca_extra_volumes_mounts | to_nice_yaml | indent(4) }}
```

Les volumes sont **vide par défaut**, on les renseigne seulement à la fin de la tâche internal-acme lancée en mode cert-manager interne. Voici la suite du `set_fact` (l.25) dans cette tâche :

```yaml linenums="18" title="playbook/roles/kubeapps/tasks/pre-import-cert.yml"
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

Une autorité de certification est toujours initiée à partir d'une paire cryptographique faite d'une clé privée et d'un certificat contenant une clé publique. Comme pour d'autres protocoles comme ssh ou même Ethereum il faut accepter le certificat racine de l'autorité contenant la clé publique.

Vous pouvez le récupérer avec cette commande :

```bash
curl -k https://localhost:15000/roots/0 > ~/Downloads/pebble-ca.pem
```

**Mac :**

- Ouvrir Trousseaux d'accès (Keychain Access)
- Fichier > Importer des élements
- Sélectionner `~/Downloads/pebble-ca.pem`
- Clic droit sur "Pebble root ca" et sélectionner "Afficher les informations"
- Ouvrir les droits et selectionner `Toujours faire confiance` quand on utilise ce certificat

**Sur Linux** :

```
sudo cp ~/Downloads/pebble-ca.pem /usr/local/share/ca-certificates/pebble-ca.pem
sudo chmod 644 /usr/local/share/ca-certificates/pebble-ca.pem
sudo update-ca-certificates
```

***Relancez la page sur votre navigateur**

---
