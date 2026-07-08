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
  [`sonar-project.properties`](../sonar-project.properties) à la racine du
  dépôt — le scanner le cherche dans `sonar.projectBaseDir`, donc il doit
  rester à la racine, pas dans `sonarqube/`).
- Générer un token (**My Account → Security → Generate Token**) et l'enregistrer
  comme secret GitHub `SONAR_TOKEN` (voir section 4).

## 3. Coolify

Le control plane de Coolify (dashboard + API) est lui-même une stack
`docker-compose` standard — reprise telle quelle depuis le dépôt officiel
dans [`coolify/docker-compose.yml`](../coolify/docker-compose.yml). Coolify
ne supporte officiellement que les hôtes **Linux** : le conteneur `coolify`
gère chaque serveur (y compris « localhost ») **par SSH**, pas par le socket
Docker, et son script d'installation refuse explicitement macOS.

Sur ce projet, la stack tourne donc dans une machine Linux locale plutôt que
directement sur macOS — au choix :

- **OrbStack Machines** (`orb create ubuntu coolify`) si OrbStack est déjà
  installé ;
- ou une VM [Multipass](https://multipass.run/) (`multipass launch --name
  coolify --cpus 2 --memory 4G --disk 20G 22.04`).

Dans cette machine Linux :

```bash
sudo mkdir -p /data/coolify/{source,ssh,applications,databases,services,backups}
sudo docker network create coolify
cp coolify/.env.example /data/coolify/source/.env
# éditer /data/coolify/source/.env et remplacer toutes les valeurs CHANGE_ME_*
# les conteneurs tournent en www-data (uid/gid 9999) : sans ce chown, Coolify
# ne peut pas écrire ses clés SSH générées au premier démarrage.
sudo chown -R 9999:9999 /data/coolify/{ssh,applications,databases,services,backups}
# --env-file est indispensable : `env_file:` dans le compose ne fournit les
# variables qu'aux conteneurs, pas à la substitution ${...} du compose lui-même.
sudo docker compose --env-file /data/coolify/source/.env -f coolify/docker-compose.yml up -d
```

- Dashboard Coolify accessible sur `http://<IP-de-la-machine-Linux>:8000`.
- Testé et validé sur ce projet avec une machine OrbStack Ubuntu
  (`orb create ubuntu coolify`) : OrbStack donne une IP LAN directement
  routable depuis le Mac (`orb list` pour la retrouver), pas besoin de port
  forwarding supplémentaire.
- TIWAP a besoin de MongoDB (voir `docker-compose.yml` à la racine du repo) :
  une application Coolify de type **Docker Image** seule ne suffit pas, l'app
  plante au démarrage (`db:27017: Name or service not known`). Créer plutôt
  trois **Services** (Docker Compose personnalisé) à partir de
  [`coolify/tiwap-stack.yml`](../coolify/tiwap-stack.yml) : `tiwap-dev`,
  `tiwap-staging`, `tiwap-production` — chacun avec les variables
  d'environnement `TIWAP_VERSION` (tag d'image à déployer) et
  `TIWAP_HOST_PORT` (`5001`/`5002`/`5003`).
- L'application sert en **HTTPS auto-signé** (`ssl_context` dans `app.py`,
  pas de certificat valide) : les URLs de smoke test doivent utiliser
  `https://`, pas `http://`, et `curl -k` (déjà géré par
  `scripts/smoke_test.sh`).
- Pour chaque service, récupérer l'UUID (visible dans son URL / ses
  paramètres) et un token d'API (**Keys & Tokens → API tokens**) avec le
  droit de déploiement.
- Le déploiement Coolify est asynchrone : `scripts/smoke_test.sh` réessaie
  pendant 2 minutes avant d'échouer, pour laisser le temps au conteneur de
  démarrer.

## 4. Secrets et environnements GitHub à créer

**Settings → Secrets and variables → Actions** :

| Secret | Valeur |
|---|---|
| `SONAR_TOKEN` | Token généré à l'étape 2 |
| `COOLIFY_URL` | `http://<IP-VM>:8000` |
| `COOLIFY_API_TOKEN` | Token d'API Coolify |
| `COOLIFY_DEV_APP_UUID` | UUID du service `tiwap-dev` |
| `COOLIFY_STAGING_APP_UUID` | UUID du service `tiwap-staging` |
| `COOLIFY_PROD_APP_UUID` | UUID du service `tiwap-production` |
| `DEV_URL` | `https://<IP-VM>:5001` |
| `STAGING_URL` | `https://<IP-VM>:5002` |
| `PROD_URL` | `https://<IP-VM>:5003` |

**Settings → Environments**, créer `development`, `staging` et `production`.
Sur `production` uniquement, activer **Required reviewers** et s'ajouter comme
reviewer : c'est ce qui matérialise la validation manuelle avant déploiement
PROD décrite dans [`pipeline.md`](./pipeline.md).
