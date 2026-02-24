#!/usr/bin/env bash
# Évolution lot 2 — Coordinateur : crée les issues Seeds à partir d'une liste de tâches puis lance le pipeline.
# Usage: ./scripts/swarm-coordinate.sh "Titre 1" "Titre 2" "Titre 3" [--test "cmd"] [--on-conflict skip|reopen] [--parallel]
#        ./scripts/swarm-coordinate.sh --file tasks.txt [options pipeline...]
# Fichier tasks.txt : une tâche par ligne (titre seul, ou "titre|description" pour usage futur).
# Options passées au pipeline : --test, --validate, --rollback-on-validate-fail, --on-conflict, --parallel (voir swarm-pipeline.sh).
# Prérequis: Seeds (sd), dépôt git, .seeds/ (créé si absent).

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

TITLES=()
FILE=""
PIPELINE_OPTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --file)   FILE="$2"; shift 2 ;;
    --test)   PIPELINE_OPTS+=(--test "$2"); shift 2 ;;
    --validate) PIPELINE_OPTS+=(--validate "$2"); shift 2 ;;
    --rollback-on-validate-fail) PIPELINE_OPTS+=(--rollback-on-validate-fail); shift ;;
    --on-conflict) PIPELINE_OPTS+=(--on-conflict "$2"); shift 2 ;;
    --parallel)    PIPELINE_OPTS+=(--parallel); shift ;;
    -h|--help)
      echo "Usage: $0 [--file FICHIER] \"Titre 1\" \"Titre 2\" ... [--test \"cmd\"] [--validate \"cmd\"] [--rollback-on-validate-fail] [--on-conflict skip|reopen] [--parallel]"
      echo "  Crée les issues Seeds puis lance le pipeline (dispatch → headless → merge)."
      echo "  --file : une tâche par ligne (titre ou titre|description)."
      exit 0 ;;
    *)        TITLES+=("$1"); shift ;;
  esac
done

if [ -n "$FILE" ]; then
  [ -f "$FILE" ] || { echo "Erreur: fichier $FILE introuvable."; exit 1; }
  TITLES=()
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$line" ] && continue
    title="${line%%|*}"
    TITLES+=("$title")
  done < "$FILE"
fi

[ ${#TITLES[@]} -gt 0 ] || { echo "Usage: $0 \"Titre 1\" \"Titre 2\" ... ou $0 --file tasks.txt"; exit 1; }

if ! command -v sd >/dev/null 2>&1; then
  echo "Erreur: 'sd' (Seeds) introuvable. Voir https://github.com/jayminwest/seeds"
  exit 1
fi

echo "=== Coordinateur : création de ${#TITLES[@]} issue(s) puis pipeline ==="
echo ""

# Créer les issues (via script existant pour cohérence)
"${REPO_ROOT}/scripts/swarm-seeds-create.sh" "${TITLES[@]}"
N=${#TITLES[@]}

echo ""
echo "=== Lancement du pipeline ($N agents) ==="
"${REPO_ROOT}/scripts/swarm-pipeline.sh" "$N" "${PIPELINE_OPTS[@]}"
