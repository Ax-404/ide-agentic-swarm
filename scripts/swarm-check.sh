#!/usr/bin/env bash
# Vérification des prérequis swarm : git, jq, sd (Seeds), pi (coding agent), mulch (optionnel).
# Usage: ./scripts/swarm-check.sh [--require seeds] [--require sd] [--require jq] [--require pi] [--quiet]
#   --require seeds  exige sd et .seeds/ (pour dispatch, pipeline, coordinate, sling)
#   --require sd     exige uniquement le binaire sd (pour seeds-create avant sd init)
#   --require jq     exige jq (pour mail, prompt, merge/dashboard qui lisent JSONL)
#   --require pi     exige pi (coding agent) en PATH (pour run, run-headless)
#   --quiet          pas d'affichage, seulement code de sortie
# Sans option : vérifie uniquement git (dépôt valide). Exit 0 si tout OK, 1 si un prérequis --require manque.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REQUIRE_SEEDS=""
REQUIRE_SD=""
REQUIRE_JQ=""
REQUIRE_PI=""
QUIET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --require)
      case "$2" in
        seeds)  REQUIRE_SEEDS=1 ;;
        sd)     REQUIRE_SD=1 ;;
        jq)     REQUIRE_JQ=1 ;;
        pi)      REQUIRE_PI=1 ;;
        *)       echo "Erreur: --require exige seeds|sd|jq|pi"; exit 1 ;;
      esac
      shift 2
      ;;
    --quiet) QUIET=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--require seeds|sd|jq|pi] [--quiet]"
      echo "  Vérifie les prérequis. Avec --require, sort en erreur si manquant."
      echo "  pi = coding agent (npm install -g @mariozechner/pi-coding-agent)"
      exit 0
      ;;
    *) shift ;;
  esac
done

FAIL=0
msg() { [ -z "$QUIET" ] && echo "$@"; }
err() { echo "$@" >&2; }

# Avec un seul --require, n'afficher que les erreurs (pas le récap informatif)
REQUIRE_ANY=""
[ -n "$REQUIRE_SEEDS" ] || [ -n "$REQUIRE_SD" ] || [ -n "$REQUIRE_JQ" ] || [ -n "$REQUIRE_PI" ] && REQUIRE_ANY=1

# Toujours : dépôt git
if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  err "Erreur: pas un dépôt git (ou pas lancé depuis la racine du projet)."
  exit 1
fi

# Optionnel / informatif (seulement si aucun --require)
if [ -z "$QUIET" ] && [ -z "$REQUIRE_ANY" ]; then
  command -v jq >/dev/null 2>&1 && msg "  jq       : OK" || msg "  jq       : absent (recommandé pour mail, prompt, Seeds)"
fi
if [ -n "$REQUIRE_JQ" ]; then
  if ! command -v jq >/dev/null 2>&1; then
    err "Erreur: jq introuvable. Install: brew install jq (ou équivalent)."
    FAIL=1
  fi
fi

# Seeds (sd + .seeds/) — informatif seulement si aucun --require
if [ -z "$QUIET" ] && [ -z "$REQUIRE_ANY" ]; then
  if command -v sd >/dev/null 2>&1; then
    [ -d "$REPO_ROOT/.seeds" ] && msg "  sd/.seeds: OK" || msg "  sd/.seeds: sd OK, .seeds/ absent (lance 'sd init')"
  else
    msg "  sd/.seeds: absent (optionnel sauf pour dispatch/pipeline/Seeds)"
  fi
fi
if [ -n "$REQUIRE_SEEDS" ]; then
  if ! command -v sd >/dev/null 2>&1; then
    err "Erreur: 'sd' (Seeds) introuvable. Voir https://github.com/jayminwest/seeds"
    FAIL=1
  elif [ ! -d "$REPO_ROOT/.seeds" ]; then
    err "Erreur: .seeds/ introuvable. À la racine du projet: sd init"
    FAIL=1
  fi
fi
if [ -n "$REQUIRE_SD" ]; then
  if ! command -v sd >/dev/null 2>&1; then
    err "Erreur: 'sd' (Seeds) introuvable. Voir https://github.com/jayminwest/seeds"
    FAIL=1
  fi
fi

# Pi (coding agent) — informatif seulement si aucun --require
if [ -z "$QUIET" ] && [ -z "$REQUIRE_ANY" ]; then
  command -v pi >/dev/null 2>&1 && msg "  pi       : OK" || msg "  pi       : absent (requis pour swarm-run, swarm-run-headless)"
fi
if [ -n "$REQUIRE_PI" ]; then
  if ! command -v pi >/dev/null 2>&1; then
    err "Erreur: pi introuvable. Install: npm install -g @mariozechner/pi-coding-agent"
    FAIL=1
  fi
fi

# Mulch (toujours optionnel, informatif seulement si aucun --require)
if [ -z "$QUIET" ] && [ -z "$REQUIRE_ANY" ]; then
  if command -v mulch >/dev/null 2>&1 || command -v npx >/dev/null 2>&1; then
    msg "  mulch    : disponible (optionnel)"
  else
    msg "  mulch    : absent (optionnel)"
  fi
fi

[ $FAIL -eq 1 ] && exit 1
exit 0
