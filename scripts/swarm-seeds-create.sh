#!/usr/bin/env bash
# Phase 2 — Initialise Seeds (sd) et crée une issue par sous-tâche pour les agents.
# Usage: ./scripts/swarm-seeds-create.sh "Titre tâche 1" "Titre tâche 2" [...]
# À lancer depuis la racine du dépôt (avant ou après swarm-setup.sh).
# Prérequis: Seeds installé (sd en PATH, voir https://github.com/jayminwest/seeds).

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v sd >/dev/null 2>&1; then
  echo "Erreur: 'sd' (Seeds) introuvable. Install: git clone https://github.com/jayminwest/seeds && cd seeds && bun install && bun link"
  exit 1
fi

if [ ! -d ".seeds" ]; then
  echo "Initialisation de Seeds dans le projet..."
  sd init
  echo ""
fi

if [ $# -eq 0 ]; then
  echo "Usage: $0 \"Titre tâche 1\" \"Titre tâche 2\" [...], ex. $0 \"Auth login\" \"Logs middleware\""
  exit 0
fi

echo "Création de $# issue(s)..."
agent_num=1
for title in "$@"; do
  out=$(sd create --title "$title" --type task --priority 2 --json 2>/dev/null) || true
  id=$(echo "$out" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
  if [ -n "$id" ]; then
    echo "  agent-${agent_num}: $id — $title"
    agent_num=$((agent_num + 1))
  else
    echo "  Erreur création: $title"
  fi
done

echo ""
echo "Pour assigner une issue à un agent, dans le worktree de l’agent:"
echo "  sd update <id> --status in_progress"
echo "En fin de tâche:"
echo "  sd close <id> --reason \"Résumé de ce qui a été fait\""
echo "Puis merger les branches (./scripts/swarm-merge.sh) ; .seeds/ fusionne avec merge=union."
