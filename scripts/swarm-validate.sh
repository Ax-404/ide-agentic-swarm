#!/usr/bin/env bash
# Phase 6 — Validation post-merge : exécute une commande sur la branche cible ; si échec, optionnellement rollback + alerte.
# Usage: ./scripts/swarm-validate.sh "cmd" [--rollback-on-fail]
#   "cmd" = commande à lancer à la racine du dépôt (ex: make test, pytest)
#   --rollback-on-fail = en cas d'échec, exécute swarm-rollback.sh puis alerte (validate_failed)
# Exemple: ./scripts/swarm-validate.sh "make test" --rollback-on-fail
# À lancer après un merge pour vérifier que la branche cible reste saine.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

CMD=""
ROLLBACK_ON_FAIL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rollback-on-fail)  ROLLBACK_ON_FAIL=1; shift ;;
    -h|--help)
      echo "Usage: $0 \"<commande>\" [--rollback-on-fail]"
      echo "  Exécute la commande à la racine du dépôt. Si elle échoue et --rollback-on-fail est passé,"
      echo "  exécute swarm-rollback.sh puis envoie une alerte validate_failed."
      exit 0
      ;;
    *)  CMD="$1"; shift; break ;;
  esac
done
while [ $# -gt 0 ]; do
  case "$1" in
    --rollback-on-fail) ROLLBACK_ON_FAIL=1; shift ;;
    *) break ;;
  esac
done
[ -n "$CMD" ] || { echo "Usage: $0 \"<commande>\" [--rollback-on-fail]"; exit 1; }

VALIDATE_EXIT=0
eval "$CMD" || VALIDATE_EXIT=$?

if [ "$VALIDATE_EXIT" -ne 0 ]; then
  [ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" validate_failed "$CMD" "$VALIDATE_EXIT"
  if [ -n "$ROLLBACK_ON_FAIL" ]; then
    echo "Validation échouée : rollback du dernier merge..."
    [ -x "${REPO_ROOT}/scripts/swarm-rollback.sh" ] && "${REPO_ROOT}/scripts/swarm-rollback.sh" || true
    [ -x "${REPO_ROOT}/scripts/swarm-alert.sh" ] && "${REPO_ROOT}/scripts/swarm-alert.sh" validate_failed "cmd=$CMD exit=$VALIDATE_EXIT (rollback effectué)"
  else
    [ -x "${REPO_ROOT}/scripts/swarm-alert.sh" ] && "${REPO_ROOT}/scripts/swarm-alert.sh" validate_failed "cmd=$CMD exit=$VALIDATE_EXIT"
  fi
  exit "$VALIDATE_EXIT"
fi

[ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" validate_ok "$CMD"
exit 0
