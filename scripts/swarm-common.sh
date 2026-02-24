# Fonctions partagées par les scripts swarm (à sourcer).
# Usage: source "$(cd "$(dirname "$0")/.." && pwd)/scripts/swarm-common.sh"   # depuis un script dans scripts/
# ou:    source "${REPO_ROOT}/scripts/swarm-common.sh"

# Génère le contenu de TASK.md (titre, issue, description, bloc "En cas de blocage").
# Usage: swarm_task_md_content issue_id title description [extra]
#   extra = contenu optionnel inséré après la ligne Issue et avant description (ex. "## Handoff depuis X\n\nbody")
# Sortie: contenu complet sur stdout (rediriger vers fichier).
swarm_task_md_content() {
  local issue_id="$1" title="$2" desc="${3:-}" extra="${4:-}"
  local block="Si tu bloques ou si un autre agent doit prendre la suite, envoie un message : \`../../scripts/swarm-mail.sh send --to coordinator --type help_request --body \"...\"\` ou \`--to agent-X --type handoff --body \"...\"\`. Voir les messages : \`./scripts/swarm-mail.sh show\` (depuis la racine)."
  echo "# Tâche: $title"
  echo ""
  echo "Issue: **$issue_id** (Seeds). En fin de session: \`sd close $issue_id --reason \"Résumé\"\`"
  echo ""
  if [ -n "$extra" ]; then
    echo "$extra"
    echo ""
    echo "---"
    echo ""
  fi
  echo "$desc"
  echo ""
  echo "## En cas de blocage ou pour passer la main"
  echo ""
  echo "$block"
}
