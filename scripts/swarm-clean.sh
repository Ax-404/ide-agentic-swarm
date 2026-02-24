#!/usr/bin/env bash
# Phase 3 — Supprime les worktrees des agents (option: seulement ceux déjà mergés).
# Usage: ./scripts/swarm-clean.sh [--merged-only] [--force]
#   --merged-only  supprime uniquement les worktrees dont la branche est mergée
#   --force        pas de confirmation
# Sans option: supprime tous les worktrees dans .swarm/

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_DIR="${REPO_ROOT}/.swarm"
MERGED_ONLY=""
FORCE=""
for arg in "$@"; do
  case "$arg" in
    --merged-only) MERGED_ONLY=1 ;;
    --force)       FORCE=1 ;;
  esac
done

cd "$REPO_ROOT"
[ -d "$SWARM_DIR" ] || { echo "Aucun .swarm/."; exit 0; }

to_remove=()
for d in "$SWARM_DIR"/agent-*; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  branch="swarm/$name"
  if [ -n "$MERGED_ONLY" ]; then
    git branch --merged | grep -qw "$branch" && to_remove+=("$d")
  else
    to_remove+=("$d")
  fi
done
[ ${#to_remove[@]} -eq 0 ] && echo "Aucun worktree à supprimer." && exit 0

echo "Worktrees à supprimer:"
printf '  %s\n' "${to_remove[@]}"
if [ -z "$FORCE" ]; then
  echo "Confirmer ? [y/N]"
  read -r r
  [ "$r" = "y" ] || [ "$r" = "Y" ] || exit 0
fi

for d in "${to_remove[@]}"; do
  git worktree remove "$d" --force 2>/dev/null || rm -rf "$d"
  echo "  Supprimé: $d"
done
echo "Fait."