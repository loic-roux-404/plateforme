# 1.4 Autorité de certification

---

Premièrement va falloir que les services soient accessibles depuis l'extérieur du cluster sur notre réseau local.

Ensuite que notre plateforme va adopter un principe zero-trust pour notre réseau. On va donc s'assurer que toutes les communication entre services sont cryptées avec TLS (https). Pour cela on va faire appel à un ensemble d'outils de gestion des certificats dans un cluster kubernetes.

#### Pebble

On va recourir à une autorité de certification locale avec l'outil [pebble](https://github.com/letsencrypt/pebble). Il s'agit d'une implémentation de l'acme server de lets encrypt dédiée au test.

Pour rappel Lets-encrypt Acme est un protocole embarquant une autorité de certification générant des certificats pour tls simplement au travers de plusieurs type de "challenges". On peut obtenir des certificats juste en ayant un serveur http disponible sur le réseau (ou internet) ou en ayant accès à l'édition des zones d'un serveur dns (en fonction du fournisseur).

Il est cependant recommandé d'utiliser un serveur acme de test pour éviter de saturer les quotas de Let's-encrypt. Ici nous sommes en local et nos services ne sont pas accessibles depuis internet.

#### Création de notre autorité avec docker et le playbook prepare de molecule

Ce playbook se lance avant le converge soit avant l'exécution de notre rôle et lance un container docker sur notre machine. Comme précisé avant, le `network_mode` à host nous permet d'hérité du localhost de votre machine et permet d'accéder aux services sur l'autre container sur lequel on installe notre rôle.

```yaml linenums="1" title="playbook/roles/kubeapps/molecule/default/prepare.yml"
- name: Prepare
  hosts: localhost
  connection: local
  gather_facts: false
  no_log: "{{ molecule_no_log }}"
  collections:
    - community.docker
  tasks:
    - name: Start pebble container
      community.docker.docker_container:
        name: pebble
        image: "letsencrypt/pebble:latest"
        command: pebble -config /pebble/pebble-config.json
        state: started
        restart: True
        network_mode: host
        volumes:
          - "{{ playbook_dir }}/pebble:/pebble:ro"
      register: result
      until: result is not failed
      retries: 3
      delay: 10

    - name: Wait for pebble to start
      ansible.builtin.wait_for:
        host: localhost
        port: 15000
        delay: 5

```

> `playbook_dir` référence le dossier ou notre playbook molecule est lancé : `playbook/roles/kubeapps/molecule/default/`

Ensuite nous avons besoin de deux certificats racines pour initialiser notre autorité de certification. On les récupère sur le [projet github de pebble](https://github.com/letsencrypt/pebble/) directement avec cette commande.

> **Warning** Attention n'utiliser surtout pas pebble et ces certificats en production

```bash
mkdir -p playbook/roles/kubeapps/molecule/default/pebble
curl -L https://raw.githubusercontent.com/letsencrypt/pebble/main/test/certs/localhost/cert.pem > playbook/roles/kubeapps/molecule/default/pebble/cert.pem
curl -L https://raw.githubusercontent.com/letsencrypt/pebble/main/test/certs/localhost/key.pem > playbook/roles/kubeapps/molecule/default/pebble/key.pem
```

Puis on crée le fichier de configuration de notre serveur Acme :

[playbook/roles/kubeapps/molecule/default/pebble/pebble-config.json](../playbook/roles/kubeapps/molecule/default/pebble/pebble-config.json)

```json
{
    "pebble": {
      "listenAddress": "0.0.0.0:14000",
      "managementListenAddress": "0.0.0.0:15000",
      "certificate": "/pebble/cert.pem",
      "privateKey": "/pebble/key.pem",
      "httpPort": 80,
      "tlsPort": 443,
      "ocspResponderURL": "",
      "externalAccountBindingRequired": false
    }
  }
```

Maintenant lorsque l'on lance `molecule test` nous exécutons dans l'ordre :

- Le playbook **create.yml** qui lance les plateformes définies dans molecule.yml (le ubuntu2004 pour tester notre rôle)
- Le playbook **prepare.yml** que l'on a entièrement créer pour lancer un pebble de test
- Le playbook **verify.yml** pour vérifier que l'on a bien lancer notre outils
- Le playbook **destroy.yml** qui supprime les containers de platforms
- Enfin le playboonk **cleanup.yml** que l'on créer en entier pour supprimer l'instance de pebble définie dans le prepare.

Voici le playbook **cleanup.yml** manquant :

```yaml linenums="1" title="playbook/roles/kubeapps/molecule/default/cleanup.yml"
---
- name: Cleanup
  hosts: localhost
  connection: local
  gather_facts: false
  no_log: "{{ molecule_no_log }}"
  collections:
    - community.docker
  tasks:
    - name: Destroy pebble instance(s)
      docker_container:
        name: pebble
        state: absent
      when: {{ lookup('env', 'MOLECULE_CLEANUP') | boolean | d(false) }}

```

> On a choisi de laisser par défaut le container pebble lancé pour pouvoir le relancer avec `molecule converge` et ne pas avoir à le relancer à chaque fois. Cependant, dans un environnement de CI/CD on peut vouloir supprimer le container après chaque test.

---
