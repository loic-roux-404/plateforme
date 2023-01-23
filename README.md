# Paas Tutorial

[Documentation](docs/index.md)

## Docs

```bash
pip install -r requirements.txt
```

#### Deploy

```bash
mkdocs gh-deploy
# Revert helm chart index file
git checkout gh-pages
curl https://raw.githubusercontent.com/esgi-lyon/paas-tutorial/gh-pages/index.yaml > index.yaml
git add . && git commit -m "Revert helm chart index file" && git push
git checkout -
```
