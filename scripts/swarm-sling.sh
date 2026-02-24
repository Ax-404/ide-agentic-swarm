#!/usr/bin/env bash
# Phase 3 — Sling: lance un agent pour une issue Seeds donnée (création worktree + TASK + claim).
# Usage: ./scripts/swarm-sling.sh <issue-id> [model]
# Exemple: ./scripts/swarm-sling.sh seeds-a1b2 gpt-4o
# Prérequis: Seeds (sd), dépôt git, .seeds/ initialisé.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_DIR="${REPO_ROOT}/.swarm"
ISSUE_ID="${1:?Usage: $0 <issue-id> [model]}"
MODEL="${2:-gpt-4o}"

if ! command -v sd >/dev/null 2>&1; then
  echo "Erreur: 'sd' (Seeds) introuvable. Voir https://github.com/jayminwest/seeds"
  exit 1
fi

cd "$REPO_ROOT"
[ -d ".seeds" ] || { echo "Erreur: .seeds/ introuvable. Lance 'sd init' à la racine."; exit 1; }

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

cat > "${dir}/TASK.md" << EOF
# Tâche: $title

Issue: **$ISSUE_ID** (Seeds). En fin de session: \`sd close $ISSUE_ID --reason "Résumé"\`

$desc

## En cas de blocage ou pour passer la main

Si tu bloques ou si un autre agent doit prendre la suite : \`../../scripts/swarm-mail.sh send --to coordinator --type help_request --body "..."\` ou \`--to agent-X --type handoff --body "..."\`. Voir : \`./scripts/swarm-mail.sh show\` (depuis la racine).
EOF
echo "$ISSUE_ID" > "${dir}/.issue_id"
sd update "$ISSUE_ID" --status in_progress
[ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" sling "$ISSUE_ID" "$name" "$MODEL"
echo "Issue $ISSUE_ID → $name (in_progress). Lancement Aider..."
echo ""
exec "${REPO_ROOT}/scripts/swarm-run.sh" "$name" "$MODEL"