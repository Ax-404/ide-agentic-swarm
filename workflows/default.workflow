# Workflow par défaut (lien ou copie). Ici = pipeline seul (sans coordinate).
# Prérequis : des issues Seeds déjà ouvertes (sd create ou swarm-seeds-create.sh).
# Usage: ./scripts/swarm-workflow.sh

dispatch
2
--
pipeline
2
--test
make test
--on-conflict
skip
--
