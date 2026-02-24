#!/usr/bin/env bash
# Phase 6 — Lance Aider en mode non interactif (scripting) dans le worktree d'un agent.
# Exécute la tâche décrite dans TASK.md puis s'arrête. À la sortie : fermeture issue Seeds, logs.
# Usage: ./scripts/swarm-run-headless.sh <agent-name> [model]
# Exemple: ./scripts/swarm-run-headless.sh agent-1 gpt-4o
# Référence: https://aider.chat/docs/scripting.html

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_DIR="${REPO_ROOT}/.swarm"

# Afficher l'aide sans exiger aider
[ "$1" = "-h" ] || [ "$1" = "--help" ] && {
  echo "Usage: $0 <agent-name> [model]"
  echo "Exemple: $0 agent-1 gpt-4o"
  exit 0
}

AGENT_NAME="${1:?Usage: $0 <agent-name> [model]}"
MODEL="${2:-gpt-4o}"
AGENT_DIR="${SWARM_DIR}/${AGENT_NAME}"

"${REPO_ROOT}/scripts/swarm-check.sh" --require aider --quiet || exit 1

if [ ! -d "$AGENT_DIR" ]; then
  echo "Erreur: $AGENT_DIR introuvable. Lance d'abord swarm-dispatch.sh ou swarm-setup.sh."
  exit 1
fi

TASK_FILE="${AGENT_DIR}/TASK.md"
if [ ! -f "$TASK_FILE" ]; then
  echo "Erreur: $TASK_FILE introuvable. Pas de tâche pour cet agent."
  exit 1
fi

# Log démarrage (headless)
[ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" agent_start_headless "$AGENT_NAME" "$MODEL"

cd "$AGENT_DIR"

# Contexte Mulch optionnel : préfixer le message avec mulch prime pour que l'agent reçoive l'expertise
MESSAGE_FILE="TASK.md"
TEMP_MSG=""
if [ -d ".mulch" ]; then
  MULCH_CMD=""
  if command -v mulch >/dev/null 2>&1; then
    MULCH_CMD="mulch"
  elif command -v npx >/dev/null 2>&1; then
    MULCH_CMD="npx -y mulch-cli"
  fi
  if [ -n "$MULCH_CMD" ]; then
    TEMP_MSG="${AGENT_DIR}/.message_headless.$$"
    {
      echo "# Contexte expertise (mulch prime)"
      echo ""
      $MULCH_CMD prime 2>/dev/null || true
      echo ""
      echo "---"
      echo ""
      cat TASK.md
    } > "$TEMP_MSG"
    MESSAGE_FILE=".message_headless.$$"
    trap 'rm -f "$AGENT_DIR/.message_headless.$$"' EXIT
  fi
fi

# PID pour le watchdog (optionnel en headless)
echo $$ > .pid 2>/dev/null || true

# Lancer Aider en mode scripting : une instruction (fichier), pas de chat, puis exit
AIDER_EXIT=0
aider --model "$MODEL" --message-file "$MESSAGE_FILE" --yes . || AIDER_EXIT=$?

# Auto-correction : en cas d'échec, réouvrir l'issue pour re-dispatch (avec plafond optionnel)
# En cas de succès : fermer l'issue ; en cas d'échec : réouvrir sauf si MAX_RETRIES atteint
if [ -f ".issue_id" ] && command -v sd >/dev/null 2>&1 && [ -d "${REPO_ROOT}/.seeds" ]; then
  issue_id=$(cat .issue_id)
  if [ "$AIDER_EXIT" -eq 0 ]; then
    reason="Headless terminé (exit 0)"
    (cd "$REPO_ROOT" && sd close "$issue_id" --reason "$reason") 2>/dev/null || true
    # Réinitialiser le compteur de retry en cas de succès
    rm -f .retry_count
  else
    # Échec : incrémenter retry_count et réouvrir si sous le plafond
    retry_file=".retry_count"
    count=0
    [ -f "$retry_file" ] && count=$(cat "$retry_file")
    count=$((count + 1))
    echo "$count" > "$retry_file"
    max_retries="${SWARM_MAX_RETRIES:-0}"
    if [ "$max_retries" -gt 0 ] && [ "$count" -ge "$max_retries" ]; then
      [ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" agent_retry_exhausted "$AGENT_NAME" "$count"
      [ -x "${REPO_ROOT}/scripts/swarm-alert.sh" ] && "${REPO_ROOT}/scripts/swarm-alert.sh" retry_exhausted "agent $AGENT_NAME after $count attempts"
      # Rouvrir quand même pour que l'issue reste visible (open) et ne reste pas bloquée en in_progress
      (cd "$REPO_ROOT" && sd update "$issue_id" --status open) 2>/dev/null && echo "  Issue $issue_id rouverte (retry épuisé, à traiter à la main)." || true
    else
      (cd "$REPO_ROOT" && sd update "$issue_id" --status open) 2>/dev/null && echo "  Issue $issue_id rouverte (retry $count)." || true
      [ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" agent_reopen_on_fail "$AGENT_NAME" "$count"
    fi
  fi
fi

# Log fin
[ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" agent_finish_headless "$AGENT_NAME" "$AIDER_EXIT"

exit "$AIDER_EXIT"
