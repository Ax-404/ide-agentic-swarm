#!/usr/bin/env bash
# Phase 5 — Résumé des sessions agents (depuis events.log) et rappel pour les coûts réels (proxy LiteLLM).
# Usage: ./scripts/swarm-costs.sh
# Les coûts en tokens/€ dépendent du proxy LiteLLM (DB, en-tête x-litellm-response-cost, /global/spend/report).

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="${REPO_ROOT}/.swarm/logs/events.log"

echo "=== Sessions agents (depuis .swarm/logs/events.log) ==="
if [ -f "$LOG_FILE" ]; then
  sessions=$(grep -c "agent_start" "$LOG_FILE" 2>/dev/null || echo "0")
  echo "  Nombre de démarrages d'agents (agent_start): $sessions"
  echo ""
  echo "  Derniers agent_start:"
  grep "agent_start" "$LOG_FILE" 2>/dev/null | tail -10 || true
else
  echo "  Aucun fichier de log (pas encore de sessions)."
fi

echo ""
echo "=== Coûts réels (tokens / €) ==="
echo "  Les coûts dépendent du proxy LiteLLM sur le Mac Mini."
echo "  - En-tête de réponse: x-litellm-response-cost (si activé)"
echo "  - Avec base de données (PostgreSQL): spend tracking et /global/spend/report"
echo "  - Doc: https://docs.litellm.ai/docs/proxy/cost_tracking"
echo ""
echo "  Ce script ne lit pas les coûts côté proxy; il ne compte que les événements locaux (sessions)."
