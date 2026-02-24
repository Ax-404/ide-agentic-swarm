# Documentation

Index de la documentation du projet **ide-agentic**.

## Utilisation sur d’autres projets

| Document | Description |
|----------|-------------|
| [utilisation-autres-projets.md](utilisation-autres-projets.md) | Copier le swarm dans un autre projet ou l’utiliser comme template pour qu’il agisse sur la construction du projet. |

| [exemples-commandes.md](exemples-commandes.md) | **Helper** : exemples de commandes (setup, Seeds, coordinateur, prompt, pipeline, workflows, monitoring). |

## Configuration et déploiement

| Document | Description |
|----------|-------------|
| [config-litelmm-tailscale-aider.md](config-litelmm-tailscale-aider.md) | Proxy LiteLLM sur Mac Mini M2, Tailscale, configuration Aider sur MacBook M1. |

## Projet et roadmap

| Document | Description |
|----------|-------------|
| [projet-roadmap.md](projet-roadmap.md) | Objectifs, stack (LiteLLM, Aider, [Mulch](https://github.com/jayminwest/mulch), [Seeds](https://github.com/jayminwest/seeds)), avis Mulch/Seeds, phases (1 à 6) et risques. |

## Workflows

| Document | Description |
|----------|-------------|
| [workflows/phase2-workflow.md](workflows/phase2-workflow.md) | Procédure Phase 2 : multi-agents manuels (worktrees, Aider, merge), option [Seeds](https://github.com/jayminwest/seeds) (issues) et [Mulch](https://github.com/jayminwest/mulch) (expertise). |
| [workflows/phase3-workflow.md](workflows/phase3-workflow.md) | Procédure Phase 3 : orchestration (dispatch Seeds → worktrees, sling, merge --completed, clean). |
| [workflows/phase4-workflow.md](workflows/phase4-workflow.md) | Procédure Phase 4 : watchdog, logs centralisés, dashboard CLI. |
| [workflows/phase5-workflow.md](workflows/phase5-workflow.md) | Phase 5 : IDE (Cursor/VS Code), autres clients, coûts/tokens. |
| [workflows/phase6-workflow.md](workflows/phase6-workflow.md) | Phase 6 : autonomie (headless, pipeline, coordinateur, conflits, rollback) + lot 3 (staging, alertes, budget) + moteur de workflow (§12). |

## Exemples

| Document | Description |
|----------|-------------|
| [examples/example-task-1.md](examples/example-task-1.md) | Exemple de sous-tâche pour un agent (à copier dans `.swarm/agent-X/TASK.md`). |
