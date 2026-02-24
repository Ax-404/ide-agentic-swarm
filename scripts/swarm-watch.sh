#!/usr/bin/env bash
# Phase 4 — Watchdog : vérifie que les processus Aider (PIDs dans .swarm/agent-*/.pid) sont vivants.
# Usage: ./scripts/swarm-watch.sh [--interval SEC] [--once] [--relaunch]
#   --interval SEC  (défaut: 30) seconde(s) entre chaque vérification
#   --once          une seule passe, puis quitter
#   --relaunch      relancer automatiquement un agent dont le processus est mort (nohup en arrière-plan)
# Tourne en avant-plan par défaut ; pour garder en arrière-plan : nohup ./scripts/swarm-watch.sh &

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_DIR="${REPO_ROOT}/.swarm"
INTERVAL=30
ONCE=""
RELAUNCH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --interval) INTERVAL="$2"; shift 2 ;;
    --once)     ONCE=1; shift ;;
    --relaunch) RELAUNCH=1; shift ;;
    *) shift ;;
  esac
done

log_event() {
  "${REPO_ROOT}/scripts/swarm-log.sh" "$@"
}

while true; do
  [ -d "$SWARM_DIR" ] || break
  for dir in "$SWARM_DIR"/agent-*; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    pid_file="${dir}/.pid"
    [ -f "$pid_file" ] || continue
    pid=$(cat "$pid_file" 2>/dev/null)
    [ -n "$pid" ] || continue
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "$(date -Iseconds 2>/dev/null || date '+%H:%M:%S') [watch] $name (PID $pid) n'est plus actif."
      log_event watch_dead "$name" "pid=$pid"
      rm -f "$pid_file"
      if [ -n "$RELAUNCH" ]; then
        echo "  Relance: nohup $REPO_ROOT/scripts/swarm-run.sh $name gpt-4o &"
        nohup "${REPO_ROOT}/scripts/swarm-run.sh" "$name" gpt-4o >> "${dir}/.relaunch.log" 2>&1 &
        log_event watch_relaunch "$name"
      fi
    fi
  done
  [ -n "$ONCE" ] && break
  sleep "$INTERVAL"
done
