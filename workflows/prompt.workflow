# Workflow : une demande en langage naturel → décomposition LLM → coordinateur
# Usage: ./scripts/swarm-workflow.sh prompt (après avoir exporté LITELLM_API_BASE ou OPENROUTER_API_KEY)
# Remplacez la ligne "Ajoute l'auth et les logs" par votre demande ou lancez swarm-prompt.sh directement.

prompt
Ajoute l'authentification et un middleware de logs
--test
make test
--on-conflict
skip
--
