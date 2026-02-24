#!/usr/bin/env bash
# Phase 4 — Dashboard minimal : état des agents, issues et processus.
# Usage: ./scripts/swarm-dashboard.sh [--watch] [--interval SEC]
#   --watch     rafraîchir périodiquement (défaut: toutes les 5 s)
#   --interval  seconde(s) entre chaque rafraîchissement

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_DIR="${REPO_ROOT}/.swarm"
WATCH=""
INTERVAL=5
while [ $# -gt 0 ]; do
  case "$1" in
    --watch)    WATCH=1; shift ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    *) shift ;;
  esac
done

show() {
  [ -d "$SWARM_DIR" ] || { echo "Aucun .swarm/ (aucun agent)."; return; }
  printf "\n  Agent      Issue        Statut issue   PID    Actif\n"
  printf "  ---------- ------------ -------------- ------ -----\n"
  n=0
  for dir in "$SWARM_DIR"/agent-*; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    issue="—"
    status="—"
    [ -f "${dir}/.issue_id" ] && issue=$(cat "${dir}/.issue_id")
    if [ -n "$issue" ] && [ "$issue" != "—" ] && [ -f "${REPO_ROOT}/.seeds/issues.jsonl" ]; then
      while IFS= read -r line; do
        if echo "$line" | grep -q "\"id\":\"$issue\""; then
          status=$(echo "$line" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
          break
        fi
      done < "${REPO_ROOT}/.seeds/issues.jsonl"
    fi
    pid="—"
    alive="—"
    if [ -f "${dir}/.pid" ]; then
      pid=$(cat "${dir}/.pid" 2>/dev/null)
      if kill -0 "$pid" 2>/dev/null; then
        alive="oui"
      else
        alive="non"
      fi
    fi
    printf "  %-10s %-12s %-14s %-6s %s\n" "$name" "$issue" "$status" "$pid" "$alive"
    n=$((n + 1))
  done
  [ "$n" -eq 0 ] && echo "  (aucun worktree agent-*)"
  [ -x "${REPO_ROOT}/scripts/swarm-mail.sh" ] && "${REPO_ROOT}/scripts/swarm-mail.sh" show 5
}

do_show() {
  clear 2>/dev/null || true
  echo "=== Swarm dashboard — $(date '+%Y-%m-%d %H:%M:%S') ==="
  show
  [ -f "${SWARM_DIR}/logs/events.log" ] && echo "Derniers événements (log):" && tail -5 "${SWARM_DIR}/logs/events.log"
}

if [ -n "$WATCH" ]; then
  while true; do
    do_show
    sleep "$INTERVAL"
  done
else
  do_show
fi
