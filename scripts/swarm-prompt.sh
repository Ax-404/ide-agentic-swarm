#!/usr/bin/env bash
# Entrée en langage naturel : décompose une demande via un LLM en sous-tâches puis lance le coordinateur.
# Usage: ./scripts/swarm-prompt.sh "Ajoute l'authentification et un middleware de logs" [--model gpt-4o] [--test "make test"] ...
#        echo "Refactoriser le module API" | ./scripts/swarm-prompt.sh --stdin [options...]
# Prérequis: OPENAI_API_BASE (proxy LiteLLM), curl, jq. Optionnel: OPENAI_API_KEY si le proxy l'exige.
# Les options --test, --validate, --rollback-on-validate-fail, --on-conflict, --parallel sont transmises au coordinateur.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_BASE="${OPENAI_API_BASE:-}"
API_KEY="${OPENAI_API_KEY:-}"
MODEL="${SWARM_PROMPT_MODEL:-gpt-4o}"
PROMPT_TEXT=""
PIPELINE_OPTS=()
USE_STDIN=""

# Afficher l'aide sans exiger les prérequis (jq, etc.)
for a in "$@"; do
  [ "$a" = "-h" ] || [ "$a" = "--help" ] && {
    echo "Usage: $0 \"<demande en langage naturel>\" [--model MODEL] [--test \"cmd\"] [--validate \"cmd\"] [--rollback-on-validate-fail] [--on-conflict skip|reopen] [--parallel]"
    echo "       echo \"<demande>\" | $0 --stdin [options...]"
    echo "  Décompose la demande en sous-tâches via le LLM (OPENAI_API_BASE) puis lance le coordinateur."
    echo "  Options pipeline: --test, --validate, --rollback-on-validate-fail, --on-conflict, --parallel."
    exit 0
  }
done

"${REPO_ROOT}/scripts/swarm-check.sh" --require jq --quiet || exit 1

while [ $# -gt 0 ]; do
  case "$1" in
    --stdin)   USE_STDIN=1; shift ;;
    --model)   MODEL="$2"; shift 2 ;;
    --test)    PIPELINE_OPTS+=(--test "$2"); shift 2 ;;
    --validate) PIPELINE_OPTS+=(--validate "$2"); shift 2 ;;
    --rollback-on-validate-fail) PIPELINE_OPTS+=(--rollback-on-validate-fail); shift ;;
    --on-conflict) PIPELINE_OPTS+=(--on-conflict "$2"); shift 2 ;;
    --parallel)    PIPELINE_OPTS+=(--parallel); shift ;;
    -h|--help)
      echo "Usage: $0 \"<demande en langage naturel>\" [--model MODEL] [--test \"cmd\"] [--validate \"cmd\"] [--rollback-on-validate-fail] [--on-conflict skip|reopen] [--parallel]"
      echo "       echo \"<demande>\" | $0 --stdin [options...]"
      echo "  Décompose la demande en sous-tâches via le LLM (OPENAI_API_BASE) puis lance le coordinateur."
      echo "  Options pipeline: --test, --validate, --rollback-on-validate-fail, --on-conflict, --parallel."
      exit 0 ;;
    *)         PROMPT_TEXT="$1"; shift ;;
  esac
done

if [ -n "$USE_STDIN" ]; then
  PROMPT_TEXT=$(cat)
fi

[ -n "$PROMPT_TEXT" ] || { echo "Donnez une demande (argument ou stdin avec --stdin)."; exit 1; }
[ -n "$API_BASE" ] || { echo "Erreur: OPENAI_API_BASE non défini (ex. export OPENAI_API_BASE=http://proxy:4000)"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Erreur: curl requis (appel API)."; exit 1; }

# Appel API chat completions (OpenAI-compatible / LiteLLM)
USER_PROMPT="The user wants to accomplish the following in a software project. Decompose this into a short list of concrete subtasks that can be done by coding agents. Return ONLY the list of subtask titles, one per line. No numbering, no explanation, no markdown. Each line will be used as a Seeds issue title. Keep titles concise (a few words each).

User request:
$PROMPT_TEXT"

PAYLOAD=$(jq -n \
  --arg model "$MODEL" \
  --arg content "$USER_PROMPT" \
  '{model: $model, messages: [{role: "user", content: $content}], max_tokens: 500}')

RESPONSE=$(curl -sS -X POST "${API_BASE%/}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  ${API_KEY:+ -H "Authorization: Bearer $API_KEY"} \
  -d "$PAYLOAD") || { echo "Erreur: appel API échoué (vérifiez OPENAI_API_BASE et réseau)."; exit 1; }

# Extraire le contenu (sous-tâches, une par ligne)
CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')
if [ -z "$CONTENT" ]; then
  echo "Erreur: pas de réponse du LLM (vérifiez OPENAI_API_BASE, modèle, et éventuellement OPENAI_API_KEY)."
  echo "Réponse brute: $RESPONSE" | head -c 500
  exit 1
fi

# Parser : une ligne = un titre, retirer numéros/début de ligne
TITLES=()
while IFS= read -r line; do
  line=$(echo "$line" | sed 's/^[[:space:]]*[0-9]*[.)\-]*[[:space:]]*//;s/^[[:space:]]*[-*][[:space:]]*//;s/[[:space:]]*$//')
  [ -z "$line" ] && continue
  # Supprimer d'éventuels préfixes markdown
  line=$(echo "$line" | sed 's/^#*[[:space:]]*//')
  TITLES+=("$line")
done <<< "$CONTENT"

[ ${#TITLES[@]} -gt 0 ] || { echo "Erreur: le LLM n'a pas renvoyé de sous-tâches exploitables."; echo "$CONTENT"; exit 1; }

echo "=== Sous-tâches proposées par le LLM (${#TITLES[@]}) ==="
for t in "${TITLES[@]}"; do echo "  - $t"; done
echo ""
echo "=== Lancement du coordinateur ==="
"${REPO_ROOT}/scripts/swarm-coordinate.sh" "${TITLES[@]}" "${PIPELINE_OPTS[@]}"
