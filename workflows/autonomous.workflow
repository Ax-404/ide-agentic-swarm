# Workflow autonome : coordinate (créer issues + lancer pipeline) en une étape.
# Adaptez les titres ou utilisez coordinate --file tasks.txt en ligne de commande.
# Usage: ./scripts/swarm-workflow.sh workflows/autonomous.workflow

coordinate
Tâche 1
Tâche 2
--test
make test
--on-conflict
skip
--
