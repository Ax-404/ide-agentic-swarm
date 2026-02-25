# Phase 6 — Autonomie (système plus qu’autonome)

Objectif : rendre le swarm **autonome** — exécution non interactive des agents, pipeline déclenchable (cron/webhook), merge conditionnel aux tests, et procédure de rollback.

---

## Prérequis

- Phases 2 à 5 en place (worktrees, Seeds, dispatch, logs, IDE tasks).
- **Aider** en mode scripting : `--message-file` et `--yes` (voir [Scripting Aider](https://aider.chat/docs/scripting.html)).
- **Seeds** (`sd`) pour les issues ; dépôt git avec `.seeds/` initialisé.

---

## 1. Agent non interactif (headless)

Un agent peut exécuter **une seule tâche** décrite dans `TASK.md` puis s’arrêter, sans chat interactif.

### Commande

```bash
./scripts/swarm-run-headless.sh <agent-name> [model]
```

Exemple :

```bash
./scripts/swarm-run-headless.sh agent-1 sonnet-4.6
```

### Comportement

1. Se place dans le worktree de l’agent (ex. `.swarm/agent-1/`).
2. Si **`.mulch/`** est présent, exécute **`mulch prime`** et envoie à Aider ce contexte + **TASK.md** ; sinon envoie uniquement **TASK.md**. Lance **Aider** avec `--message-file <fichier> --yes .` puis exit.
3. À la sortie d’Aider : ferme l’issue Seeds associée (`sd close`) si `.issue_id` est présent. **Succès (exit 0)** : ferme l'issue (`sd close`). **Échec (exit ≠ 0)** : réouvre l'issue (`sd update … --status open`) pour re-dispatch ; compteur `.retry_count` dans le worktree ; si `SWARM_MAX_RETRIES` est défini (ex. 3), au-delà l'issue n'est plus rouverte et alerte `retry_exhausted`.
4. Enregistre les événements dans `.swarm/logs/events.log` (`agent_start_headless`, `agent_finish_headless`, `agent_reopen_on_fail`, `agent_retry_exhausted`).

L’agent ne lit **que** `TASK.md` ; il n’y a pas de conversation. Idéal pour une boucle automatisée.

---

## 2. Pipeline autonome (dispatch → headless → merge)

Un seul script enchaîne : **dispatch** de N issues → **agents headless** (uniquement si l'issue est encore in_progress, pour éviter doubles exécutions sans nettoyage) → **merge** des branches dont l’issue est fermée (avec gate tests optionnel).

### Commande

```bash
./scripts/swarm-pipeline.sh [N] [--test "cmd"] [--validate "cmd"] [--rollback-on-validate-fail] [--parallel] [--on-conflict skip|reopen]
```

- **N** : nombre d’issues à dispatcher (défaut : 2).
- **--test "cmd"** : ne merger que les branches où `cmd` réussit dans le worktree (ex. `make test`, `pytest`) ; en cas d'échec, l'issue est réouverte pour re-dispatch.
- **--validate "cmd"** : après le merge, exécuter `cmd` sur la branche cible ; si échec et `--rollback-on-validate-fail`, rollback + alerte (voir §6b).
- **--rollback-on-validate-fail** : avec `--validate`, en cas d'échec de la validation, `swarm-rollback.sh` puis alerte `validate_failed`.
- **--parallel** : lancer les agents headless en parallèle (défaut : séquentiel).
- **SWARM_MODEL** : modèle utilisé par les agents (défaut : `sonnet-4.6`).
- **--on-conflict skip|reopen** : en cas de conflit au merge (voir §5).

### Exemples

```bash
# Dispatch 2 issues, run headless séquentiel, merge --completed
./scripts/swarm-pipeline.sh 2

# Avec gate : ne merger que si "make test" passe dans chaque worktree
./scripts/swarm-pipeline.sh 2 --test "make test"

# Agents en parallèle
SWARM_MODEL=claude-sonnet ./scripts/swarm-pipeline.sh 2 --parallel
```

**À lancer depuis la racine du dépôt**, de préférence sur la branche cible (ex. `main`). Le pipeline ne change pas de branche ; il merge dans la branche courante.

---

## 3. Coordinateur (création d’issues + pipeline) — lot 2

Une seule commande : **créer les issues Seeds** à partir d’une liste de tâches (titres), puis **lancer le pipeline** (dispatch → headless → merge). Idéal pour une entrée « haute niveau » sans passer par `swarm-seeds-create.sh` puis `swarm-pipeline.sh` à la main.

### Commande

```bash
./scripts/swarm-coordinate.sh "Titre 1" "Titre 2" "Titre 3" [--test "cmd"] [--on-conflict skip|reopen] [--parallel]
./scripts/swarm-coordinate.sh --file tasks.txt [options pipeline...]
```

- **Titres** : liste de titres de tâches (une issue Seeds par titre).
- **--file FICHIER** : une tâche par ligne (titre seul ; lignes vides et `#...` ignorées). Format possible : `titre` ou `titre|description` (la description peut être utilisée plus tard pour enrichir TASK.md).
- **Options pipeline** : `--test "cmd"`, `--on-conflict skip|reopen`, `--parallel` — transmises à `swarm-pipeline.sh`.

### Exemples

```bash
# Trois tâches puis pipeline avec gate tests
./scripts/swarm-coordinate.sh "Auth login" "Middleware logs" "Tests API" --test "make test"

# Depuis un fichier (une tâche par ligne)
echo -e "Refactor module A\nAjouter cache Redis\nDoc README" > tasks.txt
./scripts/swarm-coordinate.sh --file tasks.txt --on-conflict skip
```

Le coordinateur appelle `swarm-seeds-create.sh` pour créer les issues, puis `swarm-pipeline.sh N` avec N = nombre de tâches. Aucune intervention humaine entre la liste de tâches et la fin du pipeline (sauf conflits si non gérés par `--on-conflict`).

---

## 4. Déclenchement automatique (trigger)

### Cron

Exemple : lancer le pipeline toutes les heures (avec 2 agents et gate tests).

```bash
0 * * * * cd /chemin/vers/projet && ./scripts/swarm-pipeline.sh 2 --test "make test"
```

Ou seulement le dispatch + headless, sans merge automatique :

```bash
0 * * * * cd /chemin/vers/projet && ./scripts/swarm-dispatch.sh 2 && for d in .swarm/agent-*; do [ -f "$d/.issue_id" ] && ./scripts/swarm-run-headless.sh "$(basename "$d")"; done
```

### Webhook

Serveur HTTP minimal qui reçoit un POST et lance le pipeline (ex. Flask, FastAPI, ou un script CGI). Exemple conceptuel :

```bash
# À adapter : le serveur web appelle ce script
cd /chemin/vers/projet && ./scripts/swarm-pipeline.sh 2 --test "make test"
```

### File (queue)

Un worker (Redis, RabbitMQ, etc.) peut consommer des “jobs” et appeler `swarm-pipeline.sh` ou `swarm-dispatch.sh` + `swarm-run-headless.sh` pour chaque job.

---

## 5. Gestion des conflits au merge (stratégie stricte)

En cas de conflit lors d’un merge, le comportement par défaut est d’**arrêter** le script (résolution manuelle). Pour un pipeline plus autonome, on peut utiliser une **stratégie stricte** :

- **`--on-conflict skip`** : en cas de conflit sur une branche, annuler ce merge (`git merge --abort`), logger l’événement (`merge_conflict`), et **continuer** avec les autres branches. La branche en conflit reste non mergée.
- **`--on-conflict reopen`** : comme `skip`, et en plus **rouvrir l’issue Seeds** associée (`sd update … --status open`) pour que la tâche puisse être re-dispatchée plus tard (après résolution manuelle ou nouveau découpage).

**Recommandations pour limiter les conflits :**

- Découper les tâches pour qu’elles touchent des **fichiers ou zones distinctes** (idéalement une branche par fichier ou par module).
- Merger dans un **ordre fixe** (ex. agent-1 puis agent-2) en gardant le même ordre à chaque run.
- En pipeline autonome : `./scripts/swarm-pipeline.sh 2 --on-conflict skip` ou `--on-conflict reopen` selon que tu veuilles re-dispatcher ou non les tâches en conflit.

**Exemples :**

```bash
# Merge à la main : en cas de conflit, ignorer la branche et continuer
./scripts/swarm-merge.sh --completed --on-conflict skip

# Idem + rouvrir l’issue Seeds pour re-dispatch ultérieur
./scripts/swarm-merge.sh --completed --on-conflict reopen

# Pipeline autonome avec skip en cas de conflit
./scripts/swarm-pipeline.sh 2 --test "make test" --on-conflict skip
```

---

## 6. Merge avec gate « tests verts »

- **Dans le pipeline** : `./scripts/swarm-pipeline.sh 2 --test "make test"` exécute `make test` dans chaque worktree avant de merger cette branche ; en cas d’échec, la branche est ignorée (log `merge_skipped tests_failed`) et l'issue Seeds est **réouverte** pour re-dispatch (auto-correction).
- **À la main** :  
  `./scripts/swarm-merge.sh --completed --test "pytest"`  
  Ne merge que les branches dont l’issue Seeds est fermée **et** pour lesquelles `pytest` réussit dans le worktree ; si les tests échouent, l'issue est rouverte.

---

## 6b. Validation post-merge (boucle de validation)

Après le merge, vérifier la branche cible (ex. tests sur `main`) et, en cas d'échec, **rollback automatique** + alerte.

- **Script** : `./scripts/swarm-validate.sh "make test" [--rollback-on-fail]` — exécute la commande à la racine ; si échec, avec `--rollback-on-fail` exécute `swarm-rollback.sh` puis alerte `validate_failed`.
- **Dans le pipeline** : `./scripts/swarm-pipeline.sh 2 --test "make test" --validate "make test" --rollback-on-validate-fail` — après merge, validation sur la branche cible ; si échec, rollback du dernier merge et alerte.

---

## 7. Rollback

En cas de problème après un merge swarm (régression, bug en prod), annuler le merge avec un **revert** (nouveau commit qui annule les changements).

### Script

```bash
# Revert du dernier commit (souvent un merge)
./scripts/swarm-rollback.sh

# Revert d’un merge précis (hash)
./scripts/swarm-rollback.sh abc1234
```

Le script détecte si le commit est un merge et utilise `git revert -m 1` pour garder la branche principale.

### À la main

```bash
# Merge
git revert -m 1 <hash_du_merge>

# Commit simple
git revert <hash>
```

Pour **supprimer** le dernier commit sans garder l’historique (à utiliser avec précaution) :

```bash
git reset --hard HEAD~1
```

---

## 8. Runbook rapide

| Action | Commande |
|--------|----------|
| **Coordinateur** : créer issues + lancer pipeline | `./scripts/swarm-coordinate.sh "Titre 1" "Titre 2"` ou `--file tasks.txt` |
| **Un prompt (langage naturel)** : décomposition LLM → coordinateur | `./scripts/swarm-prompt.sh "Ajoute l'auth et les logs"` (LITELLM_API_BASE ou OPENROUTER_API_KEY requis) |
| Lancer un agent headless (une tâche puis stop) | `./scripts/swarm-run-headless.sh agent-1 sonnet-4.6` |
| Pipeline complet (dispatch + headless + merge) | `./scripts/swarm-pipeline.sh 2` |
| Pipeline avec gate tests | `./scripts/swarm-pipeline.sh 2 --test "make test"` |
| Pipeline + conflits ignorés (re-dispatch possible) | `./scripts/swarm-pipeline.sh 2 --on-conflict skip` ou `--on-conflict reopen` |
| Pipeline + validation post-merge (rollback si échec) | `./scripts/swarm-pipeline.sh 2 --validate "make test" --rollback-on-validate-fail` |
| Validation post-merge seule (rollback si échec) | `./scripts/swarm-validate.sh "make test" --rollback-on-fail` |
| Merge uniquement si tests verts | `./scripts/swarm-merge.sh --completed --test "make test"` |
| Merge en cas de conflit : ignorer / rouvrir issue | `./scripts/swarm-merge.sh --completed --on-conflict skip` ou `reopen` |
| Rollback du dernier merge | `./scripts/swarm-rollback.sh` |
| Pipeline sur staging puis merge vers main | `./scripts/swarm-deploy-staging.sh 2 [--test "make test"]` |
| **Workflow (fichier de définition)** | `./scripts/swarm-workflow.sh` ou `./scripts/swarm-workflow.sh workflows/staging.workflow` |
| Vérifier le budget (alerte si dépassement) | `SWARM_BUDGET_MAX=10 ./scripts/swarm-budget.sh` |
| **Mail** : derniers messages (retours, handoffs) | `./scripts/swarm-mail.sh show 10` ou `list --to coordinator` |
| Voir les logs | `./scripts/swarm-logs.sh` ou `./scripts/swarm-logs.sh --tail` |

---

## 9. Staging / prod (lot 3)

**Règle** : tout merge swarm va d’abord sur une branche **staging** ; après validation (tests, déploiement de préprod), on merge **staging → main** (prod).

- **Script** : `./scripts/swarm-deploy-staging.sh [args...]` — fait `git checkout staging`, lance `swarm-pipeline.sh` avec les mêmes arguments, puis affiche la commande pour merger vers `main`.
- **Variables** : `SWARM_STAGING_BRANCH=staging`, `SWARM_MAIN_BRANCH=main` (modifiables).
- **Exemple** : `./scripts/swarm-deploy-staging.sh 2 --test "make test" --on-conflict skip` puis, quand c’est bon : `git checkout main && git merge staging -m "Merge staging (swarm)"`.

---

## 10. Alertes (lot 3)

En cas d’échec (conflit au merge, tests en échec, pipeline en erreur, budget dépassé), les scripts peuvent **alerter** via un hook ou Slack.

- **`swarm-alert.sh <event_type> [message]`** : enregistre l’événement dans les logs et, si configuré, appelle le hook et/ou envoie à Slack.
- **Config** :
  - **`SWARM_ALERT_HOOK`** : chemin vers un script exécutable ; il est appelé avec `event_type` et `message` (ex. envoi email, PagerDuty).
  - **`SWARM_SLACK_WEBHOOK_URL`** : URL d’un Incoming Webhook Slack ; un message `[swarm] <event> — <message>` est envoyé.
- **Événements** : `merge_conflict`, `tests_failed`, `pipeline_failed`, `budget_exceeded`, `validate_failed`, `retry_exhausted`. Déclenchés automatiquement par `swarm-merge.sh`, `swarm-pipeline.sh`, `swarm-validate.sh`, `swarm-run-headless.sh`, `swarm-budget.sh`.

Exemple Slack : créer un Incoming Webhook dans l’app Slack, puis `export SWARM_SLACK_WEBHOOK_URL=https://hooks.slack.com/...`.

---

## 11. Budget et coûts (lot 3)

- **LiteLLM** : les coûts réels (tokens, €) viennent du proxy (en-tête `x-litellm-response-cost`, DB, [cost tracking](https://docs.litellm.ai/docs/proxy/cost_tracking)). Exporter périodiquement le montant (cron, script) vers un fichier ou une variable.
- **`swarm-budget.sh`** : compare la dépense courante à une limite et sort en erreur + alerte si dépassement.
  - **`SWARM_BUDGET_MAX`** : limite (ex. `10.00` en €).
  - **`SWARM_CURRENT_SPEND`** ou fichier **`.swarm/costs/current_spend`** : une ligne = montant courant. À alimenter depuis LiteLLM ou ta propre logique.
- **Politique** : définir `SWARM_BUDGET_MAX`, mettre à jour `current_spend` (cron qui interroge LiteLLM ou lit un rapport), et appeler `swarm-budget.sh` avant/après le pipeline ou dans un cron ; en cas de dépassement, l’alerte (hook/Slack) est envoyée.

---

## 12. Moteur de workflow

L’enchaînement des étapes peut être **défini dans un fichier** plutôt que codé en dur : un petit moteur lit une définition et appelle les scripts `swarm-*.sh` dans l’ordre.

### Commande

```bash
./scripts/swarm-workflow.sh [fichier_workflow]
```

Sans argument : utilise **`workflows/default.workflow`** (ou `workflows/autonomous.workflow` si default absent).

- **`--list`** (ou `-l`) : liste tous les workflows dans `workflows/*.workflow` (découverte automatique). Tout fichier `.workflow` ajouté apparaît ; supprimé, il disparaît.
- **Nom court** : `./scripts/swarm-workflow.sh staging` lance `workflows/staging.workflow`.

### Format du fichier

- **Une étape** = une ligne avec le **nom du script** (sans `swarm-` ni `.sh`), puis **un argument par ligne**, jusqu’à une ligne contenant exactement **`--`**.
- Lignes vides et **`# commentaire`** ignorées.
- Noms valides : `dispatch`, `pipeline`, `coordinate`, `merge`, `deploy-staging`, `seeds-create`, `clean`, `rollback`, `budget`, `prompt`, etc.

Exemple :

```
coordinate
Tâche 1
Tâche 2
--test
make test
--
```

= exécute `swarm-coordinate.sh "Tâche 1" "Tâche 2" --test "make test"`.

### Fichiers fournis (dossier `workflows/`)

| Fichier | Description |
|---------|-------------|
| `default.workflow` | Dispatch 2 + pipeline (tests + skip conflits). Pour issues déjà créées. |
| `autonomous.workflow` | Une étape : coordinate (2 tâches exemples + options). |
| `staging.workflow` | deploy-staging 2 (pipeline sur branche staging). |
| `prompt.workflow` | Entrée langage naturel : décomposition LLM puis coordinateur (voir §13). |

### Personnaliser

Copiez un fichier dans `workflows/`, modifiez les étapes ou les arguments. Il est **automatiquement** pris en compte (`--list`, lancement par nom court). Supprimez le fichier pour le retirer. Voir `workflows/README.md`.

---

## 13. Entrée en langage naturel (un prompt → sous-tâches → coordinateur)

Un **seul prompt** en langage naturel peut déclencher tout le flux : le script appelle le LLM (via le proxy LiteLLM) pour décomposer la demande en sous-tâches, puis lance le coordinateur avec ces titres.

### Commande

```bash
export LITELLM_API_BASE="http://macmini.ton-tailnet.ts.net:4000"   # ou OPENROUTER_API_KEY pour OpenRouter
./scripts/swarm-prompt.sh "Ajoute l'authentification et un middleware de logs" [--model sonnet-4.6] [--test "make test"] [--on-conflict skip]
```

Ou depuis l’entrée standard :

```bash
echo "Refactoriser le module API et ajouter des tests" | ./scripts/swarm-prompt.sh --stdin --test "pytest"
```

### Prérequis

- **LITELLM_API_BASE** (LiteLLM) ou **OPENROUTER_API_KEY** (OpenRouter) : voir [exemples-commandes.md](../exemples-commandes.md) section Prompt.
- **curl**, **jq** : pour l’appel API et le parse de la réponse.
- **Modèle** : `--model` ou variable `SWARM_PROMPT_MODEL` (défaut : `sonnet-4.6`).

### Comportement

1. Envoi au LLM d’une consigne demandant une liste de sous-tâches (titres seuls, un par ligne).
2. Parse de la réponse (une ligne = un titre d’issue Seeds).
3. Appel de **`swarm-coordinate.sh`** avec ces titres et les options passées (`--test`, `--on-conflict`, `--parallel`).

Vous pouvez aussi utiliser l’étape **`prompt`** dans un workflow (ex. `workflows/prompt.workflow`) : première ligne après `prompt` = la demande, puis options éventuelles jusqu’à `--`.

---

---

## 14. Auto-correction (résumé)

Le système applique désormais une **boucle d’auto-correction** partielle :

| Mécanisme | Comportement |
|-----------|--------------|
| **Retry agent** | Si un agent headless sort en exit ≠ 0, l’issue Seeds est **réouverte** ; au prochain pipeline elle sera re-dispatcher. Option `SWARM_MAX_RETRIES` pour plafonner les tentatives (au-delà : alerte `retry_exhausted`, issue non rouverte). |
| **Retry tests (merge)** | Si les tests échouent dans un worktree avant merge, la branche est ignorée et l’**issue est réouverte** pour re-dispatch. |
| **Validation en boucle** | Option `--validate "cmd"` + `--rollback-on-validate-fail` : après merge, exécution de `cmd` sur la branche cible ; si échec, **rollback automatique** du dernier merge + alerte `validate_failed`. |
| **Conflits** | Stratégie stricte : `--on-conflict skip` ou `reopen` (réouverture de l’issue pour re-dispatch). *Reste possible* : résolution automatique (LLM ou outil de fusion, plus risqué). |
| **Décomposition** | Une seule passe LLM dans `swarm-prompt.sh`. *Reste possible* : seconde passe LLM pour vérifier/ajuster les sous-tâches avant de lancer le coordinateur. |

---

## 15. Couche mail (en plus de Seeds)

En plus des issues Seeds (open / in_progress / closed), une **couche mail** type Overstory permet des retours en cours de tâche, des handoffs entre agents et des événements riches, sans fermer l’issue.

### Rôle

- **Retour en cours de tâche** : un agent peut envoyer un message (progression, blocage, demande d’aide) sans fermer l’issue.
- **Handoff agent → agent** : l’agent A envoie un message à l’agent B (ex. « Partie validation faite, voir src/validator.ts ») ; l’humain ou un script peut ensuite assigner la suite à B.
- **Événements** : « conflit dans fichier X », « tests OK mais besoin review », etc.
- **Priorité** : chaque message peut avoir une priorité (1–5) pour trier les demandes.

### Stockage

- Fichier **`.swarm/mail/messages.jsonl`** (une ligne JSON par message, append-only). Local au run (`.swarm/` est dans `.gitignore`).
- **Prérequis** : **jq** est recommandé pour `send` / `list` / `show` (JSON fiable). Sans jq, un fallback manuel est utilisé pour l’envoi ; en cas de corps avec guillemets ou retours à la ligne, installer jq évite les erreurs.

### Commandes

```bash
# Envoyer un message (depuis un worktree, --from est optionnel : détecté depuis le chemin)
./scripts/swarm-mail.sh send --from agent-1 --to coordinator --type help_request --body "Conflit dans src/auth.ts"
./scripts/swarm-mail.sh send --to agent-2 --type handoff --body "Validation faite, voir src/validator.ts" --issue-id seeds-xxx

# Lister les messages (filtres optionnels)
./scripts/swarm-mail.sh list [--to agent-2] [--from agent-1] [--type handoff] [--issue-id seeds-xxx] [--limit N]

# Affichage lisible (derniers N messages)
./scripts/swarm-mail.sh show [N]
```

**Types** : `progress` | `blocked` | `help_request` | `handoff` | `event`  
**Destinataires** : `coordinator` | `agent-X` | `broadcast` | `issue:seeds-xxx`

### Utilisation par un agent

Depuis le worktree d’un agent (ou depuis Aider en lançant une commande shell), exécuter depuis la racine du dépôt :

```bash
../../scripts/swarm-mail.sh send --to coordinator --type blocked --body "Je bloque sur le conflit dans src/auth.ts"
```

Sans `--from`, l’expéditeur est déduit du chemin courant (`.swarm/agent-X`).

### Dashboard

Le **tableau de bord** (`./scripts/swarm-dashboard.sh`) affiche les **5 derniers messages** mail en bas, pour voir en direct les retours et handoffs.

---

*Phase 6 — Autonomie : agent headless, pipeline, gate tests, conflits (--on-conflict), coordinateur, rollback. Lot 3 : staging/prod, alertes, budget. Moteur de workflow. Entrée langage naturel (swarm-prompt.sh). Auto-correction : retry, validation post-merge, réouverture des issues. Couche mail : retours en cours de tâche, handoffs, événements.*
