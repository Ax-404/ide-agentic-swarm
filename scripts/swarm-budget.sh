#!/usr/bin/env bash
# Lot 3 — Vérification du budget (coûts) : compare un montant courant à une limite et alerte si dépassement.
# Usage: ./scripts/swarm-budget.sh
#   Lit SWARM_BUDGET_MAX (ex: 10.00), et soit SWARM_CURRENT_SPEND (ex: 5.25), soit le fichier .swarm/costs/current_spend (une ligne = montant).
#   Si SWARM_CURRENT_SPEND ou fichier > SWARM_BUDGET_MAX : exit 1 et alerte (swarm-alert.sh budget_exceeded).
#   Sinon affiche le résumé et exit 0.
# Pour alimenter le montant courant : exporter depuis LiteLLM (DB, /global/spend/report) vers .swarm/costs/current_spend ou env SWARM_CURRENT_SPEND.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COSTS_DIR="${REPO_ROOT}/.swarm/costs"
SPEND_FILE="${COSTS_DIR}/current_spend"
MAX="${SWARM_BUDGET_MAX:-}"
CURRENT="${SWARM_CURRENT_SPEND:-}"

if [ -z "$MAX" ]; then
  echo "SWARM_BUDGET_MAX non défini. Pour activer la vérification :"
  echo "  export SWARM_BUDGET_MAX=10.00   # limite en € (ou \$)"
  echo "  export SWARM_CURRENT_SPEND=0    # ou écrire le montant dans .swarm/costs/current_spend"
  echo "Voir docs/workflows/phase6-workflow.md (lot 3, coûts)."
  exit 0
fi

[ -f "$SPEND_FILE" ] && CURRENT=$(head -1 "$SPEND_FILE")
[ -z "$CURRENT" ] && CURRENT=0

# Comparaison (bc si dispo, sinon awk)
if command -v bc >/dev/null 2>&1; then
  EXCEEDED=$(echo "$CURRENT > $MAX" | bc 2>/dev/null || echo 0)
else
  EXCEEDED=$(awk -v c="$CURRENT" -v m="$MAX" 'BEGIN { print (c+0 > m+0) ? 1 : 0 }' 2>/dev/null || echo 0)
fi

echo "Budget: dépense courante=$CURRENT, max=$MAX"
if [ "${EXCEEDED:-0}" = "1" ]; then
  echo "DÉPASSEMENT: budget dépassé."
  [ -x "${REPO_ROOT}/scripts/swarm-alert.sh" ] && "${REPO_ROOT}/scripts/swarm-alert.sh" budget_exceeded "spend=$CURRENT max=$MAX"
  exit 1
fi
echo "OK: sous la limite."
exit 0
