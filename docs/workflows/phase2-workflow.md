# Phase 2 — Workflow multi-agents manuels

Procédure reproductible pour faire travailler plusieurs Aider en parallèle dans des worktrees git distincts, puis merger les résultats à la main.

---

## Prérequis

- Dépôt **git** initialisé avec au moins un commit (`git init && git add . && git commit -m "initial"`).
- **Aider** installé et configuré (voir [config-litelmm-tailscale-aider.md](../config-litelmm-tailscale-aider.md)) : `OPENAI_API_BASE` pointant vers ton proxy sur le Mac Mini.
- **Phase 1** validée (proxy LiteLLM + Tailscale + Aider qui répond).
- **Optionnel** : [Seeds](https://github.com/jayminwest/seeds) (CLI `sd`) pour une issue par sous-tâche ; [Mulch](https://github.com/jayminwest/mulch) pour l’expertise cumulée (sections 8 et 9).

---

## 1. Découper la tâche en N sous-tâches

En tant que coordinateur, tu découpes l’objectif en **N sous-tâches** indépendantes (idéalement qui touchent à des fichiers différents pour limiter les conflits au merge).

Exemple pour un projet « ajouter auth + logs » :

| Agent   | Sous-tâche                          | Fichiers typiques   |
|---------|-------------------------------------|----------------------|
| agent-1 | Ajouter l’auth (login, token)       | `src/auth.ts`, `src/api/login.ts` |
| agent-2 | Ajouter les logs (middleware, format) | `src/logger.ts`, `src/middleware/logs.ts` |

Chaque sous-tâche est décrite dans un **TASK.md** (objectif, fichiers, contraintes, critère de fin). Tu peux t’inspirer de `templates/TASK.md` à la racine du projet ou de [examples/example-task-1.md](../examples/example-task-1.md).

---

## 2. Créer les worktrees (un par agent)

À la racine du projet :

```bash
# Créer 2 worktrees (agent-1, agent-2) dans .swarm/
./scripts/swarm-setup.sh 2
```

Cela crée :

- `.swarm/agent-1/` (branch `swarm/agent-1`)
- `.swarm/agent-2/` (branch `swarm/agent-2`)

Chaque répertoire contient une copie du code à ce moment-là et un fichier `TASK.md` (template par défaut).

---

## 3. Rédiger la tâche par agent

Édite manuellement le `TASK.md` de chaque agent pour y mettre la vraie sous-tâche :

```bash
# Exemple
vim .swarm/agent-1/TASK.md
vim .swarm/agent-2/TASK.md
```

Contenu type : objectif, liste de fichiers concernés, contraintes, critère de fin (voir `templates/TASK.md` ou [examples/example-task-1.md](../examples/example-task-1.md)).

---

## 4. Lancer N Aider en parallèle (un terminal par agent)

Ouvre **N terminaux** (ou onglets). Dans chaque terminal, lance Aider dans le worktree de l’agent, avec optionnellement un modèle différent par rôle :

```bash
# Terminal 1 — agent 1 (ex. Builder)
./scripts/swarm-run.sh agent-1 gpt-4o

# Terminal 2 — agent 2 (ex. autre Builder ou Scout)
./scripts/swarm-run.sh agent-2 claude-sonnet
```

Le script affiche le contenu de `TASK.md` ; tu peux le donner à Aider en début de session (« Voici ta tâche : … » ou en référençant le fichier).

Chaque instance Aider travaille dans son répertoire (son worktree) ; les modifications restent sur la branche `swarm/agent-X`.

---

## 5. Quand chaque agent a terminé

- Chaque agent commit ses changements dans son worktree (tu peux le faire toi-même ou demander à Aider) :

  ```bash
  cd .swarm/agent-1
  git add . && git commit -m "feat: auth (agent-1)"
  ```

- Revenir à la racine du dépôt et te placer sur la branche cible (souvent `main`) :

  ```bash
  cd /chemin/vers/ide-agentic
  git checkout main
  ```

---

## 6. Merge manuel des branches

Depuis la racine du projet, sur la branche cible (ex. `main`) :

```bash
# Merger tous les agents listés dans .swarm/
./scripts/swarm-merge.sh

# Ou merger uniquement certains agents
./scripts/swarm-merge.sh agent-1 agent-2
```

En cas de conflits : résoudre à la main (`git status`, éditer les fichiers, `git add . && git commit`), puis relancer le merge pour les branches restantes si besoin.

---

## 7. Nettoyer les worktrees (optionnel)

Une fois tout mergé et validé :

```bash
git worktree remove .swarm/agent-1
git worktree remove .swarm/agent-2
# ou supprimer le dossier .swarm/ après avoir retiré tous les worktrees
```

---

## 8. Optionnel — Seeds (suivi d’issues par sous-tâche)

Si [Seeds](https://github.com/jayminwest/seeds) (CLI `sd`) est installé, tu peux créer une issue par sous-tâche et la lier à chaque agent.

1. **Une fois** à la racine du projet (avant ou après `swarm-setup.sh`) : initialiser Seeds et créer les issues à partir des titres des sous-tâches :

   ```bash
   ./scripts/swarm-seeds-create.sh "Ajouter l'auth (login, token)" "Ajouter les logs (middleware)"
   ```

   Le script fait `sd init` si besoin, crée une issue par argument et affiche le mapping `agent-1` → `seeds-xxx`, `agent-2` → `seeds-yyy`.

2. **Dans chaque worktree**, avant ou en début de session Aider : marquer l’issue comme en cours et (optionnel) l’écrire dans `TASK.md` :

   ```bash
   cd .swarm/agent-1
   sd update seeds-xxx --status in_progress
   ```

3. **En fin de tâche**, dans le même worktree : fermer l’issue puis commit :

   ```bash
   sd close seeds-xxx --reason "Auth login + token implémentés"
   git add . && git commit -m "feat: auth (agent-1)"
   ```

4. Au merge des branches (`./scripts/swarm-merge.sh`), les fichiers `.seeds/` se fusionnent grâce à `merge=union` (défini par `sd init`).

---

## 9. Optionnel — Mulch (expertise cumulée)

Si [Mulch](https://github.com/jayminwest/mulch) est installé, l’expertise du projet (conventions, échecs, décisions) est disponible en début de session et peut être enrichie en fin de session.

1. **Une fois** à la racine du projet (idéalement avant `swarm-setup.sh`, puis commit pour que les worktrees en héritent) :

   ```bash
   mulch init
   mulch add api
   mulch add database
   # etc.
   git add .mulch && git commit -m "chore: mulch init"
   ```

2. **En lançant un agent** avec `./scripts/swarm-run.sh agent-1 gpt-4o`, le script affiche automatiquement la sortie de `mulch prime` (contexte expertise) si `.mulch/` existe dans le worktree. Tu peux copier-coller ce bloc dans Aider en début de session pour ancrer l’agent.

3. **En fin de session**, dans le worktree de l’agent, enregistrer les apprentissages (toi ou Aider via une commande shell) :

   ```bash
   cd .swarm/agent-1
   mulch record api --type convention "Toujours valider le token avant d'accéder aux routes protégées"
   mulch record database --type failure --description "..." --resolution "..."
   ```

4. Au merge des branches, les fichiers `.mulch/expertise/*.jsonl` se fusionnent (`merge=union`). Lors des prochaines sessions, `mulch prime` inclura ces enregistrements.

---

## Récap des commandes

| Étape              | Commande |
|--------------------|----------|
| Créer 2 agents     | `./scripts/swarm-setup.sh 2` |
| (Optionnel Seeds)  | `./scripts/swarm-seeds-create.sh "Titre 1" "Titre 2"` |
| Éditer les tâches  | `vim .swarm/agent-1/TASK.md` (et agent-2) |
| Lancer agent 1    | `./scripts/swarm-run.sh agent-1 gpt-4o` (terminal 1) |
| Lancer agent 2     | `./scripts/swarm-run.sh agent-2 claude-sonnet` (terminal 2) |
| (Optionnel Seeds)  | Dans worktree: `sd update <id> --status in_progress` puis en fin `sd close <id> --reason "..."` |
| (Optionnel Mulch)  | En fin de session: `mulch record <domaine> --type convention "..."` |
| Commit dans agent  | `cd .swarm/agent-X && git add . && git commit -m "..."` |
| Merger             | `git checkout main && ./scripts/swarm-merge.sh` |
| Nettoyer           | `git worktree remove .swarm/agent-X` |

---

## Bonnes pratiques

- **Découpage** : privilégier des sous-tâches sur des fichiers différents pour réduire les conflits au merge.
- **Modèles** : tu peux attribuer un modèle par rôle (ex. Scout = Kimi, Builder = MiniMax) en passant le nom du modèle dans `swarm-run.sh`.
- **TASK.md** : garder la spec courte et claire ; Aider s’en sert comme objectif pour la session.
- **Commit souvent** dans chaque worktree pour ne pas perdre le travail et faciliter le merge.
