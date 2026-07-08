# Mise en place de l'infrastructure locale

Ce document décrit comment installer, sur la machine qui héberge le runner
self-hosted, les trois composants dont la pipeline a besoin : le runner
GitHub Actions lui-même, SonarQube (conteneurisé) et Coolify. Il documente
aussi les secrets et environnements GitHub à créer pour que
[`ci.yml`](../.github/workflows/ci.yml) et [`cd.yml`](../.github/workflows/cd.yml)
fonctionnent.

## 1. Runner GitHub Actions self-hosted

1. Dans le dépôt GitHub `Kant1-18/TIWAP` : **Settings → Actions → Runners → New
   self-hosted runner**, choisir macOS.
2. Suivre les commandes fournies par GitHub (téléchargement de l'archive,
   `./config.sh --url https://github.com/Kant1-18/TIWAP --token <TOKEN>`).
3. Lancer le runner en service persistant : `./svc.sh install && ./svc.sh start`
   (ou `./run.sh` pour un test ponctuel en premier plan).
4. Vérifier qu'il apparaît "Idle" dans Settings → Actions → Runners : c'est ce
   runner que les jobs `runs-on: [self-hosted]` de `ci.yml`/`cd.yml`
   utiliseront pour atteindre `localhost` (SonarQube) et le réseau local
   (Coolify).

## 2. SonarQube conteneurisé

```bash
docker compose -f sonarqube/docker-compose.sonarqube.yml up -d
```

- UI disponible sur http://localhost:9000 (identifiants par défaut
  `admin`/`admin`, changement de mot de passe imposé au premier login).
- Créer un projet nommé `tiwap` (clé `tiwap`, cohérente avec
  `sonarqube/sonar-project.properties`).
- Générer un token (**My Account → Security → Generate Token**) et l'enregistrer
  comme secret GitHub `SONAR_TOKEN` (voir section 4).

## 3. Coolify

L'installeur officiel de Coolify cible Linux ; sur macOS on le fait tourner
dans une VM Ubuntu locale via [Multipass](https://multipass.run/) :

```bash
brew install --cask multipass
multipass launch --name coolify --cpus 2 --memory 4G --disk 20G 22.04
multipass exec coolify -- bash -c "curl -fsSL https://cdn.coollabs.io/coolify/install.sh | sudo bash"
multipass info coolify   # récupérer l'IP de la VM
```

- Dashboard Coolify accessible sur `http://<IP-VM>:8000`.
- Créer trois applications (Docker Image) pointant sur
  `ghcr.io/kant1-18/tiwap` : `tiwap-dev`, `tiwap-staging`, `tiwap-prod`.
- Pour chacune, récupérer :
  - l'UUID de l'application (visible dans son URL / ses paramètres) ;
  - un token d'API (**Keys & Tokens → API tokens**) avec le droit de
    déploiement.

## 4. Secrets et environnements GitHub à créer

**Settings → Secrets and variables → Actions** :

| Secret | Valeur |
|---|---|
| `SONAR_TOKEN` | Token généré à l'étape 2 |
| `COOLIFY_URL` | `http://<IP-VM>:8000` |
| `COOLIFY_API_TOKEN` | Token d'API Coolify |
| `COOLIFY_DEV_APP_UUID` | UUID de l'application `tiwap-dev` |
| `COOLIFY_STAGING_APP_UUID` | UUID de l'application `tiwap-staging` |
| `COOLIFY_PROD_APP_UUID` | UUID de l'application `tiwap-prod` |
| `DEV_URL` | URL publique/LAN de `tiwap-dev` |
| `STAGING_URL` | URL publique/LAN de `tiwap-staging` |
| `PROD_URL` | URL publique/LAN de `tiwap-prod` |

**Settings → Environments**, créer `development`, `staging` et `production`.
Sur `production` uniquement, activer **Required reviewers** et s'ajouter comme
reviewer : c'est ce qui matérialise la validation manuelle avant déploiement
PROD décrite dans [`pipeline.md`](./pipeline.md).
