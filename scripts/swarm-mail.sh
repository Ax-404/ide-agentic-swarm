#!/usr/bin/env bash
# Couche mail (type Overstory) — en plus de Seeds : messages entre agents, retours en cours de tâche, handoffs, événements.
# Prérequis : jq recommandé pour send/list/show (JSON fiable). Sans jq, un fallback manuel est utilisé pour send ;
#   list/show affichent les lignes brutes. En cas de corps contenant guillemets ou retours à la ligne, installer jq évite les erreurs.
# Usage:
#   swarm-mail.sh send --from agent-1 --to coordinator --type help_request --body "Conflit dans src/auth.ts"
#   swarm-mail.sh send --from agent-1 --to agent-2 --type handoff --body "Validation faite, voir src/validator.ts" [--issue-id seeds-xxx]
#   swarm-mail.sh list [--to agent-2] [--from agent-1] [--type handoff] [--issue-id seeds-xxx] [--limit N] [--priority-first]
# Types: progress | blocked | help_request | handoff | event
# Destinataires: coordinator | agent-X | broadcast | issue:seeds-xxx
# Depuis un worktree, --from peut être omis (détecté depuis le chemin).
# Stockage: .swarm/mail/messages.jsonl (append-only, local au run).

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAIL_DIR="${REPO_ROOT}/.swarm/mail"
MAIL_FILE="${MAIL_DIR}/messages.jsonl"

mkdir -p "$MAIL_DIR"

# Générer un id unique pour un message
gen_id() {
  if command -v uuidgen >/dev/null 2>&1; then
    echo "mail-$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-' | head -c 12)"
  else
    echo "mail-$(date +%s)-$$-${RANDOM:-0}"
  fi
}

# Détecter l'agent courant depuis le CWD (si on est dans un worktree .swarm/agent-X)
detect_from() {
  local cwd="${PWD:-.}"
  if [[ "$cwd" =~ \.swarm/(agent-[^/]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

cmd_send() {
  local from="" to="" type="" body="" issue_id="" priority="" payload="{}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --from)     from="$2"; shift 2 ;;
      --to)       to="$2"; shift 2 ;;
      --type)     type="$2"; shift 2 ;;
      --body)     body="$2"; shift 2 ;;
      --issue-id) issue_id="$2"; shift 2 ;;
      --priority) priority="$2"; shift 2 ;;
      --payload)  payload="$2"; shift 2 ;;
      *)          echo "Usage: $0 send --from AGENT --to DEST --type TYPE --body \"...\" [--issue-id ID] [--priority 1-5] [--payload '{}']"; exit 1 ;;
    esac
  done
  [ -z "$from" ] && from=$(detect_from)
  [ -z "$to" ] && { echo "Erreur: --to requis (coordinator, agent-X, broadcast, issue:seeds-xxx)"; exit 1; }
  [ -z "$type" ] && { echo "Erreur: --type requis (progress|blocked|help_request|handoff|event)"; exit 1; }
  [ -z "$body" ] && { echo "Erreur: --body requis"; exit 1; }
  case "$type" in
    progress|blocked|help_request|handoff|event) ;;
    *) echo "Erreur: type doit être progress|blocked|help_request|handoff|event"; exit 1 ;;
  esac
  local ts
  ts=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')
  local id
  id=$(gen_id)
  if command -v jq >/dev/null 2>&1; then
    local line
    line=$(jq -c -n \
      --arg id "$id" \
      --arg ts "$ts" \
      --arg from "${from:-unknown}" \
      --arg to "$to" \
      --arg type "$type" \
      --arg body "$body" \
      --arg issue_id "$issue_id" \
      --arg priority "${priority:-3}" \
      '{id:$id, ts:$ts, from:$from, to:$to, type:$type, body:$body, issue_id:(if $issue_id=="" then null else $issue_id end), priority:($priority|tonumber? // 3)}' 2>/dev/null)
    echo "$line" >> "$MAIL_FILE"
  else
    # Fallback sans jq : échappement JSON manuel (backslash, guillemets, tab, CR, NL). Pour un usage fiable, installer jq.
    local escaped
    escaped=$(echo "$body" | sed 's/\\/\\\\/g;s/"/\\"/g;s/\t/\\t/g;s/\r/\\r/g;s/\n/\\n/g')
    local issue_json="null"
    [ -n "$issue_id" ] && issue_json="\"$(echo "$issue_id" | sed 's/\\/\\\\/g;s/"/\\"/g')\""
    local p="${priority:-3}"
    case "$p" in [0-9]*) ;; *) p=3 ;; esac
    echo "{\"id\":\"$id\",\"ts\":\"$ts\",\"from\":\"${from:-unknown}\",\"to\":\"$to\",\"type\":\"$type\",\"body\":\"$escaped\",\"issue_id\":$issue_json,\"priority\":$p}" >> "$MAIL_FILE"
  fi
  echo "$id"
}

cmd_list() {
  local to="" from="" type="" issue_id="" limit="50" priority_first=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --to)        to="$2"; shift 2 ;;
      --from)      from="$2"; shift 2 ;;
      --type)      type="$2"; shift 2 ;;
      --issue-id)  issue_id="$2"; shift 2 ;;
      --limit)     limit="$2"; shift 2 ;;
      --priority-first) priority_first=1; shift ;;
      *) shift ;;
    esac
  done
  [ ! -f "$MAIL_FILE" ] && { echo "Aucun message."; return 0; }
  if command -v jq >/dev/null 2>&1; then
    local filter="."
    [ -n "$to" ] && filter="$filter | select(.to==\"$to\" or .to==\"broadcast\")"
    [ -n "$from" ] && filter="$filter | select(.from==\"$from\")"
    [ -n "$type" ] && filter="$filter | select(.type==\"$type\")"
    [ -n "$issue_id" ] && filter="$filter | select(.issue_id==\"$issue_id\" or .to==\"issue:$issue_id\")"
    tail -n "$limit" "$MAIL_FILE" | while IFS= read -r line; do
      echo "$line" | jq -c -e "$filter" 2>/dev/null || true
    done
  else
    tail -n "$limit" "$MAIL_FILE"
  fi
}

cmd_show() {
  [ ! -f "$MAIL_FILE" ] && return 0
  local limit="${1:-5}"
  echo "  Derniers messages (mail):"
  tail -n 100 "$MAIL_FILE" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    if command -v jq >/dev/null 2>&1; then
      from=$(echo "$line" | jq -r '.from // "?"')
      to=$(echo "$line" | jq -r '.to // "?"')
      type=$(echo "$line" | jq -r '.type // "?"')
      ts=$(echo "$line" | jq -r '.ts // "?"')
      body=$(echo "$line" | jq -r '.body // "?"' | head -c 60)
      echo "    [$ts] $from → $to ($type) $body..."
    else
      echo "    $line"
    fi
  done | tail -n "$limit"
  echo ""
}

case "${1:-}" in
  send)  shift; cmd_send "$@" ;;
  list)  shift; cmd_list "$@" ;;
  show)  shift; cmd_show "$@" ;;
  -h|--help)
    echo "Usage: $0 send --from AGENT --to DEST --type TYPE --body \"...\" [--issue-id ID] [--priority 1-5]"
    echo "       $0 list [--to DEST] [--from AGENT] [--type TYPE] [--issue-id ID] [--limit N] [--priority-first]"
    echo "       $0 show [N]   # Derniers N messages (défaut 5), format lisible"
    echo "Types: progress | blocked | help_request | handoff | event"
    echo "Dest: coordinator | agent-X | broadcast | issue:seeds-xxx"
    exit 0 ;;
  *)
    echo "Usage: $0 send|list|show [options]"; exit 1 ;;
esac
