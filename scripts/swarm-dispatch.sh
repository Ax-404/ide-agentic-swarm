#!/usr/bin/env bash
# Phase 3 — Dispatch: récupère les issues prêtes (Seeds), crée un worktree par issue,
# écrit TASK.md + .issue_id, marque l'issue in_progress.
# Usage: ./scripts/swarm-dispatch.sh [N]   (N = nombre d'agents à lancer, défaut: 2)
# Prérequis: Seeds (sd), dépôt git, .seeds/ initialisé.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_DIR="${REPO_ROOT}/.swarm"
N="${1:-2}"

if ! command -v sd >/dev/null 2>&1; then
  echo "Erreur: 'sd' (Seeds) introuvable. Voir https://github.com/jayminwest/seeds"
  exit 1
fi

cd "$REPO_ROOT"
[ -d ".seeds" ] || { echo "Erreur: .seeds/ introuvable. Lance 'sd init' à la racine."; exit 1; }

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Erreur: pas un dépôt git."
  exit 1
fi

# Récupérer les issues ouvertes (ready = sans blocage). On utilise sd list pour avoir id + title.
# sd list --status open --json peut varier; on lit .seeds/issues.jsonl pour robustesse.
get_open_issues() {
  if [ -f ".seeds/issues.jsonl" ] && command -v jq >/dev/null 2>&1; then
    while IFS= read -r line; do
      echo "$line" | jq -r 'select(.status=="open")? | "\(.id)|\(.title)"' 2>/dev/null
    done < .seeds/issues.jsonl
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

  cat > "${dir}/TASK.md" << EOF
# Tâche: $title

Issue: **$issue_id** (Seeds). En fin de session: \`sd close $issue_id --reason "Résumé"\`

$desc

## En cas de blocage ou pour passer la main

Si tu bloques ou si un autre agent doit prendre la suite, envoie un message : \`../../scripts/swarm-mail.sh send --to coordinator --type help_request --body "..."\` ou \`--to agent-X --type handoff --body "..."\`. Voir les messages : \`./scripts/swarm-mail.sh show\` (depuis la racine).
EOF
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
