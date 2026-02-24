#!/usr/bin/env bash
# Handoff automatisé : lit les messages mail de type handoff, réassigne l'issue à l'agent cible et met à jour TASK.md.
# Usage: ./scripts/swarm-handoff.sh [--limit N] [--dry-run]
#        ./scripts/swarm-handoff.sh list [--limit N]
#   list     : affiche les derniers handoffs sans appliquer.
#   (défaut) : pour chaque handoff (to=agent-X, issue_id optionnel, body), crée ou met à jour le worktree de l'agent cible,
#              écrit .issue_id et TASK.md (contexte handoff), met l'issue en in_progress.
# Prérequis: Seeds (sd), jq, .seeds/, .swarm/mail/messages.jsonl.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_DIR="${REPO_ROOT}/.swarm"
MAIL_FILE="${REPO_ROOT}/.swarm/mail/messages.jsonl"

# Afficher l'aide sans exiger les prérequis
[ "$1" = "-h" ] || [ "$1" = "--help" ] && {
  echo "Usage: $0 [--limit N] [--dry-run]   # Traiter les derniers handoffs (réassigner issue + TASK.md)"
  echo "       $0 list [--limit N]           # Afficher les handoffs sans appliquer"
  echo "  --limit N : nombre max de handoffs à traiter (défaut 10)."
  exit 0
}

LIST_ONLY=""
LIMIT="10"
DRY_RUN=""
while [ $# -gt 0 ]; do
  case "$1" in
    list)     LIST_ONLY=1; shift ;;
    --limit)  LIMIT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *)        shift ;;
  esac
done

"${REPO_ROOT}/scripts/swarm-check.sh" --require seeds --require jq --quiet || exit 1
cd "$REPO_ROOT"
source "${REPO_ROOT}/scripts/swarm-common.sh"

[ -f "$MAIL_FILE" ] || { echo "Aucun fichier mail (.swarm/mail/messages.jsonl)."; exit 0; }

# Extraire les handoffs : to, from, issue_id, body (priorité décroissante = plus récent en dernier si tail)
handoffs() {
  tail -n 500 "$MAIL_FILE" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "$line" | jq -c -e 'select(.type=="handoff")' 2>/dev/null || true
  done | tail -n "$LIMIT"
}

if [ -n "$LIST_ONLY" ]; then
  echo "=== Derniers handoffs (limit $LIMIT) ==="
  handoffs | while IFS= read -r line; do
    [ -z "$line" ] && continue
    to=$(echo "$line" | jq -r '.to // "?"')
    from=$(echo "$line" | jq -r '.from // "?"')
    issue_id=$(echo "$line" | jq -r '.issue_id // ""')
    body=$(echo "$line" | jq -r '.body // ""' | head -c 60)
    echo "  $from → $to (issue: ${issue_id:-création}) $body..."
  done
  exit 0
fi

count=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  to=$(echo "$line" | jq -r '.to // ""')
  from=$(echo "$line" | jq -r '.from // "?"')
  issue_id=$(echo "$line" | jq -r '.issue_id // ""')
  body=$(echo "$line" | jq -r '.body // ""')
  [ -z "$to" ] && continue
  # Destinataire doit être un agent (agent-X)
  case "$to" in
    agent-*) ;;
    *) echo "  Ignoré (to non-agent): $to"; continue ;;
  esac

  if [ -n "$DRY_RUN" ]; then
    echo "  [dry-run] $from → $to issue=${issue_id:-nouvelle} body=${body:0:40}..."
    count=$((count + 1))
    continue
  fi

  # Créer ou récupérer l'issue
  if [ -z "$issue_id" ]; then
    title="Handoff: $(echo "$body" | head -1 | head -c 80)"
    issue_id=$(sd create --title "$title" --type task --priority 2 --json 2>/dev/null | jq -r '.id // empty')
    [ -z "$issue_id" ] && { echo "  Erreur: impossible de créer l'issue pour handoff $from → $to"; continue; }
    echo "  Créé issue $issue_id pour handoff → $to"
  else
    # Vérifier que l'issue existe
    sd show "$issue_id" >/dev/null 2>&1 || { echo "  Erreur: issue $issue_id introuvable"; continue; }
  fi

  dir="${SWARM_DIR}/${to}"
  branch="swarm/${to}"
  if [ ! -d "$dir" ]; then
    git worktree add "$dir" -b "$branch"
    echo "  Créé worktree: $dir"
  fi

  title=$(sd show "$issue_id" 2>/dev/null | head -1 || echo "$issue_id")
  desc=""
  if [ -f ".seeds/issues.jsonl" ]; then
    while IFS= read -r l; do
      if echo "$l" | jq -e --arg id "$issue_id" 'select(.id==$id)' >/dev/null 2>&1; then
        desc=$(echo "$l" | jq -r '.description // ""')
        [ -z "$title" ] && title=$(echo "$l" | jq -r '.title // "'"$issue_id"'"/')
        break
      fi
    done < .seeds/issues.jsonl
  fi
  [ -z "$title" ] && title="$issue_id"

  # TASK.md avec contexte handoff (extra = section Handoff depuis $from)
  extra=$'## Handoff depuis '"$from"$'\n\n'"$body"
  swarm_task_md_content "$issue_id" "$title" "$desc" "$extra" > "${dir}/TASK.md"
  echo "$issue_id" > "${dir}/.issue_id"
  sd update "$issue_id" --status in_progress
  echo "  Assigné: $issue_id → $to (in_progress)"
  count=$((count + 1))
done < <(handoffs)

[ -z "$DRY_RUN" ] && [ "$count" -gt 0 ] && echo "" && echo "Handoff(s) appliqué(s). Lance l'agent avec: ./scripts/swarm-run.sh <agent> \${MODEL:-gpt-4o}"
