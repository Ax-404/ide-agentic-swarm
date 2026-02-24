#!/usr/bin/env bash
# Copie les dossiers swarm (scripts, docs, templates, .vscode) dans un autre projet
# pour que le swarm agisse directement sur ce projet.
# Usage: ./swarm-install.sh /chemin/vers/autre-projet
# À lancer depuis la racine du projet (ide-agentic ou tout projet contenant le swarm).

set -e
SOURCE_ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:?Usage: $0 /chemin/vers/autre-projet}"

if [ ! -d "$SOURCE_ROOT/scripts" ] || [ ! -f "$SOURCE_ROOT/scripts/swarm-setup.sh" ]; then
  echo "Erreur: scripts swarm introuvables dans $SOURCE_ROOT"
  exit 1
fi

TARGET_ROOT="$(cd "$TARGET" && pwd)"
if [ "$TARGET_ROOT" = "$SOURCE_ROOT" ]; then
  echo "La cible est le même répertoire que la source. Rien à faire."
  exit 0
fi

echo "Installation du swarm vers: $TARGET_ROOT"
mkdir -p "$TARGET_ROOT/scripts" "$TARGET_ROOT/docs" "$TARGET_ROOT/templates" "$TARGET_ROOT/.vscode" "$TARGET_ROOT/workflows"

cp "$SOURCE_ROOT/scripts"/swarm-*.sh "$TARGET_ROOT/scripts/" 2>/dev/null || true
chmod +x "$TARGET_ROOT/scripts"/swarm-*.sh 2>/dev/null || true

cp -r "$SOURCE_ROOT/docs/"* "$TARGET_ROOT/docs/" 2>/dev/null || true
cp -r "$SOURCE_ROOT/templates/"* "$TARGET_ROOT/templates/" 2>/dev/null || true
cp "$SOURCE_ROOT/.vscode/tasks.json" "$TARGET_ROOT/.vscode/" 2>/dev/null || true
[ -d "$SOURCE_ROOT/workflows" ] && cp -r "$SOURCE_ROOT/workflows/"* "$TARGET_ROOT/workflows/" 2>/dev/null || true

# Copier ce script à la racine du projet cible pour qu'il puisse à son tour installer ailleurs
cp "$SOURCE_ROOT/swarm-install.sh" "$TARGET_ROOT/" 2>/dev/null && chmod +x "$TARGET_ROOT/swarm-install.sh" || true

if [ -f "$TARGET_ROOT/.gitignore" ]; then
  grep -q '\.swarm/' "$TARGET_ROOT/.gitignore" || echo '.swarm/' >> "$TARGET_ROOT/.gitignore"
else
  echo '.swarm/' >> "$TARGET_ROOT/.gitignore"
fi

echo ""
echo "Swarm installé dans $TARGET_ROOT"
echo "Depuis ce projet, lance par exemple:"
echo "  cd $TARGET_ROOT"
echo "  git init && git add . && git commit -m 'initial'   # si besoin"
echo "  sd init   # si tu utilises Seeds"
echo "  ./scripts/swarm-setup.sh 2"
echo "  ./scripts/swarm-dispatch.sh 2"
echo "  ./scripts/swarm-pipeline.sh 2   # Phase 6 : dispatch + headless + merge"
echo "  ./scripts/swarm-workflow.sh     # Moteur workflow (workflows/default.workflow)"
echo "  ./scripts/swarm-prompt.sh \"Ta demande\"   # Entrée langage naturel (OPENAI_API_BASE requis)"
echo "  ./scripts/swarm-rollback.sh     # Phase 6 : revert dernier merge"
echo "  ./scripts/swarm-validate.sh \"make test\" --rollback-on-fail   # Phase 6 : validation post-merge + rollback si échec"
echo "  ./scripts/swarm-mail.sh show 15   # Derniers messages (retours, handoffs)"
echo "Voir: docs/exemples-commandes.md, docs/utilisation-autres-projets.md et docs/workflows/phase6-workflow.md"
