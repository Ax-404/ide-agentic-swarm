# Coûts LiteLLM et boucle budget

Les **vrais coûts** (tokens, €) viennent du proxy LiteLLM. Ce document décrit comment les récupérer et alimenter la boucle budget du swarm (`swarm-budget.sh`).

## Où sont les coûts côté LiteLLM

- **En-tête de réponse** : `x-litellm-response-cost` (si activé dans LiteLLM).
- **Base de données** (PostgreSQL, etc.) : tables de suivi des appels / dépenses.
- **Endpoint** : `/global/spend/report` (ou équivalent selon la version LiteLLM).

Documentation LiteLLM : [Cost tracking](https://docs.litellm.ai/docs/proxy/cost_tracking).

## Alimenter le swarm

`swarm-budget.sh` lit :

1. **Variable d'environnement** : `SWARM_CURRENT_SPEND` (ex. `5.25`).
2. **Fichier** : `.swarm/costs/current_spend` (une ligne = montant courant, ex. `5.25`).

Si l'un des deux est renseigné, il est utilisé pour comparer à `SWARM_BUDGET_MAX`. En cas de dépassement, le script sort en erreur et peut déclencher une alerte (`swarm-alert.sh budget_exceeded`).

### Méthode 1 : export manuel

Après avoir récupéré le montant depuis LiteLLM (DB, dashboard, script) :

```bash
export SWARM_CURRENT_SPEND=5.25
export SWARM_BUDGET_MAX=10.00
./scripts/swarm-budget.sh
```

### Méthode 2 : fichier `.swarm/costs/current_spend`

Créer le répertoire et écrire le montant (une ligne) :

```bash
mkdir -p .swarm/costs
echo "5.25" > .swarm/costs/current_spend
SWARM_BUDGET_MAX=10.00 ./scripts/swarm-budget.sh
```

Un cron ou un script peut mettre à jour ce fichier à partir de LiteLLM (API, requête SQL, curl sur `/global/spend/report`, etc.).

### Méthode 3 : script d’import (exemple)

Exemple d’un script qui lit un montant depuis une API ou un fichier et met à jour `.swarm/costs/current_spend` :

```bash
#!/usr/bin/env bash
# Exemple : récupérer le spend depuis LiteLLM (adapter l'URL et le parsing selon votre setup).
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COSTS_DIR="${REPO_ROOT}/.swarm/costs"
SPEND_FILE="${COSTS_DIR}/current_spend"
mkdir -p "$COSTS_DIR"

# Exemple 1 : fichier exporté par LiteLLM (chemin à adapter)
# LITELLM_SPEND_FILE="/var/lib/litellm/spend_report.txt"
# [ -f "$LITELLM_SPEND_FILE" ] && cp "$LITELLM_SPEND_FILE" "$SPEND_FILE"

# Exemple 2 : curl sur l'API proxy (nécessite une URL et un format de réponse connus)
# TOTAL=$(curl -sS "${LITELLM_PROXY_URL}/global/spend/report" | jq -r '.total_spend // 0')
# echo "$TOTAL" > "$SPEND_FILE"

# Exemple 3 : valeur fixe pour test
echo "${SWARM_CURRENT_SPEND:-0}" > "$SPEND_FILE"
echo "Écrit: $(cat "$SPEND_FILE") dans $SPEND_FILE"
```

Adapter selon votre déploiement LiteLLM (variables d’environnement, chemin du rapport, format JSON, etc.).

## Intégration dans le pipeline

Pour vérifier le budget avant ou après une phase coûteuse :

```bash
SWARM_BUDGET_MAX=10.00 ./scripts/swarm-budget.sh || exit 1
./scripts/swarm-pipeline.sh 2
# Optionnel : mettre à jour current_spend après le run (script d’import ci‑dessus)
```

Voir aussi : [phase6-workflow.md](workflows/phase6-workflow.md) (lot 3, coûts), [swarm-costs.sh](../scripts/swarm-costs.sh) (sessions locales).
