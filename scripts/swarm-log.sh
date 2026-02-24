#!/usr/bin/env bash
# Phase 4 — Écrit une ligne dans le log centralisé .swarm/logs/events.log
# Usage: ./scripts/swarm-log.sh <event> [détail...]
# Exemple: ./scripts/swarm-log.sh agent_start agent-1 gpt-4o
#          ./scripts/swarm-log.sh dispatch 2
# Appelé par les autres scripts swarm-* pour tracer les événements.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${REPO_ROOT}/.swarm/logs"
LOG_FILE="${LOG_DIR}/events.log"
mkdir -p "$LOG_DIR"
echo "$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S') $*" >> "$LOG_FILE"
