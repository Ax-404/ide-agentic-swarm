#!/usr/bin/env bash
# Tests smoke : vérifications minimales pour valider les scripts swarm sans environnement complet (sd, aider).
# Usage: ./tests/smoke.sh   (depuis la racine du projet)
# À lancer après modifications des scripts pour vérifier que check, mail et common fonctionnent.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
FAIL=0

run() {
  if "$@"; then
    echo "  OK: $*"
  else
    echo "  FAIL: $*"
    FAIL=1
  fi
}

echo "=== Smoke tests ==="
echo ""

echo "1. swarm-check.sh (récap, sans --require)"
run bash -c './scripts/swarm-check.sh >/dev/null'

echo "2. swarm-check.sh --require jq --quiet"
run ./scripts/swarm-check.sh --require jq --quiet

echo "3. swarm-common.sh : fonction swarm_task_md_content"
source "./scripts/swarm-common.sh"
content=$(swarm_task_md_content "seeds-test" "Titre test" "Description.")
if echo "$content" | grep -q "Tâche: Titre test" && echo "$content" | grep -q "En cas de blocage"; then
  echo "  OK: swarm_task_md_content produit en-tête + bloc blocage"
else
  echo "  FAIL: swarm_task_md_content"
  FAIL=1
fi

echo "4. swarm-mail.sh send + list (jq requis)"
if ! command -v jq >/dev/null 2>&1; then
  echo "  SKIP: jq absent"
else
  mkdir -p .swarm/mail
  id=$(./scripts/swarm-mail.sh send --from agent-1 --to coordinator --type event --body "Smoke test" 2>/dev/null || true)
  if [ -n "$id" ]; then
    run bash -c './scripts/swarm-mail.sh list --limit 1 >/dev/null'
    run bash -c './scripts/swarm-mail.sh show 1 >/dev/null'
  else
    echo "  SKIP: send a échoué (env mail)"
  fi
fi

echo "5. --help sans prérequis (dispatch, coordinate, handoff)"
run bash -c './scripts/swarm-dispatch.sh --help >/dev/null'
run bash -c './scripts/swarm-coordinate.sh --help >/dev/null'
run bash -c './scripts/swarm-handoff.sh --help >/dev/null'

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "Tous les tests smoke passent."
  exit 0
else
  echo "Certains tests ont échoué."
  exit 1
fi
