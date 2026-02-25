# Exemples de commandes swarm

Commandes à lancer **depuis la racine du projet** (après `cd mon-projet` ou après `./swarm-install.sh /chemin/vers/mon-projet`).

---

## Quel script pour quoi ?

| Entrée | Prérequis | Script à lancer |
|--------|-----------|-----------------|
| **Premier run** (tout valider en une fois) | git, sd, aider | `./scripts/swarm-quickstart.sh` ou `./scripts/swarm-quickstart.sh --yes` |
| **Manuelle** (sans Seeds) : worktrees + TASK à la main | git, aider | `swarm-setup.sh N` → éditer TASK.md → `swarm-run.sh agent-X` → `swarm-merge.sh` |
| **Manuelle avec Seeds** : issues déjà créées | git, sd, .seeds/, aider | `swarm-dispatch.sh N` → `swarm-run.sh agent-X` ou `swarm-pipeline.sh N` |
| **Liste de tâches** (titres → issues + pipeline) | git, sd, aider, (jq pour merge/dashboard) | `swarm-coordinate.sh "T1" "T2"` ou `--file tasks.txt` + options |
| **Prompt naturel** (phrase → LLM → sous-tâches → pipeline) | git, sd, aider, **LITELLM_API_BASE** ou **OPENROUTER_API_KEY**, jq, curl | `swarm-prompt.sh "Ta demande"` + options |
| **Une issue précise** | git, sd, .seeds/, aider | `swarm-sling.sh <issue-id> [model]` |
| **Diagnostic prérequis** | — | `./scripts/swarm-check.sh` ou `--require seeds|jq|aider` |
| **Handoff agent → agent** (appliquer les handoffs mail) | git, sd, jq, .seeds/, mail | `swarm-handoff.sh` ou `swarm-handoff.sh list` |

**Prérequis détaillés :** Seeds = `sd` + répertoire `.seeds/` (sinon `sd init`). Mulch = optionnel (expertise). jq = recommandé pour mail, prompt, lecture JSONL. Pour `swarm-prompt.sh` : **LITELLM_API_BASE** (proxy LiteLLM) ou **OPENROUTER_API_KEY** (OpenRouter) — voir section « Variables LLM » ci-dessous. Aider : configurer le proxy selon sa doc.

---

## Premier usage (sans Seeds)

```bash
# Créer 2 worktrees
./scripts/swarm-setup.sh 2

# Éditer les tâches dans .swarm/agent-1/TASK.md et .swarm/agent-2/TASK.md puis lancer Aider en interactif
./scripts/swarm-run.sh agent-1 sonnet-4.6
# Dans un 2e terminal :
./scripts/swarm-run.sh agent-2 sonnet-4.6

# Merger les branches dans la branche courante
./scripts/swarm-merge.sh

# Nettoyer les worktrees
./scripts/swarm-clean.sh --force
```

---

## Avec Seeds (issues)

```bash
# Initialiser Seeds
sd init

# Créer des issues (une par sous-tâche)
./scripts/swarm-seeds-create.sh "Auth login" "Middleware logs" "Tests API"

# Dispatcher 2 issues → 2 worktrees + TASK.md + issues en in_progress
./scripts/swarm-dispatch.sh 2

# Lancer les agents (interactif ou headless)
./scripts/swarm-run.sh agent-1 sonnet-4.6
# ou pipeline automatique (dispatch déjà fait) :
./scripts/swarm-pipeline.sh 2

# Merge uniquement les branches dont l'issue Seeds est fermée
./scripts/swarm-merge.sh --completed

# Nettoyer (optionnel)
./scripts/swarm-clean.sh --merged-only
```

---

## Coordinateur (liste de tâches → issues + pipeline)

```bash
# Une commande : crée les issues puis lance le pipeline
./scripts/swarm-coordinate.sh "Refactor module A" "Ajouter cache Redis" "Doc README" --test "make test"

# Depuis un fichier (une tâche par ligne)
echo -e "Refactor module A\nAjouter cache Redis\nDoc README" > tasks.txt
./scripts/swarm-coordinate.sh --file tasks.txt --test "pytest" --on-conflict skip
```

---

## Prompt (langage naturel → sous-tâches → pipeline)

**Variables LLM (choix unique)** : `swarm-prompt.sh` lit l’env et choisit automatiquement **LiteLLM** (`LITELLM_API_BASE` = URL du proxy) ou **OpenRouter** (`OPENROUTER_API_KEY` = clé API). Priorité à LiteLLM si les deux sont définis. Le choix se fait en exportant l’une des deux variables (dans ce dépôt ou au build).

Prérequis : `LITELLM_API_BASE` ou `OPENROUTER_API_KEY`.

```bash
# Option 1 — LiteLLM
export LITELLM_API_BASE="http://macmini.ton-tailnet.ts.net:4000"

# Option 2 — OpenRouter
# export OPENROUTER_API_KEY="sk-or-v1-..."

# Un prompt → le LLM décompose en sous-tâches → coordinateur → pipeline
./scripts/swarm-prompt.sh "Ajoute l'authentification JWT et un middleware de logs" --test "make test"

# Entrée depuis stdin
echo "Refactoriser l'API et ajouter des tests unitaires" | ./scripts/swarm-prompt.sh --stdin --test "pytest"
```

---

## Pipeline avec garde-fous

```bash
# Gate tests + validation post-merge + rollback si la validation échoue
./scripts/swarm-pipeline.sh 2 --test "make test" --validate "make test" --rollback-on-validate-fail --on-conflict skip

# Limiter les retries par agent (après N échecs headless, l'issue est rouverte mais plus relancée automatiquement)
SWARM_MAX_RETRIES=3 ./scripts/swarm-pipeline.sh 2 --test "make test"

# Agents en parallèle
./scripts/swarm-pipeline.sh 2 --test "make test" --parallel
```

---

## Workflows (fichiers .workflow)

```bash
# Lister les workflows disponibles
./scripts/swarm-workflow.sh --list

# Lancer le workflow par défaut (default.workflow ou autonomous.workflow)
./scripts/swarm-workflow.sh

# Par nom court
./scripts/swarm-workflow.sh staging
./scripts/swarm-workflow.sh autonomous
./scripts/swarm-workflow.sh prompt

# Par chemin
./scripts/swarm-workflow.sh workflows/staging.workflow
```

---

## Staging, rollback, validation, budget

```bash
# Pipeline sur la branche staging (puis merge staging → main à la main)
./scripts/swarm-deploy-staging.sh 2 --test "make test"

# Revert du dernier merge
./scripts/swarm-rollback.sh

# Validation post-merge : si "make test" échoue, rollback automatique + alerte
./scripts/swarm-validate.sh "make test" --rollback-on-fail

# Vérifier le budget LLM (alerte si dépassement)
SWARM_BUDGET_MAX=10.00 ./scripts/swarm-budget.sh
```

---

## Une issue précise (sling)

```bash
# Assigner une issue Seeds à un worktree dédié et lancer Aider
./scripts/swarm-sling.sh seeds-abc123 sonnet-4.6
```

---

## Monitoring

```bash
# Dashboard (état des agents, issues, PID + derniers messages mail)
./scripts/swarm-dashboard.sh

# Dashboard en rafraîchissement continu
./scripts/swarm-dashboard.sh --watch --interval 5

# Derniers événements (log central)
./scripts/swarm-logs.sh --tail

# Nombre de sessions agents (indication pour les coûts)
./scripts/swarm-costs.sh
```

---

## Mail (retours en cours de tâche, handoffs, événements)

En plus de Seeds, la couche **mail** permet aux agents d’envoyer des messages sans fermer l’issue (blocage, demande d’aide, handoff à un autre agent).

```bash
# Envoyer un message (depuis un worktree, --from est optionnel)
./scripts/swarm-mail.sh send --from agent-1 --to coordinator --type help_request --body "Conflit dans src/auth.ts"
./scripts/swarm-mail.sh send --to agent-2 --type handoff --body "Validation faite, voir src/validator.ts" --issue-id seeds-xxx

# Lister les messages
./scripts/swarm-mail.sh list --to coordinator [--type blocked] [--limit 20]

# Affichage lisible : derniers N messages (défaut 5). Pour un suivi léger, « derniers N » suffit.
./scripts/swarm-mail.sh show 10
```

Types : `progress` | `blocked` | `help_request` | `handoff` | `event`.  
Destinataires : `coordinator` | `agent-X` | `broadcast` | `issue:seeds-xxx`.  
Voir [phase6-workflow.md §15](workflows/phase6-workflow.md).

---

## Handoff automatisé (agent A → agent B)

Après qu’un agent a envoyé un message handoff (ex. `--to agent-2 --type handoff --body "..."`), appliquer les handoffs pour réassigner l’issue au worktree de l’agent cible et mettre à jour TASK.md :

```bash
# Voir les derniers handoffs sans appliquer
./scripts/swarm-handoff.sh list --limit 5

# Appliquer les handoffs (crée/réassigne worktree + TASK.md + issue in_progress)
./scripts/swarm-handoff.sh [--limit 10] [--dry-run]

# Puis lancer l’agent cible
./scripts/swarm-run.sh agent-2 sonnet-4.6
```

---

## Récap des scripts principaux

| Script | Rôle |
|--------|------|
| `swarm-common.sh` | **Sourcé** par dispatch, sling, handoff : fonction `swarm_task_md_content` (génération TASK.md). |
| `swarm-check.sh [--require seeds\|jq\|aider]` | Vérifie les prérequis (git, sd, jq, aider). |
| `swarm-quickstart.sh [--yes]` | Premier run : check → sd init si besoin → 2 issues test → pipeline. |
| `swarm-setup.sh [N]` | Crée N worktrees (sans Seeds). |
| `swarm-seeds-create.sh "T1" "T2"` | Crée les issues Seeds. |
| `swarm-dispatch.sh [N]` | Assigne N issues open → worktrees + TASK.md. |
| `swarm-run.sh agent-X [model] [scout\|builder]` | Aider interactif (+ mulch prime). Rôle `scout` = rappel lecture seule ; `builder` = défaut. Voir [ROLES.md](ROLES.md). |
| `swarm-run-headless.sh agent-X [model]` | Aider non interactif (TASK.md, close/reopen issue). |
| `swarm-pipeline.sh [N] [--test "cmd"] ...` | Dispatch → headless → merge (→ validate). |
| `swarm-coordinate.sh "T1" "T2" [options]` | Crée issues + pipeline. |
| `swarm-prompt.sh "demande" [options]` | LLM → sous-tâches → coordinateur (LITELLM_API_BASE ou OPENROUTER_API_KEY). |
| `swarm-merge.sh [--completed] [--test "cmd"]` | Merge des branches (optionnel : seulement si issue closed). |
| `swarm-clean.sh [--merged-only] [--force]` | Supprime les worktrees. |
| `swarm-workflow.sh [nom]` | Exécute un fichier workflows/*.workflow. |
| `swarm-mail.sh send|list|show` | Couche mail : retours en cours de tâche, handoffs, événements (en plus de Seeds). |
| `swarm-handoff.sh [--limit N]` | Lit les handoffs mail → réassigne l'issue à l'agent cible (TASK.md + in_progress). |

Voir aussi : [phase6-workflow.md](workflows/phase6-workflow.md), [utilisation-autres-projets.md](utilisation-autres-projets.md), [ROLES.md](ROLES.md) (Planner, Scout, Builder, Reviewer, Documenter, Red-team).
