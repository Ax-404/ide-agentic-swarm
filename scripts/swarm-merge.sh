#!/usr/bin/env bash
# Phase 2/3 — Merge des branches des agents dans la branche courante (ex: main).
# Usage: ./scripts/swarm-merge.sh [agent-1 agent-2 ...]
#         ./scripts/swarm-merge.sh --completed   (Phase 3: ne merger que les branches dont l'issue Seeds est closed)
#         ./scripts/swarm-merge.sh --completed --test "make test"   (Phase 6: ne merger que si la commande réussit dans le worktree)
#         ./scripts/swarm-merge.sh --completed --on-conflict skip  (en cas de conflit: annuler le merge, continuer les autres)
#         ./scripts/swarm-merge.sh --completed --on-conflict reopen (idem + rouvrir l'issue Seeds pour re-dispatch)
#         ./scripts/swarm-merge.sh --all         (forcer toutes les branches .swarm/)
# Sans arguments: merge toutes les branches swarm/* présentes dans .swarm/
# À lancer depuis la racine du dépôt, sur la branche cible (ex: main).

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_DIR="${REPO_ROOT}/.swarm"
cd "$REPO_ROOT"

ONLY_COMPLETED=""
FORCE_ALL=""
TEST_CMD=""
ON_CONFLICT="abort"   # abort | skip | reopen
AGENTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --completed)    ONLY_COMPLETED=1; shift ;;
    --all)          FORCE_ALL=1; shift ;;
    --test)         TEST_CMD="${2:?--test exige une commande}"; shift 2 ;;
    --on-conflict)  ON_CONFLICT="${2:?--on-conflict exige: abort|skip|reopen}"; shift 2 ;;
    *)              AGENTS+=("$1"); shift ;;
  esac
done

if [ ${#AGENTS[@]} -eq 0 ]; then
  [ -d "$SWARM_DIR" ] || { echo "Aucun .swarm/ trouvé."; exit 1; }
  for d in "$SWARM_DIR"/agent-*; do
    [ -d "$d" ] || continue
    AGENTS+=("$(basename "$d")")
  done
fi

# Phase 3: filtrer par issue closed si --completed (lit .seeds/issues.jsonl)
if [ -n "$ONLY_COMPLETED" ] && [ -z "$FORCE_ALL" ]; then
  COMPLETED=()
  for name in "${AGENTS[@]}"; do
    issue_file="${SWARM_DIR}/${name}/.issue_id"
    if [ -f "$issue_file" ]; then
      issue_id=$(cat "$issue_file")
      closed=0
      if [ -f ".seeds/issues.jsonl" ]; then
        while IFS= read -r line; do
          if echo "$line" | grep -q "\"id\":\"$issue_id\""; then
            echo "$line" | grep -q '"status":"closed"' && closed=1
            break
          fi
        done < .seeds/issues.jsonl
      fi
      [ "$closed" = 1 ] && COMPLETED+=("$name")
    else
      COMPLETED+=("$name")
    fi
  done
  AGENTS=("${COMPLETED[@]}")
fi

[ ${#AGENTS[@]} -gt 0 ] || { echo "Aucun agent à merger (ou aucune issue fermée avec --completed)."; exit 0; }

echo "Branche actuelle: $(git branch --show-current)"
echo "Agents à merger: ${AGENTS[*]}"
echo ""

for name in "${AGENTS[@]}"; do
  branch="swarm/$name"
  agent_dir="${SWARM_DIR}/${name}"
  if ! git rev-parse --verify "$branch" >/dev/null 2>&1; then
    echo "Branche $branch introuvable, ignorée."
    continue
  fi
  # Phase 6 : gate tests — exécuter la commande dans le worktree avant de merger
  if [ -n "$TEST_CMD" ] && [ -d "$agent_dir" ]; then
    echo "Tests dans $name : $TEST_CMD"
    if ! ( cd "$agent_dir" && eval "$TEST_CMD" ); then
      echo "  Ignoré (tests en échec): $branch"
      [ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" merge_skipped "$name" "tests_failed"
      [ -x "${REPO_ROOT}/scripts/swarm-alert.sh" ] && "${REPO_ROOT}/scripts/swarm-alert.sh" tests_failed "agent $name (branch $branch)"
      # Auto-correction : rouvrir l'issue pour re-dispatch au prochain pipeline
      if [ -f "${agent_dir}/.issue_id" ] && command -v sd >/dev/null 2>&1 && [ -d "${REPO_ROOT}/.seeds" ]; then
        issue_id=$(cat "${agent_dir}/.issue_id")
        (cd "$REPO_ROOT" && sd update "$issue_id" --status open) 2>/dev/null && echo "  Issue $issue_id rouverte (re-dispatch possible)." || true
      fi
      continue
    fi
  fi
  echo "Merge de $branch..."
  if git merge "$branch" -m "Merge $branch (swarm)"; then
    echo "  OK: $branch"
    [ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" merge "$name"
  else
    # Conflit : selon --on-conflict
    git merge --abort 2>/dev/null || true
    [ -x "${REPO_ROOT}/scripts/swarm-log.sh" ] && "${REPO_ROOT}/scripts/swarm-log.sh" merge_conflict "$name"
    [ -x "${REPO_ROOT}/scripts/swarm-alert.sh" ] && "${REPO_ROOT}/scripts/swarm-alert.sh" merge_conflict "agent $name"
    if [ "$ON_CONFLICT" = "abort" ]; then
      echo "  CONFLITS: résous les conflits puis: git add . && git commit (ou relance avec --on-conflict skip|reopen)"
      exit 1
    fi
    echo "  Ignoré (conflit, --on-conflict=$ON_CONFLICT): $branch"
    if [ "$ON_CONFLICT" = "reopen" ] && [ -f "${agent_dir}/.issue_id" ] && command -v sd >/dev/null 2>&1 && [ -d "${REPO_ROOT}/.seeds" ]; then
      issue_id=$(cat "${agent_dir}/.issue_id")
      (cd "$REPO_ROOT" && sd update "$issue_id" --status open) 2>/dev/null && echo "  Issue $issue_id rouverte (re-dispatch possible)." || true
    fi
    # skip ou reopen : on continue avec les autres branches
  fi
done

echo ""
echo "Merge terminé. Nettoyer les worktrees: ./scripts/swarm-clean.sh"
