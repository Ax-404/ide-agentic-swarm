#!/usr/bin/env bash
# Premier run : un seul point d'entrée pour valider le système (check → sd init si besoin → issues de test → pipeline).
# Usage: ./scripts/swarm-quickstart.sh [--yes]
#   Sans option : vérifie les prérequis, propose de créer 2 issues de test et de lancer le pipeline.
#   --yes : crée 2 issues de test et lance le pipeline sans demander.
# Prérequis: git, sd (Seeds), pi. Le script fait sd init si .seeds/ est absent.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Afficher l'aide sans exiger les prérequis
for a in "$@"; do
  [ "$a" = "-h" ] || [ "$a" = "--help" ] && {
    echo "Usage: $0 [--yes]"
    echo "  Premier run : check → sd init si besoin → 2 issues test → pipeline."
    echo "  --yes : sans confirmation."
    exit 0
  }
done

AUTO_YES=""
[ "$1" = "--yes" ] && AUTO_YES=1

echo "=== Swarm — Premier run ==="
echo ""

# 1 — Vérifier git
"${REPO_ROOT}/scripts/swarm-check.sh" --quiet || exit 1

# 2 — sd (Seeds) : requis pour quickstart
if ! command -v sd >/dev/null 2>&1; then
  echo "Erreur: 'sd' (Seeds) introuvable. Voir https://github.com/jayminwest/seeds"
  exit 1
fi

# 3 — Initialiser .seeds/ si absent
if [ ! -d ".seeds" ]; then
  echo "Initialisation de Seeds dans le projet..."
  sd init
  echo ""
fi

# 4 — pi : requis pour le pipeline
if ! command -v pi >/dev/null 2>&1; then
  echo "Erreur: pi introuvable. Install: npm install -g @mariozechner/pi-coding-agent"
  exit 1
fi

# 5 — Proposer de créer des issues de test et lancer le pipeline
RUN_PIPELINE=""
if [ -n "$AUTO_YES" ]; then
  RUN_PIPELINE=1
else
  echo "Créer 2 issues de test et lancer le pipeline ? (o/n)"
  read -r rep
  case "$rep" in
    o|O|y|Y|oui|yes) RUN_PIPELINE=1 ;;
    *) echo "Pour lancer plus tard: ./scripts/swarm-seeds-create.sh \"Titre 1\" \"Titre 2\" puis ./scripts/swarm-pipeline.sh 2"; exit 0 ;;
  esac
fi

[ -n "$RUN_PIPELINE" ] || exit 0

echo ""
echo "=== Création de 2 issues de test ==="
"${REPO_ROOT}/scripts/swarm-seeds-create.sh" "Issue test 1" "Issue test 2"
echo ""
echo "=== Lancement du pipeline (2 agents) ==="
"${REPO_ROOT}/scripts/swarm-pipeline.sh" 2
