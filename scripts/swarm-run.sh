#!/usr/bin/env bash
# Phase 2/3 — Lance Aider dans le worktree d'un agent.
# Rôle(s): Scout, Builder, Reviewer, Documenter, Red-team (voir docs/ROLES.md).
# Usage: ./scripts/swarm-run.sh <agent-name> [model] [role]
#   role = scout | builder | reviewer | documenter | red-team (optionnel ; sinon lu depuis .role).
# Exemple: ./scripts/swarm-run.sh agent-1 gpt-4o
#          ./scripts/swarm-run.sh agent-2 claude-sonnet scout
# Ouvrir un terminal par agent pour travailler en parallèle.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_DIR="${REPO_ROOT}/.swarm"
AGENT_NAME="${1:?Usage: $0 <agent-name> [model] [role]}"
MODEL="${2:-gpt-4o}"
ROLE_ARG="${3:-}"
AGENT_DIR="${SWARM_DIR}/${AGENT_NAME}"

if [ ! -d "$AGENT_DIR" ]; then
  echo "Erreur: $AGENT_DIR introuvable. Lance d'abord: ./scripts/swarm-setup.sh [N]"
  exit 1
fi

# Phase 4: log démarrage
[ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" agent_start "$AGENT_NAME" "$MODEL"

# Tout le reste s'exécute depuis le worktree de l'agent
cd "$AGENT_DIR"

# Rôle : 3e arg explicite prioritaire, sinon .role dans le worktree (cohérent avec dispatch/sling et run-headless, voir docs/ROLES.md)
ROLE="builder"
if [ -n "$ROLE_ARG" ]; then
  case "$ROLE_ARG" in
    scout|reviewer|documenter|red-team) ROLE="$ROLE_ARG" ;;
  esac
elif [ -f ".role" ]; then
  r=$(cat .role 2>/dev/null) || true
  case "$r" in
    scout|reviewer|documenter|red-team) ROLE="$r" ;;
  esac
fi

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

# Rôle (Phase 3) — rappel selon le rôle (voir docs/ROLES.md)
case "$ROLE" in
  scout)      echo "--- Rôle: Scout (lecture seule — ne pas modifier les fichiers) ---" ;;
  reviewer)   echo "--- Rôle: Reviewer — revoir le code (qualité, tests, conventions) ; rapport ou corrections ciblées ---" ;;
  documenter) echo "--- Rôle: Documenter — mettre à jour ou créer la doc ; ne pas modifier la logique métier ---" ;;
  red-team)   echo "--- Rôle: Red-team — challenger edge cases, sécurité, scénarios d'échec ; rapport et recommandations ---" ;;
esac
[ "$ROLE" = "scout" ] || [ "$ROLE" = "reviewer" ] || [ "$ROLE" = "documenter" ] || [ "$ROLE" = "red-team" ] && echo ""

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
