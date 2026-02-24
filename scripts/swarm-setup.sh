#!/usr/bin/env bash
# Phase 2 — Crée N worktrees (ou répertoires) pour N agents.
# Usage: ./scripts/swarm-setup.sh [N]   (défaut: 2)
# Prérequis: dépôt git initialisé (git init + au moins un commit).

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_DIR="${REPO_ROOT}/.swarm"
DEFAULT_AGENTS=2
N="${1:-$DEFAULT_AGENTS}"

if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Erreur: pas un dépôt git. Depuis la racine du projet:"
  echo "  git init && git add . && git commit -m 'initial'"
  exit 1
fi

mkdir -p "$SWARM_DIR"
cd "$REPO_ROOT"

for i in $(seq 1 "$N"); do
  name="agent-${i}"
  dir="${SWARM_DIR}/${name}"
  branch="swarm/${name}"
  if [ -d "$dir" ]; then
    echo "Déjà existant: $dir (ignoré)"
    continue
  fi
  git worktree add "$dir" -b "$branch"
  cp -f "${REPO_ROOT}/templates/TASK.md" "$dir/TASK.md" 2>/dev/null || true
  echo "Créé: $dir (branch $branch)"
done

echo ""
echo "Worktrees créés dans .swarm/"
echo "Édite .swarm/agent-X/TASK.md pour définir la tâche de chaque agent."
echo "Lance chaque agent dans un terminal: ./scripts/swarm-run.sh agent-X [modèle]"
