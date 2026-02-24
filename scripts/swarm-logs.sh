#!/usr/bin/env bash
# Phase 4 — Affiche les logs centralisés (.swarm/logs/events.log).
# Usage: ./scripts/swarm-logs.sh [--tail] [--lines N]
#   --tail   suivre les nouvelles lignes (comme tail -f)
#   --lines  nombre de lignes à afficher (défaut: 50)

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="${REPO_ROOT}/.swarm/logs/events.log"
LINES=50
TAIL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tail)   TAIL=1; shift ;;
    --lines)  LINES="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -f "$LOG_FILE" ] || { echo "Aucun log (fichier absent)."; exit 0; }
if [ -n "$TAIL" ]; then
  tail -f -n "$LINES" "$LOG_FILE"
else
  tail -n "$LINES" "$LOG_FILE"
fi
