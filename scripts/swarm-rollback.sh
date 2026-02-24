#!/usr/bin/env bash
# Phase 6 — Aide au rollback après un merge swarm : revert du dernier merge (ou d'un commit donné).
# Usage: ./scripts/swarm-rollback.sh [commit]
#   Sans argument : revert du dernier commit de merge (HEAD).
#   Avec commit  : revert du commit spécifié (ex: hash du merge).
# Ne supprime pas l'historique ; crée un commit de revert. Pour annuler le dernier commit sans garder l'historique : git reset --hard HEAD~1 (à utiliser avec précaution).

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

COMMIT="${1:-HEAD}"
if [ "$COMMIT" = "-h" ] || [ "$COMMIT" = "--help" ]; then
  echo "Usage: $0 [commit]"
  echo "  Revert le commit (défaut: HEAD). Crée un nouveau commit qui annule les changements."
  echo "  Pour un merge : git revert -m 1 <merge_commit>"
  exit 0
fi

if git rev-parse --verify "$COMMIT" >/dev/null 2>&1; then
  if git log -1 --pretty=%P "$COMMIT" | grep -q " "; then
    echo "Commit $COMMIT est un merge. Revert avec -m 1 (garder la branche principale)."
    git revert -m 1 --no-edit "$COMMIT"
  else
    git revert --no-edit "$COMMIT"
  fi
  echo "Revert créé. Vérifier puis : git push (si distant)."
else
  echo "Commit $COMMIT introuvable."
  exit 1
fi
