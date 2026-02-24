#!/usr/bin/env bash
# Phase 6 — Pipeline autonome : dispatch → agents headless → merge (avec gate tests optionnel) → validation post-merge.
# Usage: ./scripts/swarm-pipeline.sh [N] [--test "cmd"] [--validate "cmd"] [--rollback-on-validate-fail] [--parallel] [--on-conflict skip|reopen]
#   N = nombre d'issues à dispatcher (défaut: 2)
#   --test "cmd" = ne merger que les branches où "cmd" réussit dans le worktree (ex: make test, pytest)
#   --validate "cmd" = après merge, exécuter "cmd" sur la branche cible ; si échec et --rollback-on-validate-fail : rollback + alerte
#   --rollback-on-validate-fail = avec --validate : en cas d'échec de la validation, revert du dernier merge puis alerte
#   --parallel = lancer les agents headless en parallèle (défaut: séquentiel)
#   --on-conflict skip|reopen = en cas de conflit au merge : skip (ignorer la branche) ou reopen (ignorer + rouvrir l'issue Seeds)
# Exemple: ./scripts/swarm-pipeline.sh 2
#          ./scripts/swarm-pipeline.sh 2 --test "make test" --validate "make test" --rollback-on-validate-fail --on-conflict skip
# Prérequis: Seeds (sd), dépôt git, .seeds/ avec des issues open.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Lot 3 : alerte en cas d'échec du pipeline (trap sur EXIT)
_alert_on_fail() {
  local code=$?
  [ $code -eq 0 ] && return 0
  [ -x "${REPO_ROOT}/scripts/swarm-alert.sh" ] && "${REPO_ROOT}/scripts/swarm-alert.sh" pipeline_failed "exit code $code"
}
trap _alert_on_fail EXIT
SWARM_DIR="${REPO_ROOT}/.swarm"
N=2
TEST_CMD=""
VALIDATE_CMD=""
ROLLBACK_ON_VALIDATE_FAIL=""
PARALLEL=""
ON_CONFLICT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --test)                      TEST_CMD="${2:?--test exige une commande}"; shift 2 ;;
    --validate)                  VALIDATE_CMD="${2:?--validate exige une commande}"; shift 2 ;;
    --rollback-on-validate-fail) ROLLBACK_ON_VALIDATE_FAIL=1; shift ;;
    --parallel)                  PARALLEL=1; shift ;;
    --on-conflict)               ON_CONFLICT="${2:?--on-conflict exige: skip|reopen}"; shift 2 ;;
    [0-9]*)                      N="$1"; shift ;;
    *)                            echo "Usage: $0 [N] [--test \"cmd\"] [--validate \"cmd\"] [--rollback-on-validate-fail] [--parallel] [--on-conflict skip|reopen]"; exit 1 ;;
  esac
done

cd "$REPO_ROOT"

# 1 — Dispatch : créer worktrees et assigner N issues
echo "=== Dispatch ($N agents) ==="
"${REPO_ROOT}/scripts/swarm-dispatch.sh" "$N" || true
# Si aucune issue ouverte, dispatch peut ne rien faire ; on continue pour lancer headless sur les worktrees existants

# 2 — Lancer les agents headless (worktrees avec .issue_id et TASK.md dont l'issue est encore in_progress)
echo ""
echo "=== Agents headless ==="
MODEL="${SWARM_MODEL:-gpt-4o}"

# Garde-fou : ne lancer headless que si l'issue Seeds est encore in_progress (évite double exécution si on n'a pas nettoyé)
issue_still_in_progress() {
  local dir="$1"
  local repo_root="$2"
  [ -f "$dir/.issue_id" ] || return 1
  [ -f "$repo_root/.seeds/issues.jsonl" ] || return 0
  local issue_id
  issue_id=$(cat "$dir/.issue_id")
  if grep -q "\"id\":\"$issue_id\"" "$repo_root/.seeds/issues.jsonl" 2>/dev/null; then
    grep "\"id\":\"$issue_id\"" "$repo_root/.seeds/issues.jsonl" | grep -q '"status":"closed"' && return 1
  fi
  return 0
}

run_agents() {
  for d in "$SWARM_DIR"/agent-*; do
    [ -d "$d" ] || continue
    [ -f "$d/.issue_id" ] && [ -f "$d/TASK.md" ] || continue
    if ! issue_still_in_progress "$d" "$REPO_ROOT"; then
      echo "  Ignoré (issue déjà fermée): $(basename "$d")"
      continue
    fi
    name="$(basename "$d")"
    echo "Lancement headless: $name"
    if [ -n "$PARALLEL" ]; then
      "${REPO_ROOT}/scripts/swarm-run-headless.sh" "$name" "$MODEL" &
    else
      "${REPO_ROOT}/scripts/swarm-run-headless.sh" "$name" "$MODEL"
    fi
  done
  [ -n "$PARALLEL" ] && wait
}
run_agents

# 3 — Merge des branches dont l'issue est closed (avec gate tests si --test, gestion conflits si --on-conflict)
echo ""
echo "=== Merge (--completed${TEST_CMD:+ --test \"$TEST_CMD\"}${ON_CONFLICT:+ --on-conflict $ON_CONFLICT}) ==="
MERGE_ARGS=(--completed)
[ -n "$TEST_CMD" ] && MERGE_ARGS+=(--test "$TEST_CMD")
[ -n "$ON_CONFLICT" ] && MERGE_ARGS+=(--on-conflict "$ON_CONFLICT")
"${REPO_ROOT}/scripts/swarm-merge.sh" "${MERGE_ARGS[@]}"

# 4 — Validation post-merge (optionnel) : tests sur la branche cible ; si échec, rollback + alerte
if [ -n "$VALIDATE_CMD" ]; then
  echo ""
  echo "=== Validation post-merge ==="
  VAL_ARGS=("$VALIDATE_CMD")
  [ -n "$ROLLBACK_ON_VALIDATE_FAIL" ] && VAL_ARGS+=(--rollback-on-fail)
  if ! "${REPO_ROOT}/scripts/swarm-validate.sh" "${VAL_ARGS[@]}"; then
    echo "Validation échouée.${ROLLBACK_ON_VALIDATE_FAIL:+ Rollback effectué.}"
    exit 1
  fi
fi

echo ""
echo "Pipeline terminé. Nettoyer : ./scripts/swarm-clean.sh [--merged-only] [--force]"
