<div style="display: flex; width: 100%; text-align: center;">
<h3 style="width: 20%">

[Précédent](3-4-terraform-azure-vm.md)
</h3>

</div>

## 4. Helm chart

Pour rappel helm est le gestionnaire de packages pour Kubernetes. Il vous aide à piloter Kubernetes à l’aide de cartes de navigation, appelés Charts en anglais. Nous allons donc en créer une pour le microservice que nous avons créé.

Une chart est une collection de fichiers organisés dans une structure de répertoire spécifique. Ces fichiers décrivent un ensemble de ressources Kubernetes et leur configuration de manière dynamique.

Une instance exécutée d'une chart avec une configuration spécifique est appelée une release.

Ce chart sert à implémenter les fonctionnalités d'un ensemble de manifests kubernetes `deployment,service,ingress`. Nous n'allons pas aller trop loin et nous contenter de seulement ces fonctionnalités de déploiement. Nous aurons un chart générique que l'on va utiliser pour chaque micro services.

### Installation

Sur Linux / mac
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Si vous utilisez homebrew : `brew install helm` 

On vérifie avec `helm --version`

### Déploiement des containers des microservices sur un registre

Nous avons besoin pour utiliser un container dans un chart helm et donc dans un pod kube, de les déployer sur un registre. 

> Un registre de containers consiste à stocker des images de containers pour pouvoir les utiliser facilement avec une technologie de conteneurisation.

Nous allons utiliser docker hub pour déployer nos containers de manière publique pour bénéficier de la gratuité du stockage des images.

Tout d'abord rancher (docker) doit être lancé avant de déployer les containers et vous devez vous placer dans votre projet maven / spring boot.

Enuite connectez vous à votre docker hub avec `docker login` et créez un repository pour chaque microservice. Voici un exemple pour le microservice `client`.

![docker hub repository](../images/docker-hub.png)

Ensuite dans le dossier d'un microservice lancer la commande maven suivante. (on est toujours sur l'exemple du microservice `client`)

```bash
mvn spring-boot:build-image -Dspring-boot.build-image.imageName=loicroux/client
```

Le build devrait se terminé par un message comme celui ci :

```txt
Successfully built image 'docker.io/loicroux/client:latest'
```

### Création d'un chart pour un microservice

```bash
mkdir charts
helm create charts/microservice
```

Dans le répertoire `charts/microservice` nous avons :

- un répertoire `templates` qui contient les fichiers de déploiement. 
- un fichier `Chart.yaml` qui contient les informations sur le chart
- un fichier `values.yaml` qui contient les valeurs par défaut du chart

Nous allons donc modifier notre `values.yaml` pour mettre en place plusieurs microservices et les déployer avec un seul chart.
Tou d'abord il va falloir que nos containers soit déployer sur un registre, nous allons utilisé docker hub pour placer des containers générés construit automatiquement par le module `buildImage` de spring.

Dans ce chart nous allons mettre en places des défaut pour faire fonctionner directement les microservices sur la paas sans configurations supplémentaires.

On change donc seulement les valeurs par défaut du ingress pour qu'il utilise traefik et le cert-manager de notre paas.

[chart/values.yaml](chart/values.yaml#L46)

```yaml
  annotations:
    kubernetes.io/ingress.class: traefik
    cert-manager.io/cluster-issuer: letsencrypt-acme-issuer
```

### Mise en place de la dépendance du micro service : postgres

Avant de déployer notre microservice on sait que l'on a besoin d'une base de données postgres. On va donc ajouter comme [dépendance](https://bitnami.com/stack/postgresql/helm) le chart bitnami de postgres au notre.

On va donc modifier le fichier `Chart.yaml` pour ajouter la dépendance.

[charts/microservice/Chart.yaml#L26](../charts/microservice/Chart.yaml#L26)

```yaml
dependencies:
  - name: postgresql
    version: ~12.1.9
    repository: https://charts.bitnami.com/bitnami
```

> `~` Signifie que on garde les version de patch sans passer à la majeure ou mineure suivante.

Puis on met à jour les dépendances avec la commande `helm dependency update charts/microservice`.

> Cette commande génère un `Chart.lock` qui va permettre de bloquer les versions des dépendances.

### Helper et secrets dans helm

Nous avons besoin de pouvoir configurer nos microservices facilement avec des variables et des identifiants divers comme la connection à la base de données. Pour cela nous allons créer notre propre helper et des manifests kubernetes pour utiliser des secrets.

On va donc remplir un fichier de secret comme ceci :

[charts/microservice/templates/secrets.yaml](charts/microservice/templates/secrets.yaml)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Values.secret.name }}
type: Opaque
data:
  {{- range $key, $val := .Values.env.secret }}
  {{ $key }}: {{ $val | b64enc }}
  {{- end}}

```

Ensuite ce fichier de template va permettre de définir comme une fonction (helper) qui va récupérer les secrets et les injecter sous forme de variable d'environnement dans les pods.

[charts/microservice/templates/_helpers.tpl](charts/microservice/templates/_helpers.tpl)

```yaml
{{/*
Create the secrets required for our app as environment var
*/}}
{{- define "helpers.listEnvVariables"}}
{{- range $key, $val := .Values.env.secret }}
- name: {{ $key }}
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.secret.name }}
      key: {{ $key }}
{{- end}}
{{- end }}

```

Puis, il esr utiliser dans le fichier de deployment avec la clé `containers`:

[charts/microservice/templates/deployment.yaml](charts/microservice/templates/deployment.yaml#L36)

```yaml
          env:
            {{- include "helpers.listEnvVariables" . | indent 10 }}

```

Enfin on ne doit pas oublier de définir les valeurs par défaut dans le fichier `values.yaml`:

> On prépare d'avance les variable de connection au serveur de base de données que l'on test en local (role kubeapps, `molecule test --destroy never`)

[charts/microservice/values.yaml](charts/microservice/values.yaml#L17)

```yaml
secret:
  name: all-secrets
env:
  secret:
    PG_USER: ekommerce
    PG_PASSWORD: password
    PG_CONNECTION: jdbc:postgresql://postgres.default.pod.cluster.local:5432/db

```

Puis on configure le chart postgres pour qu'il utilise les secrets définis dans le chart microservice.


[charts/microservice/values.yaml](charts/microservice/values.yaml#L25)

```yaml
auth:
  username: ekommerce
  existingSecret: all-secrets
  secretKeys:
    userPasswordKey: PG_PASSWORD

```

Nous pouvons vérifier avec `helm lint charts/microservice` si il n'y a pas d'erreurs puis aussi voir le résultat de notre chart avec `helm template charts/microservice`

### Déploiement du chart

Si vous n'avez pas suivi le tutoriel en utilisant un repository git, vous pouvez créer un repository sur github [ici](https://github.com/new) et y ajouter le chart. Ceci vous permettra de mettre à disposition un repository helm grâce github pages. Ainsi vous pourrez utiliser le chart sur votre cluster kubernetes.

> Nous utiliserons l'outil CD [chart_releaser_action](https://helm.sh/docs/howto/chart_releaser_action/) développé pour automatisé la publication de chart avec github actions (CI/CD)

```bash
git clone https://github.com/my-org/my-repo
cd my-repo
git add .
git commit -m "chore: Helm chart"
git push
```

Ensuite créer une branche vide et orpheline pour github pages :

```bash
git checkout --orphan gh-pages
git rm --cached -r .
echo  "## Pages branch for helm charts" > README.md
git add README.md
git commit -m "init gh pages"
git push -u origin gh-pages
```

On revient sur la branche main et on laisse la nouvelle aux mains de chart releaser action

```bash
git checkout -f main
```

Puis on créer un fichier `.github/workflows/release.yml` dans lequel on met en place l'automatisation de la publication du chart.

```bash
mkdir -p .github/workflows
touch .github/workflows/release.yml
```

[.github/workflows/release.yml](../.github/workflows/release.yml)

```yaml
name: Release Charts

on:
  push:
    branches:
      - main
    paths:
      - 'charts/**'
      - .github/workflows/release.yml

permissions:
  contents: write
  packages: write
  pages: write
  id-token: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Configure Git
        run: |
          git config user.name "$GITHUB_ACTOR"
          git config user.email "$GITHUB_ACTOR@users.noreply.github.com"

      - name: Add repositories workaround
        run: |
          helm repo add bitnami https://charts.bitnami.com/bitnami

      - name: Run chart-releaser
        uses: helm/chart-releaser-action@v1.4.1
        env:
          CR_TOKEN: "${{ github.token }}"

```

> On a bien précisé que le token créer pour un job github action a la **permission d'écrire sur les pages github**.


```bash
git add .
git commit -m "chore: chart releaser action"
git push
```

Notre chart va donc se déployer sur github pages et être disponible à l'adresse suivante : `https://my-org.github.io/my-repo`. N'hésitez pas à consulter l'avancement du job [ici](https://github.com/esgi-lyon/paas-tutorial/actions/runs/) et à suivre le déploiement sur [l'onglet deployments](https://github.com/esgi-lyon/paas-tutorial/deployments)

Enfin vous pouvez ajouter le repo à helm pour tester que la publication a bien fonctionnée :

```bash
helm repo add paas https://esgi-lyon.github.io/paas-tutorial
```

> Si vous avez des soucis après cette commande essayez de relancer les déploiements github pages qui peuvent dysfonctionner parfois. Exemple de lien vers les jobs : https://github.com/esgi-lyon/paas-tutorial/actions/workflows/pages/pages-build-deployment

### Utilisation finale de notre chart

Sur le lien de votre [kubeapps](https://kubeapps.k3s.local/#/c/default/ns/default/config/repos) vous pouvez gérer les repositories helm à utiliser pour découvrir les applications. Nous allons ainsi pouvoir ajouter notre repository helm. 

Cliquez sur `Add Package Repository` puis renseigner les informations suivantes :

- **Name** : paas
- **Url** : https://esgi-lyon.github.io/paas-tutorial
- **Type** : Helm
- **Scope** : Global Repository (accessible depuis tous les namespaces)

Enfin vous pouvez rechercher l'application `chart` dans le `Catalog` de kubeapps et le déployé dans le namespace de votre choix. Arrêter vous bien à l'étape de configuration du chart avant de le déployer.

**Dans la configuration** vous pourrez mettre en place :

- Un container de votre choix, ici j'ai utilisé l'image docker que j'ai créé précédemment pour le microservice fraude.

```yaml
image:
  pullPolicy: IfNotPresent
  repository: loicroux/client
  tag: latest

```

- un ingress avec un certificat TLS automatique.

```yaml
  hosts:
    - host: fraud.k3s.local
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - hosts:
        - fraud.k3s.local
      secretName: fraud.k3s.local-tls
```

Attention cela ne risque de ne pas fonctionner correctement car les microservices ont une dépendence à postgresql. Il faudra donc bien configurer le helm chart de posgres en dépendance comme cela :

```yaml
auth.username: ekommerce
auth.password: password
auth.database: client
```

### Installation du chart sur kubeapps

<div style="display: flex; width: 100%; text-align: center;">
<h3 style="width: 20%">

[Recommencer](#4-Helm-chart)
</h3>

<div style="width: 35%"></div>

<h3 style="width: 40%">

[Suivant - Faq et exercices](5-allez-plus-loin.md)
</h3>
</div>
