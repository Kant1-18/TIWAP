# Changelog

Toutes les versions notables de l'industrialisation CI/CD de TIWAP sont
recensées ici. Voir aussi les tags Git (`v1.0.0`, `v1.0.1`) et les images
publiées sur `ghcr.io/kant1-18/tiwap`.

## [1.0.0]

- Mise en place de la chaîne CI/CD complète : GitHub Actions, SonarQube
  conteneurisé, Trivy, GitHub Container Registry, Coolify.
- Pipeline CI : lint, tests unitaires, analyse SonarQube, build Docker, scan
  Trivy, publication de l'image.
- Pipeline CD : déploiement automatique sur DEV, STAGING puis PROD (validation
  manuelle), avec smoke tests entre chaque environnement.
- Documents de conception : `docs/architecture.md`, `docs/pipeline.md`,
  `docs/git-strategy.md`.
