# Phase 3 — Workflow orchestration (Seeds + worktrees + merge)

Procédure pour faire tourner le swarm piloté par [Seeds](https://github.com/jayminwest/seeds) : dispatch d’issues vers des worktrees, un agent par tâche, merge des branches dont l’issue est fermée.

---

## Prérequis

- Tout ce qui est nécessaire pour la [Phase 2](phase2-workflow.md) (git, Aider, proxy).
- **Seeds** installé (CLI `sd`), dépôt initialisé (`sd init`) et `.seeds/` versionné (merge=union).
- Optionnel : **Mulch** (déjà utilisé dans `swarm-run.sh` via `mulch prime`), **jq** pour le parsing JSON.

---

## 1. Créer des issues (backlog)

À la racine du projet :

```bash
sd create --title "Implémenter l'auth login" --type task --priority 2
sd create --title "Ajouter middleware de logs" --type task --priority 2
# ou en lot :
./scripts/swarm-seeds-create.sh "Titre 1" "Titre 2"
```

---

## 2. Dispatcher les tâches (créer worktrees + assigner issues)

Un script crée un worktree par issue ouverte et assigne l’issue à cet agent :

```bash
# Dispatcher jusqu'à 2 issues (prêtes / ouvertes) vers agent-1, agent-2
./scripts/swarm-dispatch.sh 2
```

Cela :

- Lit les issues ouvertes (`.seeds/issues.jsonl` ou `sd list --status open`),
- Crée les worktrees `agent-1`, `agent-2`, … si besoin,
- Remplit `TASK.md` et `.issue_id` dans chaque worktree,
- Passe chaque issue en `in_progress` (`sd update <id> --status in_progress`),
- Affiche les commandes à lancer dans chaque terminal.

Tu lances ensuite un terminal par agent :

```bash
./scripts/swarm-run.sh agent-1 sonnet-4.6
./scripts/swarm-run.sh agent-2 claude-sonnet
```

---

## 3. Sling une seule issue (un agent pour une tâche)

Pour lancer un seul agent sur une issue donnée (création worktree + claim + Aider) :

```bash
./scripts/swarm-sling.sh seeds-a1b2 sonnet-4.6
```

Le script crée un worktree dédié (ex. `agent-seedsa1b2`), remplit `TASK.md` et `.issue_id`, met l’issue en `in_progress`, puis lance `swarm-run.sh` (donc Aider avec `mulch prime` si présent).

---

## 4. Travail des agents et clôture

Dans chaque worktree, l’agent (ou toi) travaille puis :

- Clôture l’issue : `sd close <issue-id> --reason "Résumé de ce qui a été fait"`
- Commit : `git add . && git commit -m "feat: ..."`

Optionnel : en fin de session, enregistrer l’expertise avec **Mulch** :  
`mulch record <domaine> --type convention "..."`

---

## 5. Merger les branches terminées

Depuis la racine, sur la branche cible (ex. `main`) :

```bash
# Ne merger que les branches dont l’issue Seeds est fermée (Phase 3)
./scripts/swarm-merge.sh --completed

# Ou merger toutes les branches présentes dans .swarm/ (comportement classique)
./scripts/swarm-merge.sh

# Ou merger des agents précis
./scripts/swarm-merge.sh agent-1 agent-2
```

`--completed` lit `.issue_id` dans chaque worktree et ne garde que les agents dont l’issue a `status: closed` dans `.seeds/issues.jsonl`.

---

## 6. Nettoyer les worktrees

Après merge, supprimer les worktrees :

```bash
# Tout supprimer dans .swarm/
./scripts/swarm-clean.sh --force

# Ou seulement les branches déjà mergées
./scripts/swarm-clean.sh --merged-only --force
```

---

## 7. Rôles (optionnel)

Lors du lancement d’un agent, tu peux préciser un rôle (rappel dans le contexte, pas d’application mécanique) :

```bash
./scripts/swarm-run.sh agent-1 sonnet-4.6 scout   # lecture seule
./scripts/swarm-run.sh agent-2 claude-sonnet builder
```

`scout` affiche une ligne rappelant « Rôle: Scout (lecture seule) » pour que tu puisses le donner à Aider.

---

## Récap des commandes Phase 3

| Étape           | Commande |
|-----------------|----------|
| Créer des issues | `sd create --title "..."` ou `./scripts/swarm-seeds-create.sh "..." "..."` |
| Dispatcher      | `./scripts/swarm-dispatch.sh 2` |
| Lancer un agent | `./scripts/swarm-run.sh agent-1 sonnet-4.6` (ou `swarm-sling.sh <issue-id>`) |
| Fermer l’issue  | Dans le worktree : `sd close <id> --reason "..."` |
| Merger (terminés) | `git checkout main && ./scripts/swarm-merge.sh --completed` |
| Nettoyer        | `./scripts/swarm-clean.sh [--merged-only] [--force]` |

---

## Différence Phase 2 / Phase 3

- **Phase 2** : tu crées les worktrees à la main (`swarm-setup.sh`), tu écris les `TASK.md` toi-même, merge manuel de toutes les branches.
- **Phase 3** : les tâches viennent de **Seeds** ; `swarm-dispatch.sh` crée les worktrees et assigne les issues ; `swarm-merge.sh --completed` ne merge que les branches dont l’issue est fermée ; `swarm-sling.sh` enchaîne une issue → un worktree → Aider ; `swarm-clean.sh` supprime les worktrees.
