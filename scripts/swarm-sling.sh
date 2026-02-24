#!/usr/bin/env bash
# Phase 3 — Sling: lance un agent pour une issue Seeds donnée (création worktree + TASK + claim).
# Usage: ./scripts/swarm-sling.sh <issue-id> [model]
# Exemple: ./scripts/swarm-sling.sh seeds-a1b2 gpt-4o
# Prérequis: Seeds (sd), dépôt git, .seeds/ initialisé.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_DIR="${REPO_ROOT}/.swarm"

# Afficher l'aide sans exiger les prérequis
[ "$1" = "-h" ] || [ "$1" = "--help" ] && {
  echo "Usage: $0 <issue-id> [model]"
  echo "Exemple: $0 seeds-a1b2 gpt-4o"
  exit 0
}

ISSUE_ID="${1:?Usage: $0 <issue-id> [model]}"
MODEL="${2:-gpt-4o}"

"${REPO_ROOT}/scripts/swarm-check.sh" --require seeds --quiet || exit 1
cd "$REPO_ROOT"
source "${REPO_ROOT}/scripts/swarm-common.sh"

# Nom worktree = agent-<court id> pour éviter conflits
short_id=$(echo "$ISSUE_ID" | tr -dc 'a-zA-Z0-9' | head -c 12)
name="agent-${short_id}"
dir="${SWARM_DIR}/${name}"
branch="swarm/${name}"

if [ ! -d "$dir" ]; then
  git worktree add "$dir" -b "$branch"
  echo "Créé: $dir (branch $branch)"
fi

# Détails issue
title=$(sd show "$ISSUE_ID" 2>/dev/null | head -1 || echo "$ISSUE_ID")
desc=""
if command -v jq >/dev/null 2>&1 && [ -f ".seeds/issues.jsonl" ]; then
  while IFS= read -r line; do
    if echo "$line" | jq -e --arg id "$ISSUE_ID" 'select(.id==$id)' >/dev/null 2>&1; then
      desc=$(echo "$line" | jq -r '.description // ""')
      [ -z "$title" ] && title=$(echo "$line" | jq -r '.title // "'"$ISSUE_ID"'"/')
      break
    fi
  done < .seeds/issues.jsonl
fi
[ -z "$title" ] && title="$ISSUE_ID"

swarm_task_md_content "$ISSUE_ID" "$title" "$desc" > "${dir}/TASK.md"
echo "$ISSUE_ID" > "${dir}/.issue_id"
sd update "$ISSUE_ID" --status in_progress
[ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" sling "$ISSUE_ID" "$name" "$MODEL"
echo "Issue $ISSUE_ID → $name (in_progress). Lancement Aider..."
echo ""
exec "${REPO_ROOT}/scripts/swarm-run.sh" "$name" "$MODEL"