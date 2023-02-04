# 4.2 Déploiement du chart

Si vous n'avez pas suivi le tutoriel en utilisant un repository git, vous pouvez créer un repository sur github pour votre organisation avec ce type d'url : [https://github.com/organizations/<votre-org>/repositories/new](https://github.com/organizations/<votre-org>/repositories/new). Ceci vous permettra de mettre à disposition un repository helm grâce github pages et ainsi d'utiliser le chart sur le cluster kubernetes.

> Nous utiliserons l'outil CD [chart_releaser_action](https://helm.sh/docs/howto/chart_releaser_action/) développé pour automatisé la publication de chart avec github actions (CI/CD)

On va donc initialiser un repository git et pour l'instant ne pas y ajouter le chart tout de suite :

```bash
git init
git remote add origin git@github.com:<my-org>/<my-repo>.git
git add infra playbook README.md
git commit -m "chore: Helm chart"
git push
```

> Note: Par défaut lorsque l'on initialise un repository git, la branche main est créée.

> Note : on ne push pas sur la branche main pour le moment car la CI github n'est pas encore mise en place

Ensuite, on va placer le dossier chart dans un espace temporaire git "stash" pour le commit plus tard

```bash
git add .
git stash
```

On créer une branche vide et orpheline pour github pages :

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

```yaml linenums="25" title=".github/workflows/release.yml"
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

Enfin, on enlève le dossier `charts` du stash et on le commit :

```bash
git stash pop
git add .
git commit -m "chore: add chart"
```

L'objectif est de modifier les fichiers du chart pour que git détecte un changement et déclenche la CD github action.

Notre chart va donc se déployer sur github pages et être disponible à l'adresse suivante : `https://my-org.github.io/my-repo`. N'hésitez pas à consulter l'avancement du job [ici](https://github.com/esgi-lyon/paas-tutorial/actions/runs/) et à suivre le déploiement sur [l'onglet deployments](https://github.com/esgi-lyon/paas-tutorial/deployments)

Enfin vous pouvez ajouter le repo à helm pour tester que la publication a bien fonctionner :

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

**Dans la configuration** vous pourrez mettre en place en modifiant les valeurs par défaut :

- Un container de votre choix, ici j'ai utilisé l'image docker que j'ai créé précédemment pour le microservice client.

```yaml
image:
  pullPolicy: IfNotPresent
  repository: loicroux/client
  tag: latest

```

- Le port du container en fonction de la configuration `server.port` dans le application.yaml de votre microservice. Ici c'est pour le client 8080.

```yaml
container:
  port: 8080
```

- Un ingress avec un certificat TLS automatique.

```yaml
ingress:
  # ...
  enabled: true
  hosts:
    - host: client.k3s.local
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - hosts:
        - client.k3s.local
      secretName: client.k3s.local-tls
```
