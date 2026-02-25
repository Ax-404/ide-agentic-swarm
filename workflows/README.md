# Workflows swarm

Définitions de workflows pour le moteur **`swarm-workflow.sh`**. Chaque fichier décrit une suite d'étapes (scripts `swarm-*.sh`) exécutées dans l'ordre.

## Ajout / retrait automatique

- **Ajouter un workflow** : créez `workflows/<nom>.workflow` — il est pris en compte automatiquement (`--list` et `./scripts/swarm-workflow.sh <nom>`).
- **Retirer** : supprimez le fichier ; il disparaît de la liste. Aucune configuration à part le fichier.

## Format

- **Une étape** = une ligne avec le **nom du script** (sans `swarm-` ni `.sh`), puis **un argument par ligne**, jusqu'à une ligne contenant exactement `--`.
- Lignes vides et `# commentaire` sont ignorées. La **première ligne de commentaire** sert de description dans `--list`.
- Noms de scripts valides : `dispatch`, `pipeline`, `coordinate`, `merge`, `deploy-staging`, `seeds-create`, `clean`, `rollback`, `budget`, `validate`, etc. (tous les `scripts/swarm-*.sh`).

## Fichiers fournis

| Fichier | Description |
|---------|-------------|
| `default.workflow` | Dispatch 2 issues puis pipeline (tests + skip conflits). À lancer quand des issues existent déjà. |
| `autonomous.workflow` | Coordinate (création de 2 tâches exemples) + pipeline. Tout-en-un depuis une liste de titres. |
| `staging.workflow` | Déploiement sur la branche staging (deploy-staging + pipeline). |
| `prompt.workflow` | Entrée langage naturel : décomposition LLM puis coordinateur (LITELLM_API_BASE ou OPENROUTER_API_KEY requis). |

## Usage

```bash
# Lister les workflows (découverte auto)
./scripts/swarm-workflow.sh --list

# Workflow par défaut
./scripts/swarm-workflow.sh

# Par nom court
./scripts/swarm-workflow.sh staging
./scripts/swarm-workflow.sh autonomous

# Par chemin
./scripts/swarm-workflow.sh workflows/staging.workflow
```

## Personnaliser

Copiez un fichier en `workflows/<mon-workflow>.workflow` ; il sera listé avec `--list` et lançable avec `./scripts/swarm-workflow.sh mon-workflow`. Vous pouvez ajouter d'autres étapes (ex. `budget` en début, `clean` en fin).
