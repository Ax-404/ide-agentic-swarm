# Workflow staging : pipeline sur la branche staging (puis merge manuel vers main).
# Usage: ./scripts/swarm-workflow.sh workflows/staging.workflow

deploy-staging
2
--test
make test
--on-conflict
skip
--
