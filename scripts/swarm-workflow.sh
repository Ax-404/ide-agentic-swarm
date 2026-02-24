#!/usr/bin/env bash
# Moteur de workflow : exécute une suite d'étapes définies dans un fichier.
# Usage: ./scripts/swarm-workflow.sh [fichier_workflow|nom_court]
#         ./scripts/swarm-workflow.sh --list   # liste les workflows (découverte auto)
#   Sans argument : utilise workflows/default.workflow (ou workflows/autonomous.workflow).
#   Nom court : ex. "staging" → workflows/staging.workflow (tout .workflow ajouté est utilisable).
# Format du fichier : une étape = une ligne avec le nom du script (sans swarm- ni .sh),
#   puis une ligne d'argument par ligne, jusqu'à une ligne contenant exactement "--".
#   Lignes # et vides ignorées. Scripts disponibles : dispatch, pipeline, coordinate,
#   merge, deploy-staging, seeds-create, clean, rollback, budget, etc. (tous swarm-*.sh).
# Exemple de fichier :
#   coordinate
#   Tâche 1
#   Tâche 2
#   --test
#   make test
#   --
#   pipeline
#   2
#   --test
#   make test
#   --

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOWS_DIR="${REPO_ROOT}/workflows"
SCRIPT_DIR="${REPO_ROOT}/scripts"

# --list / -l : lister les workflows (découverte automatique de workflows/*.workflow)
if [ "${1:-}" = "--list" ] || [ "${1:-}" = "-l" ]; then
  echo "Workflows disponibles (workflows/*.workflow) :"
  echo ""
  if [ ! -d "$WORKFLOWS_DIR" ]; then
    echo "  (aucun dossier workflows/)"
    exit 0
  fi
  for f in "$WORKFLOWS_DIR"/*.workflow; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .workflow)"
    desc=""
    while IFS= read -r line; do
      line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [[ "$line" == \#* ]]; then
        desc=$(echo "$line" | sed 's/^#[[:space:]]*//')
        break
      fi
    done < "$f"
    [ -n "$desc" ] && echo "  $name — $desc" || echo "  $name"
  done
  echo ""
  echo "Lancer : $0 <nom>  ou  $0 workflows/<nom>.workflow"
  exit 0
fi

# Fichier workflow : argument explicite ou nom court (ex. staging → workflows/staging.workflow)
WORKFLOW_FILE="${1:-}"
if [ -z "$WORKFLOW_FILE" ]; then
  for f in "${WORKFLOWS_DIR}/default.workflow" "${WORKFLOWS_DIR}/autonomous.workflow"; do
    if [ -f "$f" ]; then
      WORKFLOW_FILE="$f"
      break
    fi
  done
fi

# Nom court (sans chemin ni .workflow) → workflows/<nom>.workflow
if [ -n "$WORKFLOW_FILE" ] && [ ! -f "$WORKFLOW_FILE" ] && [[ "$WORKFLOW_FILE" != */* ]]; then
  short="${WORKFLOW_FILE%.workflow}"
  if [ -f "${WORKFLOWS_DIR}/${short}.workflow" ]; then
    WORKFLOW_FILE="${WORKFLOWS_DIR}/${short}.workflow"
  fi
fi

if [ -z "$WORKFLOW_FILE" ] || [ ! -f "$WORKFLOW_FILE" ]; then
  echo "Usage: $0 [fichier_workflow|nom]   ou   $0 --list"
  echo "  --list       liste les workflows (tout .workflow dans workflows/ est pris en compte)"
  echo "  nom          ex. staging → workflows/staging.workflow"
  echo "  Fichier manquant ? Créez workflows/default.workflow ou lancez $0 --list"
  echo "  Voir docs/workflows/phase6-workflow.md (moteur de workflow)."
  exit 1
fi

WORKFLOW_FILE="$(cd "$(dirname "$WORKFLOW_FILE")" && pwd)/$(basename "$WORKFLOW_FILE")"
echo "=== Workflow: $WORKFLOW_FILE ==="
echo ""

run_step() {
  local script_name="$1"
  shift
  local args=("$@")
  local script_path="${SCRIPT_DIR}/swarm-${script_name}.sh"
  if [ ! -x "$script_path" ]; then
    echo "Erreur: script $script_path introuvable ou non exécutable."
    exit 1
  fi
  echo "--- Étape: swarm-${script_name}.sh ${args[*]} ---"
  "$script_path" "${args[@]}"
  echo ""
}

# Parse : script name puis args ligne par ligne jusqu'à --
current_script=""
current_args=()
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%%#*}"
  line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -z "$line" ]; then
    continue
  fi
  if [ "$line" = "--" ]; then
    if [ -n "$current_script" ]; then
      run_step "$current_script" "${current_args[@]}"
      current_script=""
      current_args=()
    fi
    continue
  fi
  if [ -z "$current_script" ]; then
    current_script="$line"
  else
    current_args+=("$line")
  fi
done < "$WORKFLOW_FILE"

if [ -n "$current_script" ]; then
  run_step "$current_script" "${current_args[@]}"
fi

echo "=== Workflow terminé ==="
