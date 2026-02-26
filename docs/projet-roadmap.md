# Projet : IDE agentique type swarm (pi + couche Overstory-like)

Ce document décrit ce que l’on va faire pour le projet : un système agentique multi-agents (swarm) basé sur pi et une couche d’orchestration inspirée d’Overstory, utilisable en terminal (et plus tard éventuellement dans un IDE), avec des modèles ouverts (Kimi K2, GLM-5, MiniMax 2.5, etc.) via un proxy LiteLLM.

---

## 1. Objectifs

- **Multi-LLM** : utiliser n’importe quel modèle (Kimi K2, GLM-5, MiniMax 2.5, OpenAI, Anthropic, etc.) via un proxy LiteLLM hébergé sur un Mac Mini M2.
- **Accès depuis le MacBook M1** : pi (et les futurs agents) pointent vers le proxy via Tailscale.
- **Swarm** : plusieurs agents (pi) qui travaillent en parallèle sur des tâches décomposées, avec coordination (type Overstory) et merge des résultats.
- **Usage terminal** en priorité ; extension IDE (VS Code / Cursor) possible plus tard.

---

## 2. Stack technique retenue

| Composant | Choix | Rôle |
|-----------|--------|------|
| **Proxy LLM** | LiteLLM (Mac Mini M2) | Un seul endpoint, multi-providers, clés centralisées. |
| **Réseau** | Tailscale | Accès au proxy depuis le MacBook (et ailleurs) sans ouvrir de ports. |
| **Agent de base** | pi | Agent coding en terminal, multi-LLM via LiteLLM/OpenRouter. |
| **Orchestration** | Couche “Overstory-like” (à construire) | Worktrees, coordination, mail/queue, merge. |
| **Expertise / mémoire** | [Mulch](https://github.com/jayminwest/mulch) | Fichiers d’expertise (`.mulch/`, JSONL) : `mulch record` / `mulch query` / `mulch prime` ; cumul entre sessions et entre agents, merge=union. |
| **Suivi de tâches** | [Seeds](https://github.com/jayminwest/seeds) | Tracker d’issues git-native (`.seeds/`, JSONL), CLI `sd` : créer issues, `sd ready`, claim/close ; compatible multi-worktree (merge=union). |

---

## 2bis. Avis sur Mulch et Seeds

**Ils ne sont pas réservés à Claude.** Mulch et Seeds sont conçus pour **tout agent** : Mulch indique *"work with any agent"* et *"Provider-agnostic — Any agent with bash access can call the CLI"*, et `mulch setup [provider]` propose **claude, cursor, codex, gemini, windsurf, aider** (Aider reste une option ; pi est le défaut). Seeds est un simple CLI `sd` sans dépendance à un agent ; Overstory l’utilise mais n’importe quel processus peut appeler `sd`.

**Mulch** ([github.com/jayminwest/mulch](https://github.com/jayminwest/mulch)) : *“Growing Expertise for Coding Agents”* — couche passive (pas de LLM) : les agents appellent `mulch record` pour écrire des apprentissages (conventions, échecs, décisions, patterns) et `mulch query` / `mulch prime` pour les relire. Tout vit dans `.mulch/` (JSONL par domaine), versionné en git. Conçu pour le multi-agent (verrous, écritures atomiques, `merge=union` dans git). **Intérêt pour nous** : chaque agent (ou le coordinateur) peut enregistrer ce qu’il a appris ; au merge des branches, l’expertise se combine ; en début de session ou avant dispatch, `mulch prime` donne le contexte au modèle. À intégrer dès la Phase 2 (optionnel) et systématiquement en Phase 3.

**Seeds** ([github.com/jayminwest/seeds](https://github.com/jayminwest/seeds)) : tracker d’issues git-native pour workflows agents (remplace “beads” dans l’écosystème Overstory). Stockage JSONL dans `.seeds/`, CLI `sd`, zéro dépendance runtime (Bun). Création d’issues (`sd create`), liste du travail prêt (`sd ready`), claim (`sd update id --status in_progress`), clôture (`sd close id --reason "..."`). Merge-friendly (`merge=union`), dédup à la lecture. **Intérêt pour nous** : un coordinateur (ou toi en manuel) peut créer des issues par sous-tâche, les agents “prennent” une issue via `sd ready` / `sd update`, et à la fin `sd close` ; au merge des worktrees, les changements `.seeds/` se fusionnent proprement. Naturel en Phase 2 (issues = sous-tâches) et Phase 3 (orchestration qui s’appuie sur `sd` pour le dispatch).

---

## 3. Phases du projet

### Phase 1 — Proxy + pi (priorité immédiate)

- [ ] Héberger le proxy LiteLLM sur le Mac Mini M2 (voir [config-litelmm-tailscale-aider.md](config-litelmm-tailscale-aider.md)).
- [ ] Configurer Tailscale sur Mac Mini et MacBook ; vérifier la connectivité.
- [ ] Configurer pi sur le MacBook pour utiliser l’URL du proxy (Tailscale du Mac Mini). Pour swarm-prompt.sh : LITELLM_API_BASE.
- [ ] Tester plusieurs modèles (OpenAI, Anthropic, Kimi, GLM, MiniMax selon config) via pi.
- [ ] Valider latence et stabilité (depuis le LAN et depuis l’extérieur via Tailscale).

**Livrable** : un flux MacBook → Tailscale → Mac Mini (LiteLLM) → APIs LLM fonctionnel et documenté.

---

### Phase 2 — Multi-agents “manuels” (sans orchestration)

- [x] Définir un workflow simple : 1 coordinateur (toi ou un script) qui découpe une tâche en N sous-tâches.
- [x] Lancer N processus pi (ou N terminaux) dans N répertoires ou worktrees git distincts (un par sous-tâche).
- [x] Chaque instance pi pointe vers le même proxy (Mac Mini) ; possibilité d’attribuer des modèles différents par rôle (ex. Scout = Kimi, Builder = MiniMax).
- [x] Merge manuel des branches / répertoires une fois les sous-tâches terminées.
- [x] Documenter le pattern (worktrees, commandes, exemples de découpage).
- [x] **(Optionnel)** Introduire **Seeds** : `sd init` dans le projet, créer une issue par sous-tâche (`sd create --title "..."`), assigner manuellement chaque issue à un worktree ; à la fin `sd close` dans chaque agent et merger (`.seeds/` merge=union). Script `scripts/swarm-seeds-create.sh` + doc section 8 dans [workflows/phase2-workflow.md](workflows/phase2-workflow.md).
- [x] **(Optionnel)** Introduire **Mulch** : `mulch init` + `mulch add <domaine>` ; dans chaque agent, en fin de session faire `mulch record` pour les apprentissages ; au merge des branches, l’expertise se cumule ; en début de session `mulch prime` injecté automatiquement par `swarm-run.sh`. Doc section 9 dans [workflows/phase2-workflow.md](workflows/phase2-workflow.md).

**Livrable** : procédure reproductible pour faire travailler plusieurs pi en parallèle avec merge manuel.

**Implémenté** : scripts `scripts/swarm-setup.sh`, `scripts/swarm-run.sh`, `scripts/swarm-merge.sh`, `scripts/swarm-seeds-create.sh` ; template `templates/TASK.md` ; intégration optionnelle Seeds (issues par sous-tâche) et Mulch (`mulch prime` dans swarm-run, `mulch record` en fin de session) ; workflow détaillé dans [workflows/phase2-workflow.md](workflows/phase2-workflow.md).

---

### Phase 3 — Couche orchestration type Overstory

- [x] **Worktrees** : un worktree git par agent ; création/suppression automatisée (`swarm-dispatch.sh`, `swarm-sling.sh`, `swarm-clean.sh`).
- [x] **Seeds** : `sd` pour le suivi — dispatch (`swarm-dispatch.sh` crée worktrees + TASK + `sd update in_progress`), sling une issue (`swarm-sling.sh <issue-id>`), merge des branches dont issue fermée (`swarm-merge.sh --completed`). `.seeds/` merge=union.
- [x] **Mulch** : `mulch prime` déjà injecté au démarrage dans `swarm-run.sh` ; en fin de tâche les agents font `mulch record` (documenté). `.mulch/` merge=union.
- [x] **Coordination** : Seeds = file d’issues (open → in_progress → closed) ; dispatch piloté par `sd list --status open` / `.seeds/issues.jsonl` ; “task done” = `sd close` + `swarm-merge.sh --completed`.
- [x] **Rôles** : option `scout` | `builder` dans `swarm-run.sh` (rappel contexte ; pas d’application mécanique).
- [x] **Merge** : `swarm-merge.sh` avec option `--completed` (ne merge que les branches dont l’issue est closed) ; conflits à résoudre à la main.
- [x] **CLI / scripts** : `swarm-dispatch.sh [N]`, `swarm-sling.sh <issue-id> [model]`, `swarm-merge.sh [--completed|--all]`, `swarm-clean.sh [--merged-only] [--force]`.

**Livrable** : couche “Overstory-like” minimaliste (scripts + worktrees + Seeds + Mulch) utilisable avec pi. Doc : [workflows/phase3-workflow.md](workflows/phase3-workflow.md).

---

### Phase 4 — Robustesse et monitoring (optionnel)

- [x] **Watchdog léger** : `swarm-watch.sh` vérifie les PIDs dans `.swarm/agent-*/.pid` ; option `--once`, `--interval`, `--relaunch` pour relancer un agent mort. Les PIDs sont enregistrés par `swarm-run.sh` au démarrage de pi.
- [x] **Logs centralisés** : `.swarm/logs/events.log` (append) ; `swarm-log.sh` pour écrire, `swarm-logs.sh` pour afficher / suivre. Les scripts swarm (run, dispatch, merge, sling, watch) enregistrent les événements.
- [x] **Dashboard minimal** : `swarm-dashboard.sh` affiche un tableau (agent, issue, statut Seeds, PID, actif) + dernières lignes du log ; option `--watch` pour rafraîchissement périodique.

**Livrable** : scripts et doc dans [workflows/phase4-workflow.md](workflows/phase4-workflow.md).

---

### Phase 5 — Évolution (optionnel)

- [x] **Intégration IDE** : doc [workflows/phase5-workflow.md](workflows/phase5-workflow.md) (Cursor/VS Code : Custom API Base = URL du proxy) ; tâches dans `.vscode/tasks.json` pour lancer Dispatch, Dashboard, Logs, Watchdog, Merge, Costs depuis **Terminal → Run Task**.
- [x] **Autres clients** : tout client OpenAI-compatible peut utiliser le proxy (URL + modèle) ; doc avec exemple `curl` et rappel SDK (base URL).
- [x] **Coûts / tokens** : doc sur LiteLLM (en-tête `x-litellm-response-cost`, DB, [cost tracking](https://docs.litellm.ai/docs/proxy/cost_tracking)) ; script `swarm-costs.sh` qui compte les sessions (agent_start) dans le log et rappelle où obtenir les coûts réels.

---

### Phase 6 — Autonomie (système plus qu’autonome)

Objectif : rendre le swarm **autonome** — déclenchement sans humain, exécution non interactive, merge conditionnel aux tests, et garde-fous (staging, rollback).

- [x] **Agent non interactif** : script `swarm-run-headless.sh` qui lance pi en mode non interactif (message via stdin, `--print-turn`), attend la fin (exit code), ferme l’issue Seeds (`sd close`) et écrit dans les logs. Référence : [pi.dev](https://pi.dev).
- [x] **Boucle automatique** :
  - **Trigger** : cron, webhook ou queue (exemples dans [workflows/phase6-workflow.md](workflows/phase6-workflow.md)).
  - **Dispatch** : réutilisation de `swarm-dispatch.sh`.
  - **Lancement des agents** : script `swarm-pipeline.sh` qui enchaîne dispatch → pour chaque worktree avec `.issue_id` + `TASK.md` lance `swarm-run-headless.sh` (séquentiel ou `--parallel`).
  - **Collecte des résultats** : à la sortie de l’agent headless, `sd close` et logs (`agent_finish_headless`).
  - **Merge avec gate optionnel** : `swarm-merge.sh --completed --test "cmd"` (ex. `make test`) ne merge que les branches où la commande réussit dans le worktree ; `swarm-pipeline.sh --test "cmd"` enchaîne merge avec cette gate.
- [x] **Sécurité** :
  - **Tests automatiques** : option `--test "cmd"` dans `swarm-merge.sh` et `swarm-pipeline.sh` ; la commande est exécutée dans chaque worktree avant de merger cette branche.
  - **Staging** : décrit dans phase6-workflow.md (branche staging, merge puis validation).
  - **Politique de merge** : merge uniquement si tests verts via `--test "cmd"`.
  - **Rollback** : script `swarm-rollback.sh` (revert du dernier commit ou d’un hash donné ; détection merge → `git revert -m 1`) + runbook dans phase6-workflow.md.
- [x] **Moteur de workflow** : `swarm-workflow.sh` lit un fichier dans `workflows/` (étapes = script + args, séparateur `--`). Fichiers : default.workflow, autonomous.workflow, staging.workflow. Voir phase6-workflow.md §12 et workflows/README.md.
- [x] **Auto-correction** :
  - **Retry** : en cas d’échec d’un agent headless (exit ≠ 0), réouverture de l’issue Seeds pour re-dispatch ; option `SWARM_MAX_RETRIES` pour plafonner les tentatives (alerte `retry_exhausted` au-delà). En cas d’échec des tests avant merge, réouverture de l’issue pour re-dispatch.
  - **Validation en boucle** : script `swarm-validate.sh` ; option pipeline `--validate "cmd"` et `--rollback-on-validate-fail` : après merge, exécution de la commande sur la branche cible ; si échec, rollback automatique du dernier merge + alerte `validate_failed`.
  - **Conflits** : stratégie stricte (skip/reopen) en place ; *reste possible* : résolution automatique (script/LLM, plus risqué).
  - **Décomposition** : une passe LLM dans `swarm-prompt.sh` ; *reste possible* : seconde passe LLM pour vérifier/ajuster les sous-tâches avant coordinateur.
- [x] **Couche mail** (type Overstory, en plus de Seeds) : script `swarm-mail.sh` (send / list / show) ; stockage `.swarm/mail/messages.jsonl`. Permet retours en cours de tâche (progress, blocked, help_request), handoffs agent → agent, événements riches, priorité sur les messages. Intégré au dashboard (derniers messages). Voir phase6-workflow.md §15.

**Livrable** : pipeline autonome + gate “tests verts” + runbook + moteur de workflow + auto-correction + **couche mail** (retours, handoffs, événements). Workflow détaillé dans [workflows/phase6-workflow.md](workflows/phase6-workflow.md).

---

## 4. Références

- **Overstory** : [github.com/jayminwest/overstory](https://github.com/jayminwest/overstory) — inspiration pour worktrees, mail, merge, rôles.
- **Mulch** : [github.com/jayminwest/mulch](https://github.com/jayminwest/mulch) — expertise structurée pour agents (record/query/prime), git-native, multi-agent safe.
- **Seeds** : [github.com/jayminwest/seeds](https://github.com/jayminwest/seeds) — tracker d’issues git-native pour workflows agents (CLI `sd`), remplace beads dans l’écosystème Overstory.
- **pi** : [pi.dev](https://pi.dev) — agent coding, support multi-LLM / OpenAI-compatible. Extension IDE : [pi-vs-claude-code](https://github.com/ax402/pi-vs-claude-code).
- **LiteLLM** : [docs.litellm.ai](https://docs.litellm.ai) — proxy et lib pour multi-providers.
- **Configuration détaillée** : voir [config-litelmm-tailscale-aider.md](config-litelmm-tailscale-aider.md) dans ce dépôt.

---

## 5. Risques et limites (à garder en tête)

- **Swarm** : taux d’erreur et coût peuvent augmenter avec le nombre d’agents ; bien découper les tâches et limiter le parallélisme au début.
- **Merge** : les conflits peuvent être fréquents ; prévoir une stratégie (merge par fichier, résolution manuelle, ou outil dédié).
- **Dépendance au proxy** : si le Mac Mini est éteint, prévoir un fallback (pi en direct vers OpenRouter ou une API) pour continuer à coder en solo.

---

## 6. Évolutions possibles (au-delà de la Phase 6)

Pour tendre vers une autonomie encore plus poussée (« outil ultime »), il faudrait en plus :

- **Résolution automatique des conflits (ou stratégie stricte)** *(lot 1 en place)* : en cas de conflit au merge, option **`--on-conflict skip`** (annuler le merge, logger, continuer les autres branches) ou **`--on-conflict reopen`** (idem + rouvrir l’issue Seeds pour re-dispatch). Stratégie recommandée : découper les tâches par fichier/module, merge ordonné. Voir [workflows/phase6-workflow.md §5](workflows/phase6-workflow.md) (gestion des conflits). *Reste possible* : résolution automatique (ex. `-X ours`/`theirs` ou outil de fusion).
- **Une couche qui crée les issues et déclenche le pipeline** *(lot 2 + langage naturel en place)* : **`swarm-coordinate.sh`** (liste de titres ou `--file`). **`swarm-prompt.sh`** : entrée en **langage naturel** — appelle le LLM (LITELLM_API_BASE ou OPENROUTER_API_KEY) pour décomposer la demande en sous-tâches, puis lance le coordinateur. Usage : `./scripts/swarm-prompt.sh "Ajoute l'auth et les logs"`. Voir [workflows/phase6-workflow.md §3 et §13](workflows/phase6-workflow.md).
- **Une politique claire de déploiement (staging/prod, alertes, coûts)** *(lot 3 en place)* : **Staging/prod** : script `swarm-deploy-staging.sh`. **Alertes** : `swarm-alert.sh` + `SWARM_ALERT_HOOK` et/ou `SWARM_SLACK_WEBHOOK_URL`. **Coûts** : `swarm-budget.sh` avec `SWARM_BUDGET_MAX`. Voir [workflows/phase6-workflow.md §9–11](workflows/phase6-workflow.md)

---

*Dernière mise à jour : Auto-correction (retry headless + tests, validation post-merge avec rollback, SWARM_MAX_RETRIES ; doc phase6 §6b, §14).*
