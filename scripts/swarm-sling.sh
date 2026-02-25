#!/usr/bin/env bash
# Phase 3 — Sling: lance un agent pour une issue Seeds donnée (création worktree + TASK + .role + claim).
# Rôle(s): Builder (défaut) ou Scout si titre issue commence par [Scout] ou si 3e arg = scout. Voir docs/ROLES.md.
# Usage: ./scripts/swarm-sling.sh <issue-id> [model] [role]
#   role = scout | builder | reviewer | documenter | red-team (optionnel).
# Exemple: ./scripts/swarm-sling.sh seeds-a1b2 sonnet-4.6
#          ./scripts/swarm-sling.sh seeds-xxx sonnet-4.6 scout
# Prérequis: Seeds (sd), dépôt git, .seeds/ initialisé.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_DIR="${REPO_ROOT}/.swarm"

# Afficher l'aide sans exiger les prérequis
[ "$1" = "-h" ] || [ "$1" = "--help" ] && {
  echo "Usage: $0 <issue-id> [model] [role]"
  echo "Exemple: $0 seeds-a1b2 sonnet-4.6"
  echo "         $0 seeds-xxx sonnet-4.6 scout"
  exit 0
}

ISSUE_ID="${1:?Usage: $0 <issue-id> [model] [role]}"
MODEL="${2:-sonnet-4.6}"
ROLE_ARG="${3:-}"

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

# Rôle : 3e argument ou préfixe dans le titre (voir docs/ROLES.md)
ROLE="builder"
if [ -n "$ROLE_ARG" ]; then
  case "$ROLE_ARG" in
    scout)      ROLE="scout" ;;
    reviewer)   ROLE="reviewer" ;;
    documenter) ROLE="documenter" ;;
    red-team)   ROLE="red-team" ;;
    *)          ROLE="builder" ;;
  esac
fi
if [ "$ROLE" = "builder" ]; then
  if [[ "$title" =~ ^\[Scout\] ]]; then
    ROLE="scout"
    title=$(echo "$title" | sed 's/^\[Scout\] *//')
  elif [[ "$title" =~ ^\[Reviewer\] ]]; then
    ROLE="reviewer"
    title=$(echo "$title" | sed 's/^\[Reviewer\] *//')
  elif [[ "$title" =~ ^\[Documenter\] ]]; then
    ROLE="documenter"
    title=$(echo "$title" | sed 's/^\[Documenter\] *//')
  elif [[ "$title" =~ ^\[Red-team\] ]]; then
    ROLE="red-team"
    title=$(echo "$title" | sed 's/^\[Red-team\] *//')
  fi
fi
title_for_task="$title"
echo "$ROLE" > "${dir}/.role"
swarm_task_md_content "$ISSUE_ID" "$title_for_task" "$desc" > "${dir}/TASK.md"
echo "$ISSUE_ID" > "${dir}/.issue_id"
sd update "$ISSUE_ID" --status in_progress
[ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" sling "$ISSUE_ID" "$name" "$MODEL"
echo "Issue $ISSUE_ID → $name ($ROLE, in_progress). Lancement Aider..."
echo ""
exec "${REPO_ROOT}/scripts/swarm-run.sh" "$name" "$MODEL" "$ROLE"