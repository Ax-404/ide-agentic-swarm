#!/usr/bin/env bash
# Lot 3 — Lancer le pipeline sur la branche staging (puis merger vers main quand prêt).
# Usage: ./scripts/swarm-deploy-staging.sh [args pour swarm-pipeline...]
#   Ex: ./scripts/swarm-deploy-staging.sh 2 --test "make test" --on-conflict skip
# Env: SWARM_STAGING_BRANCH=staging (défaut), SWARM_MAIN_BRANCH=main
# Comportement: checkout staging, lance swarm-pipeline.sh avec les args, puis affiche la marche à suivre pour merger vers main.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGING="${SWARM_STAGING_BRANCH:-staging}"
MAIN="${SWARM_MAIN_BRANCH:-main}"
CURRENT=$(cd "$REPO_ROOT" && git branch --show-current 2>/dev/null || true)

cd "$REPO_ROOT"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Erreur: pas un dépôt git."
  exit 1
fi

# Créer staging si elle n'existe pas
if ! git rev-parse --verify "$STAGING" >/dev/null 2>&1; then
  echo "Création de la branche $STAGING..."
  git checkout -b "$STAGING" 2>/dev/null || git checkout "$STAGING"
fi

echo "=== Déploiement staging : branche $STAGING ==="
git checkout "$STAGING"
"${REPO_ROOT}/scripts/swarm-pipeline.sh" "$@"
echo ""
echo "--- Staging à jour. Pour promouvoir vers $MAIN : ---"
echo "  git checkout $MAIN && git merge $STAGING -m 'Merge staging (swarm)'"
echo "  # Puis tester/déployer et éventuellement : git push"
echo "  # Pour revenir sur ta branche : git checkout $CURRENT"
