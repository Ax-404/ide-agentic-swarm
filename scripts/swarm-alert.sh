#!/usr/bin/env bash
# Lot 3 — Envoi d'alertes en cas d'échec ou régression (hook script, Slack).
# Usage: ./scripts/swarm-alert.sh <event_type> [message]
#   event_type = merge_conflict | tests_failed | pipeline_failed | budget_exceeded
# Config: SWARM_ALERT_HOOK (script exécutable appelé avec event_type et message)
#         SWARM_SLACK_WEBHOOK_URL (URL webhook Slack Incoming)
# Les deux peuvent être définis ; les deux sont appelés si présents.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVENT="${1:-unknown}"
MSG="${2:-}"
TEXT="[swarm] $EVENT — $MSG"
export SWARM_ALERT_EVENT="$EVENT"
export SWARM_ALERT_MESSAGE="$MSG"

# Log central (optionnel)
[ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" alert "$EVENT" "$MSG"

# Hook personnalisé (script ou commande)
if [ -n "$SWARM_ALERT_HOOK" ]; then
  if [ -x "$SWARM_ALERT_HOOK" ]; then
    "$SWARM_ALERT_HOOK" "$EVENT" "$MSG" 2>/dev/null || true
  elif command -v "$SWARM_ALERT_HOOK" >/dev/null 2>&1; then
    $SWARM_ALERT_HOOK "$EVENT" "$MSG" 2>/dev/null || true
  fi
fi

# Slack Incoming Webhook
if [ -n "$SWARM_SLACK_WEBHOOK_URL" ]; then
  PAYLOAD=$(printf '{"text":"%s"}' "$(echo "$TEXT" | sed 's/\\/\\\\/g;s/"/\\"/g')')
  curl -sS -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$SWARM_SLACK_WEBHOOK_URL" >/dev/null 2>&1 || true
fi
