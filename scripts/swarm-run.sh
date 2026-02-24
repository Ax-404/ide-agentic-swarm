#!/usr/bin/env bash
# Phase 2/3 — Lance Aider dans le worktree d'un agent.
# Usage: ./scripts/swarm-run.sh <agent-name> [model] [role]
#   role = scout | builder (optionnel; scout = lecture seule, rappel dans le contexte).
# Exemple: ./scripts/swarm-run.sh agent-1 gpt-4o
#          ./scripts/swarm-run.sh agent-2 claude-sonnet builder
# Ouvrir un terminal par agent pour travailler en parallèle.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_DIR="${REPO_ROOT}/.swarm"
AGENT_NAME="${1:?Usage: $0 <agent-name> [model] [role]}"
MODEL="${2:-gpt-4o}"
ROLE="${3:-builder}"
AGENT_DIR="${SWARM_DIR}/${AGENT_NAME}"

if [ ! -d "$AGENT_DIR" ]; then
  echo "Erreur: $AGENT_DIR introuvable. Lance d'abord: ./scripts/swarm-setup.sh [N]"
  exit 1
fi

# Phase 4: log démarrage
[ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" agent_start "$AGENT_NAME" "$MODEL"

# Tout le reste s'exécute depuis le worktree de l'agent
cd "$AGENT_DIR"

# Contexte expertise Mulch (si présent) — https://github.com/jayminwest/mulch
if [ -d ".mulch" ]; then
  MULCH_CMD=""
  if command -v mulch >/dev/null 2>&1; then
    MULCH_CMD="mulch"
  elif command -v npx >/dev/null 2>&1; then
    MULCH_CMD="npx -y mulch-cli"
  fi
  if [ -n "$MULCH_CMD" ]; then
    echo "--- Contexte expertise (mulch prime) — à donner à Aider si utile ---"
    $MULCH_CMD prime 2>/dev/null || true
    echo "--- Fin mulch prime ---"
    echo ""
  fi
fi

# Rôle (Phase 3) — scout = lecture seule
if [ "$ROLE" = "scout" ]; then
  echo "--- Rôle: Scout (lecture seule — ne pas modifier les fichiers) ---"
  echo ""
fi

TASK_FILE="TASK.md"
if [ -f "$TASK_FILE" ]; then
  echo "--- Tâche pour cet agent (TASK.md) ---"
  cat "$TASK_FILE"
  echo "--- Fin TASK.md — donne cette tâche à Aider ---"
  echo ""
fi

echo "Lancement Aider dans $AGENT_DIR (modèle: $MODEL, rôle: $ROLE)"
echo "OPENAI_API_BASE est utilisé si défini dans ton env."
echo ""
# Phase 4: enregistrer le PID pour le watchdog (après exec ce sera le PID d'aider)
echo $$ > .pid
exec aider --model "$MODEL" .
