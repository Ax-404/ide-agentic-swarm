#!/usr/bin/env bash
# Phase 3 — Dispatch: récupère les issues prêtes (Seeds), crée un worktree par issue,
# écrit TASK.md + .issue_id, marque l'issue in_progress.
# Les issues sont triées par priorité (champ priority dans .seeds/issues.jsonl, plus petite = plus prioritaire).
# Usage: ./scripts/swarm-dispatch.sh [N]   (N = nombre d'agents à lancer, défaut: 2)
# Prérequis: Seeds (sd), dépôt git, .seeds/ initialisé.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_DIR="${REPO_ROOT}/.swarm"
N="${1:-2}"

# Afficher l'aide sans exiger les prérequis
[ "$1" = "-h" ] || [ "$1" = "--help" ] && {
  echo "Usage: $0 [N]   (N = nombre d'agents à lancer, défaut: 2)"
  exit 0
}

"${REPO_ROOT}/scripts/swarm-check.sh" --require seeds --quiet || exit 1
cd "$REPO_ROOT"
source "${REPO_ROOT}/scripts/swarm-common.sh"

# Récupérer les issues ouvertes, triées par priorité (priorité numérique croissante = plus prioritaire en premier).
# Si .seeds/issues.jsonl a un champ priority, on trie ; sinon ordre inchangé.
get_open_issues() {
  if [ -f ".seeds/issues.jsonl" ] && command -v jq >/dev/null 2>&1; then
    jq -r 'select(.status=="open") | "\(.priority // 99)|\(.id)|\(.title)"' .seeds/issues.jsonl 2>/dev/null | sort -t'|' -k1 -n | cut -d'|' -f2-
  else
    sd list --status open --limit 50 2>/dev/null | while read -r line; do
      id=$(echo "$line" | grep -oE 'seeds-[a-zA-Z0-9]+' | head -1)
      [ -n "$id" ] && echo "${id}|$(sd show "$id" 2>/dev/null | head -1 || echo "$id")"
    done
  fi
}

count=0
while IFS='|' read -r issue_id title; do
  [ -z "$issue_id" ] && continue
  count=$((count + 1))
  name="agent-${count}"
  dir="${SWARM_DIR}/${name}"
  branch="swarm/${name}"

  if [ ! -d "$dir" ]; then
    git worktree add "$dir" -b "$branch"
    echo "Créé: $dir (branch $branch)"
  fi

  # Détails de l'issue pour TASK.md (JSONL = une ligne = un objet)
  desc=""
  if command -v jq >/dev/null 2>&1 && [ -f ".seeds/issues.jsonl" ]; then
    while IFS= read -r line; do
      if echo "$line" | jq -e --arg id "$issue_id" 'select(.id==$id)' >/dev/null 2>&1; then
        desc=$(echo "$line" | jq -r '.description // ""')
        break
      fi
    done < .seeds/issues.jsonl
  fi
  [ -z "$title" ] && title="$issue_id"

  swarm_task_md_content "$issue_id" "$title" "$desc" > "${dir}/TASK.md"
  echo "$issue_id" > "${dir}/.issue_id"
  sd update "$issue_id" --status in_progress
  echo "  Assigné: $issue_id → $name (in_progress)"
done < <(get_open_issues | head -n "$N")
# Si aucun agent créé, count=0

if [ "$count" -eq 0 ]; then
  echo "Aucune issue ouverte (sd list --status open). Crée des issues avec sd create ou swarm-seeds-create.sh"
  exit 0
fi

# Phase 4: log
agents_list=$(seq -s ' ' -f 'agent-%g' 1 "$count" 2>/dev/null || true)
[ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" dispatch "$count" $agents_list

echo ""
echo "Dispatch terminé. Lance un terminal par agent:"
for i in $(seq 1 "$count"); do
  echo "  ./scripts/swarm-run.sh agent-$i \${MODEL:-gpt-4o}"
done
echo "Quand chaque agent a fini: sd close <id> --reason \"...\" puis ./scripts/swarm-merge.sh"
