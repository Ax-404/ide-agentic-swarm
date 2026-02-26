# ide-agentic

Projet **IDE agentique type swarm** : plusieurs agents **pi** (coding agent) en parallèle (worktrees git), orchestrés manuellement puis en Phase 3 de façon automatisée, avec un proxy LiteLLM (Mac Mini) accessible via Tailscale. Optionnel : **[Mulch](https://github.com/jayminwest/mulch)** (expertise cumulée, `mulch record` / `mulch prime`) et **[Seeds](https://github.com/jayminwest/seeds)** (issues git-native, CLI `sd`) pour mémoire et suivi de tâches compatibles multi-agent. Mulch et Seeds sont **agnostiques** (pas limités à Claude) : Mulch supporte divers agents ; Seeds est un CLI appelable par tout processus.

## Structure du projet

```
ide-agentic/
├── README.md                 # Ce fichier
├── swarm-install.sh          # Installer le swarm dans un autre projet (à la racine)
├── .gitignore
├── docs/                     # Toute la documentation
│   ├── README.md             # Index de la doc
│   ├── config-litelmm-tailscale-aider.md   # Config proxy + Tailscale + pi/LLM
│   ├── projet-roadmap.md     # Phases et objectifs du projet
│   ├── exemples-commandes.md # Exemples de commandes $ (helper)
│   ├── utilisation-autres-projets.md       # Utiliser le swarm sur un autre projet
│   ├── workflows/            # Procédures par phase
│   │   └── phase2-workflow.md
│   └── examples/             # Exemples de tâches
│       └── example-task-1.md
├── scripts/                  # Scripts swarm (Phase 2)
│   ├── swarm-common.sh       # Fonctions partagées (swarm_task_md_content) — sourcé par dispatch, sling, handoff
│   ├── swarm-check.sh        # Vérif prérequis (git, jq, sd, pi) — appelé par les autres scripts
│   ├── swarm-quickstart.sh   # Premier run : check → sd init si besoin → 2 issues test → pipeline
│   ├── swarm-setup.sh        # Créer N worktrees
│   ├── swarm-run.sh          # Lancer pi dans un worktree (+ mulch prime si présent)
│   ├── swarm-merge.sh        # Merger les branches (--completed = seulement issues fermées)
│   ├── swarm-clean.sh        # Supprimer les worktrees (--merged-only)
│   ├── swarm-seeds-create.sh # Seeds : créer des issues
│   ├── swarm-dispatch.sh     # Phase 3 : dispatcher des issues → worktrees
│   ├── swarm-sling.sh        # Phase 3 : une issue → un agent (worktree + pi)
│   ├── swarm-log.sh          # Phase 4 : écrire dans .swarm/logs/events.log
│   ├── swarm-logs.sh         # Phase 4 : afficher / suivre les logs
│   ├── swarm-watch.sh        # Phase 4 : watchdog (PIDs vivants, --relaunch)
│   ├── swarm-dashboard.sh    # Phase 4 : tableau état agents (--watch)
│   ├── swarm-costs.sh        # Phase 5 : sessions + rappel coûts LiteLLM
│   ├── swarm-run-headless.sh # Phase 6 : pi non interactif (TASK.md via stdin puis exit, sd close)
│   ├── swarm-pipeline.sh     # Phase 6 : dispatch → headless → merge (--test optionnel)
│   ├── swarm-coordinate.sh   # Lot 2 : créer issues + lancer pipeline (--file tasks.txt)
│   ├── swarm-rollback.sh     # Phase 6 : revert du dernier merge
│   ├── swarm-alert.sh        # Lot 3 : alertes (hook, Slack) — merge_conflict, tests_failed, etc.
│   ├── swarm-deploy-staging.sh # Lot 3 : pipeline sur branche staging puis merge main
│   └── swarm-budget.sh       # Lot 3 : vérif budget (SWARM_BUDGET_MAX, alerte si dépassement)
│   ├── swarm-workflow.sh     # Moteur de workflow (exécute une définition dans workflows/)
│   ├── swarm-prompt.sh       # Entrée langage naturel : LLM décompose → coordinateur (LITELLM_API_BASE ou OPENROUTER_API_KEY)
│   ├── swarm-handoff.sh     # Handoff automatisé : mail handoff → réassigner issue + TASK.md pour l'agent cible
│   └── swarm-mail.sh         # Couche mail (retours en cours de tâche, handoffs, événements)
├── workflows/                # Définitions de workflows (format : étapes + args, séparateur --)
│   ├── README.md
│   ├── default.workflow      # Dispatch + pipeline
│   ├── autonomous.workflow   # Coordinate (création issues + pipeline)
│   ├── staging.workflow      # Deploy sur branche staging
│   └── prompt.workflow       # Un prompt → décomposition LLM → coordinateur
├── tests/
│   └── smoke.sh              # Tests smoke (check, common, mail, --help)
├── .vscode/
│   └── tasks.json            # Phase 5 : tâches IDE (Dispatch, Dashboard, Logs, etc.)
└── templates/                # Modèles réutilisables
    └── TASK.md               # Spec de tâche par agent
```

## Démarrage rapide

**Premier run (tout-en-un)** : `./scripts/swarm-quickstart.sh` — vérifie les prérequis, initialise Seeds si besoin, propose de créer 2 issues de test et lance le pipeline. Avec `--yes` : sans confirmation.

**Workspace / layout** : en **interactif** : 1 terminal à la racine (dispatch, merge, dashboard) + 1 terminal par agent (`swarm-run.sh agent-1`, `agent-2`, …). En **headless** : un seul terminal suffit — `swarm-pipeline.sh N` lance dispatch puis les agents en arrière-plan et fait le merge à la fin.

1. **Config** : [docs/config-litelmm-tailscale-aider.md](docs/config-litelmm-tailscale-aider.md) — proxy LiteLLM sur Mac Mini, Tailscale, pi sur MacBook.
2. **Roadmap** : [docs/projet-roadmap.md](docs/projet-roadmap.md) — objectifs et phases (1 à 6).
3. **Phase 2 (multi-agents)** : [docs/workflows/phase2-workflow.md](docs/workflows/phase2-workflow.md) — worktrees, lancer plusieurs pi, merge manuel.
4. **Phase 3 (orchestration)** : [docs/workflows/phase3-workflow.md](docs/workflows/phase3-workflow.md) — dispatch Seeds, sling, merge --completed, clean.
5. **Phase 4 (monitoring)** : [docs/workflows/phase4-workflow.md](docs/workflows/phase4-workflow.md) — watchdog, logs, dashboard.
6. **Phase 5 (évolution)** : [docs/workflows/phase5-workflow.md](docs/workflows/phase5-workflow.md) — IDE (Cursor/VS Code), autres clients, coûts ; tâches dans `.vscode/tasks.json`.
7. **Phase 6 (autonomie)** : [docs/workflows/phase6-workflow.md](docs/workflows/phase6-workflow.md) — agent headless, pipeline autonome, merge avec gate tests, rollback.

**Rôles** : Le swarm distingue Planner (décomposition → tâches), Scout (exploration lecture seule), Builder (exécution code), Reviewer, Documenter, Red-team. Détail et mapping scripts / contrats I/O : [docs/ROLES.md](docs/ROLES.md).

## Commandes Phase 2

```bash
./scripts/swarm-setup.sh 2           # Créer 2 agents (worktrees)
# Éditer .swarm/agent-1/TASK.md et .swarm/agent-2/TASK.md
./scripts/swarm-run.sh agent-1 sonnet-4.6     # Terminal 1
./scripts/swarm-run.sh agent-2 claude-sonnet  # Terminal 2
# Après travail : commit dans chaque worktree, puis :
git checkout main && ./scripts/swarm-merge.sh
```

**Commandes Phase 3 (orchestration Seeds)**  
```bash
./scripts/swarm-seeds-create.sh "Titre 1" "Titre 2"   # ou sd create
./scripts/swarm-dispatch.sh 2                         # issues ouvertes → worktrees
./scripts/swarm-run.sh agent-1 sonnet-4.6                 # par terminal (ou swarm-sling.sh <issue-id>)
# Dans chaque worktree : sd close <id> --reason "..." puis commit
git checkout main && ./scripts/swarm-merge.sh --completed
./scripts/swarm-clean.sh --force
```

**Commandes Phase 6 (autonomie)**  
```bash
./scripts/swarm-prompt.sh "Ajoute l'auth et les logs" [--test "make test"]   # Un prompt → LLM → coordinateur (LITELLM_API_BASE ou OPENROUTER_API_KEY)
./scripts/swarm-coordinate.sh "Titre 1" "Titre 2" [--test "make test"]   # Créer issues + lancer pipeline (lot 2)
./scripts/swarm-run-headless.sh agent-1 sonnet-4.6   # Une tâche (TASK.md) puis stop, sd close auto
./scripts/swarm-pipeline.sh 2                    # Dispatch 2 → headless → merge --completed
./scripts/swarm-pipeline.sh 2 --test "make test" # Idem, ne merger que si tests verts
./scripts/swarm-merge.sh --completed --test "pytest"
./scripts/swarm-rollback.sh                     # Revert du dernier merge
# Lot 3 : staging, alertes, budget
./scripts/swarm-deploy-staging.sh 2 --test "make test"   # Pipeline sur staging
SWARM_BUDGET_MAX=10 ./scripts/swarm-budget.sh            # Vérif budget (SWARM_SLACK_WEBHOOK_URL pour alertes)
# Moteur de workflow (définition en fichier)
./scripts/swarm-workflow.sh                               # default.workflow ou autonomous.workflow
./scripts/swarm-workflow.sh workflows/staging.workflow    # Workflow explicite
```
Voir [docs/workflows/phase6-workflow.md](docs/workflows/phase6-workflow.md) et [workflows/README.md](workflows/README.md).  
Tests smoke (après modif des scripts) : `./tests/smoke.sh`

## Utiliser ce projet sur un autre dépôt

Pour que le swarm **agisse directement sur un autre projet** (construction, code, issues), il faut que les scripts tournent **depuis la racine de ce projet**. Concrètement :

- **Copier** le swarm dans la racine du projet cible : depuis la racine du projet, lancer `./swarm-install.sh /chemin/vers/autre-projet` (ou copier à la main `scripts/`, `docs/`, `templates/`, `.vscode/`, et `.swarm/` dans `.gitignore`). Puis lancer les commandes **depuis la racine du projet cible** (`./scripts/swarm-setup.sh`, etc.).
- Ou **créer le nouveau projet** à partir de ce dépôt (template) pour qu’il contienne déjà le swarm.

Détail : [docs/utilisation-autres-projets.md](docs/utilisation-autres-projets.md).

---

## Dépannage

Voir [docs/troubleshooting.md](docs/troubleshooting.md) : pi / LLM ne répond pas (proxy), sd introuvable, aucune issue ouverte, conflit au merge, mail vide, commandes de diagnostic.

---

## Prérequis

- Git (dépôt initialisé avec au moins un commit pour Phase 2).
- pi installé (`npm install -g @mariozechner/pi-coding-agent`), proxy LLM configuré (voir doc config). Pour swarm-prompt.sh : `LITELLM_API_BASE` (LiteLLM) ou `OPENROUTER_API_KEY` (OpenRouter). **Extension IDE** (VS Code / Cursor) : [pi-vs-claude-code](https://github.com/disler/pi-vs-claude-code).
- Optionnel : LiteLLM sur Mac Mini, Tailscale sur les deux machines ; **[Mulch](https://github.com/jayminwest/mulch)** (npm install -g mulch-cli) et **[Seeds](https://github.com/jayminwest/seeds)** (Bun, CLI `sd`) pour expertise et suivi d’issues — voir [docs/projet-roadmap.md](docs/projet-roadmap.md).
