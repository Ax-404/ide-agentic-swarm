# Rôles du swarm

Ce document définit les **rôles** utilisés dans le swarm ide-agentic : mission, entrées/sorties, insertion dans le pipeline, et **mapping avec les composants actuels**. Les contrats (formats I/O) permettent à des outils externes (OpenClaw, Agent Zero, bridge) d’appeler ou consommer les étapes.

---

## Tableau récapitulatif

| Rôle | Mission | Entrée typique | Sortie typique |
|------|----------|----------------|----------------|
| **Planner** | Décomposer la demande en plan d’actions (tâches ordonnées, dépendances, critères de done). | Requête / objectif / PRD. | Liste de tâches (titres + spec courte si besoin), ordre, blocages éventuels. |
| **Scout** | Explorer le dépôt : stack, structure, points d’entrée, contraintes. | Chemin du repo + objectif. | Rapport de contexte (stack, layout, fichiers clés, recommandations). |
| **Builder** | Implémenter les tâches (code, modifications). | Plan (du Planner) + contexte (du Scout). | Patches / fichiers modifiés, résumé des changements, statut par tâche. |
| **Reviewer** | Revoir le code : qualité, tests, conventions, bugs, perf. | Diff / fichiers ou PR. | Rapport de review (bloquant / important / suggestion), approve / request changes. |
| **Documenter** | Mettre à jour ou créer la doc (README, API, ADR) en fonction du code. | Code actuel + changements + public cible. | Fichiers de doc mis à jour ou créés. |
| **Red-team** | Challenger : edge cases, sécurité, scénarios d’échec, incohérences. | Spec + code (ou livrable). | Liste de risques / scénarios adverses / incohérences + recommandations. |

---

## Détail par rôle

### Planner

- **Mission** : Transformer une demande (objectif, PRD, requête utilisateur) en plan d’actions exécutable : tâches ordonnées, dépendances éventuelles, critères de done.
- **Entrées** : Texte (requête, objectif, PRD) ; optionnel : chemin du repo pour adapter le plan au contexte.
- **Sorties** : Liste de tâches (titres + description courte optionnelle), ordre recommandé, blocages ou prérequis identifiés.
- **Dans le pipeline** : Première étape. Appelé avant Scout/Builder. Sa sortie alimente le coordinateur (issues Seeds) ou un fichier `tasks.txt`. Peut être appelé par un orchestrateur externe (OpenClaw, Agent Zero) ou par `swarm-prompt.sh`.

### Scout

- **Mission** : Explorer le dépôt (stack, structure, points d’entrée, contraintes) et produire un rapport de contexte pour les autres rôles.
- **Entrées** : Chemin du repo (ou racine du projet) + objectif ou question ciblée.
- **Sorties** : Rapport texte (stack, layout des dossiers, fichiers clés, conventions détectées, recommandations). Pas de modification du code.
- **Dans le pipeline** : Peut être exécuté avant ou en parallèle du Planner. Sortie consommée par Builder (contexte) ou par Planner (affiner le plan). En interactif, `swarm-run.sh agent-X sonnet-4.6 scout` affiche un rappel « lecture seule » pour Aider.

### Builder

- **Mission** : Implémenter les tâches : modifier le code, ajouter tests, respecter les contraintes. C’est le rôle « exécution » du plan.
- **Entrées** : Plan (liste de tâches / issues Seeds) + contexte (rapport Scout ou Mulch prime) ; chaque agent reçoit une issue + TASK.md.
- **Sorties** : Fichiers modifiés (commits dans le worktree), résumé des changements, statut (issue fermée via `sd close` ou rouverte).
- **Dans le pipeline** : Après Planner (et optionnellement Scout). Dispatch assigne N issues → N worktrees ; chaque agent Aider incarne un Builder. Merge agrège les branches.

### Reviewer

- **Mission** : Revoir le code (qualité, tests, conventions, bugs, perf) et produire un rapport (bloquant / important / suggestion) ou approve / request changes.
- **Entrées** : Diff (ou ensemble de fichiers / PR) ; optionnel : critères de review (conventions, checklist).
- **Sorties** : Rapport de review structuré (niveau par point : bloquant / important / suggestion) ; décision : approve ou request changes.
- **Dans le pipeline** : Après Builder, avant ou après merge. Aujourd’hui non automatisé dans le swarm : peut être incarné par un agent Aider dédié (worktree + TASK.md « review les changements de la branche X ») ou par un outil externe qui lit le diff et appelle un LLM.

### Documenter

- **Mission** : Mettre à jour ou créer la documentation (README, API, ADR) en fonction du code et des changements.
- **Entrées** : Code actuel (ou chemins ciblés) + résumé des changements + public cible (dév, utilisateur, API).
- **Sorties** : Fichiers de doc créés ou modifiés (Markdown, etc.).
- **Dans le pipeline** : Souvent après Builder (ou en parallèle sur une tâche dédiée). Peut être une issue Seeds « Mettre à jour README et doc API » traitée par un Builder ; pas de script dédié aujourd’hui.

### Red-team

- **Mission** : Challenger la spec et le code : edge cases, sécurité, scénarios d’échec, incohérences.
- **Entrées** : Spec (ou objectif) + code / livrable (fichiers, diff).
- **Sorties** : Liste de risques, scénarios adverses, incohérences, + recommandations.
- **Dans le pipeline** : Après Builder (ou après merge). Non automatisé : peut être une tâche dédiée (issue + TASK.md « Red-team le module auth ») ou un outil externe.

---

## Mapping : composants ide-agentic → rôles

| Rôle | Composant(s) actuel(s) | Commentaire |
|------|------------------------|-------------|
| **Planner** | `swarm-prompt.sh` (LLM décompose requête → titres) ; `swarm-coordinate.sh` (reçoit la liste et crée les issues). | Le « Planner » est le couple prompt LLM + coordinateur : entrée = requête, sortie = issues Seeds. Un orchestrateur externe peut remplacer `swarm-prompt.sh` et appeler directement `swarm-coordinate.sh --file tasks.txt`. |
| **Scout** | `swarm-run.sh … scout`, `swarm-run-headless.sh` (lit `.role`), `swarm-dispatch.sh` / `swarm-sling.sh` (écrivent `.role` si titre `[Scout]` ou arg `scout`). | Titre issue préfixé `[Scout]` ou 3ᵉ arg `scout` pour sling ; rappel lecture seule injecté en headless ou affiché en interactif. |
| **Builder** | `swarm-dispatch.sh`, `swarm-sling.sh`, `swarm-run.sh` (défaut), `swarm-run-headless.sh`, `swarm-pipeline.sh`, `swarm-merge.sh`. | Tout le flux dispatch → worktrees → Aider (TASK.md + .role) → sd close → merge. Chaque worktree = Builder, Scout, Reviewer, Documenter ou Red-team selon `.role`. |
| **Reviewer** | Même chaîne que Scout/Builder : `[Reviewer]` dans le titre ou 3ᵉ arg sling → `.role=reviewer` → rappel injecté (run/run-headless). | Revue code (qualité, tests, conventions) ; rapport ou corrections ciblées. |
| **Documenter** | Idem : `[Documenter]` → `.role=documenter` → rappel « doc seulement, pas de logique métier ». | Mise à jour ou création de doc (README, API, ADR). |
| **Red-team** | Idem : `[Red-team]` → `.role=red-team` → rappel « challenger edge cases, sécurité ». | Rapport de risques et recommandations. |

---

## Ordre dans le pipeline (idéal)

1. **Planner** : requête → liste de tâches (→ `swarm-coordinate.sh` ou équivalent).
2. **Scout** (optionnel) : repo + objectif → rapport ; rapport utilisé pour enrichir TASK.md ou Mulch.
3. **Builder** : N tâches → N agents (dispatch → headless ou run) → merge.
4. **Reviewer** (optionnel) : diff / PR → rapport de review ; peut déclencher des corrections (nouvelles tâches).
5. **Documenter** (optionnel) : tâche(s) dédiée(s) ou incluse(s) dans le plan.
6. **Red-team** (optionnel) : après merge ou livrable → rapport de risques.

---

## Contrats (formats I/O) pour outils externes

### Planner : entrée

- **Format** : Texte libre (requête, objectif, PRD) ou fichier.
- **Appel typique** :  
  - Soit `./scripts/swarm-prompt.sh "Objectif: ..."` (Planner = LLM interne).  
  - Soit l’orchestrateur externe produit lui-même la liste et appelle le coordinateur (contrat Planner sortie → coordinateur entrée).

### Convention rôles dans les titres et fichier `.role`

- **Titres d’issues** : Un titre peut être préfixé par l’un des rôles suivants (convention). Le préfixe est retiré pour le contenu de TASK.md, le rôle est écrit dans `.role`.
  - `[Scout]` — exploration, rapport, lecture seule. Ex. `[Scout] Explorer la structure du dépôt`.
  - `[Reviewer]` — revue de code (qualité, tests, conventions). Ex. `[Reviewer] Revoir le module auth`.
  - `[Documenter]` — mise à jour ou création de doc uniquement. Ex. `[Documenter] Mettre à jour README et API`.
  - `[Red-team]` — challenger (sécurité, edge cases). Ex. `[Red-team] Red-team le flux de login`.
  - `[Builder]` ou sans préfixe — implémentation (défaut).
- **Fichier `.role`** : Dans chaque worktree (`.swarm/agent-X/`), le script écrit un fichier `.role` contenant `scout`, `builder`, `reviewer`, `documenter` ou `red-team`. Rempli par :
  - **dispatch** : selon le préfixe du titre de l’issue Seeds ;
  - **sling** : selon le 3ᵉ argument (`scout`|`builder`|`reviewer`|`documenter`|`red-team`) ou le préfixe du titre.
- **run-headless** : lit `.role` et injecte en tête du message envoyé à Aider un rappel selon le rôle (Scout = lecture seule ; Reviewer = revue/corrections ciblées ; Documenter = doc seulement ; Red-team = challenger/rapport).
- **swarm-run.sh** (interactif) : utilise le 3ᵉ argument si fourni, sinon lit `.role` dans le worktree ; affiche le même rappel de rôle qu’en headless.
- **swarm-prompt.sh** : le prompt LLM demande d’utiliser les préfixes `[Scout]`, `[Reviewer]`, `[Documenter]`, `[Red-team]` ou `[Builder]`/aucun selon le type de tâche.

### Planner : sortie → coordinateur entrée

- **Format attendu par le coordinateur** :  
  - **Arguments** : `./scripts/swarm-coordinate.sh "Titre 1" "Titre 2" "Titre 3" [options]`  
  - **Fichier** : `tasks.txt` = une tâche par ligne ; ligne = `titre` ou `titre|description`. Commentaires `#` ignorés.  
  - **Options** : `--test "cmd"`, `--validate "cmd"`, `--rollback-on-validate-fail`, `--on-conflict skip|reopen`, `--parallel`.
- **Exemple tasks.txt** :
  ```
  # MVP auth
  Auth JWT
  Écran login
  API users
  Mettre à jour README
  ```
- **Contrat** : Tout outil qui produit un fichier ou une liste de titres (un par ligne) peut appeler `swarm-coordinate.sh --file tasks.txt [options]` depuis la racine du dépôt.

### Scout : entrée / sortie

- **Entrée** : Chemin racine du repo (variable d’environnement ou argument) + objectif (texte).
- **Sortie** : Rapport texte (stdout ou fichier). Pas de format imposé ; recommandation : sections (Stack, Structure, Fichiers clés, Recommandations). Un outil externe peut parser ce rapport pour alimenter le Planner ou les TASK.md.

### Builder : entrée (ce que reçoit chaque agent)

- **Format** : Fichier `TASK.md` dans le worktree de l’agent (généré par dispatch/sling/handoff) + optionnel `.issue_id` (Seeds) + optionnel `.role` (`scout` | `builder` | `reviewer` | `documenter` | `red-team`, écrit par dispatch/sling). Contenu TASK.md : titre, issue, description, section « En cas de blocage » (mail).  
- **Contrat** : Toute étape qui crée ou met à jour `.swarm/agent-X/TASK.md`, `.issue_id` et optionnellement `.role`, puis appelle `swarm-run.sh agent-X` ou `swarm-run-headless.sh agent-X`, incarne un Builder, Scout, Reviewer, Documenter ou Red-team selon `.role`. Le format TASK.md est décrit dans `templates/TASK.md` et généré par `swarm_task_md_content()` (voir `scripts/swarm-common.sh`).

### Builder : sortie

- **Format** : Fichiers modifiés dans le worktree ; issue Seeds passée en `closed` via `sd close <id> --reason "..."`. État observable via `sd list`, `.seeds/issues.jsonl`, ou dashboard.

### Reviewer / Documenter / Red-team

- Même contrat entrée que Builder/Scout : TASK.md + `.role` (rempli par dispatch/sling si préfixe `[Reviewer]` etc.). Le rappel de rôle est injecté par run-headless / affiché par run. La **description de l’issue** (reprise dans TASK.md) peut détailler la mission et la situation (voir exemple « System prompt dans TASK.md » ci-dessous).

---

## System prompt dans TASK.md

Le **rôle** (Scout, Builder, Reviewer, etc.) est déterminé par le titre de l'issue et écrit dans `.role` ; un rappel court est injecté par les scripts. Pour ancrer l'agent dans la **situation actuelle**, mets dans la **description de l'issue Seeds** un bloc repris dans TASK.md — il sert de **system prompt** pour la tâche. Le Planner (ou toi) remplit le titre (éventuellement préfixé) et la description ; dispatch/sling génèrent TASK.md à partir de l'issue.

**Exemple — Reviewer :**

```markdown
## Rôle et contexte pour cette tâche

Tu agis en **Reviewer** sur le module auth. Contexte : le Builder a implémenté JWT et l'écran login. Ta mission : revoir le code (qualité, tests, conventions), produire un rapport (bloquant / important / suggestion). Corrections ciblées uniquement si nécessaire.

## Objectif

Revoir `src/auth/*.ts` et tests : couverture edge cases, gestion d'erreurs, style du projet.

## Livrable

Rapport (fichier `REVIEW-auth.md` ou dans le chat). En fin : `sd close <issue-id> --reason "Review terminée."`
```

**Exemple — Scout :** (description d'issue) « Tu agis en **Scout** : exploration et rapport uniquement, sans modifier le code. Contexte : préparation évolution API. Explorer le dépôt (structure, `src/api/`), produire un rapport : stack, fichiers clés, recommandations. »

**Exemple — Builder :** (description d'issue) « Tu agis en **Builder**. Contexte : tâches Auth JWT et Écran login faites ; tu reçois « API users ». Implémenter CRUD utilisateurs dans `src/api/users.ts`, réutiliser l'auth. Critères : routes testées, pas de régression `npm test`. »

En résumé : **TASK.md est utile** pour le rôle dans la situation : mets dans la description de l'issue un bloc « Rôle et contexte » + objectif + livrable ; ce contenu sera le system prompt de l'agent.

---

## Résumé des points d’intégration

| Étape | Script / artefact | Contrat entrée | Contrat sortie |
|-------|-------------------|----------------|----------------|
| Planner (interne) | `swarm-prompt.sh` | Requête (arg ou stdin) | Liste titres → `swarm-coordinate.sh` |
| Planner (externe) | — | — | Fichier `tasks.txt` ou liste d’args |
| Coordinateur | `swarm-coordinate.sh` | `--file tasks.txt` ou "T1" "T2" … + options | Issues Seeds + lancement pipeline |
| Scout | `swarm-run.sh … scout` | TASK.md (manuel) + rappel rôle | Rapport (sortie Aider / copier-coller) |
| Builder | `swarm-dispatch.sh` + `swarm-run-headless.sh` (ou `swarm-run.sh`) | Issues open + TASK.md par worktree | Commits, issues closed, branches à merger |
| Merge | `swarm-merge.sh` | Branches swarm/* | Branche cible mise à jour |
| État | `sd list`, `.seeds/issues.jsonl`, `swarm-dashboard.sh`, `swarm-mail.sh show` | — | État des issues, agents, messages |

Un **bridge** (OpenClaw, Agent Zero, etc.) peut donc :  
- **Appeler** : `swarm-coordinate.sh --file tasks.txt` (après avoir produit `tasks.txt`) ;  
- **Consommer** : `sd list --status open`, `sd list --status closed`, ou lire `.seeds/issues.jsonl` et `swarm-mail.sh show` pour savoir où en est l’exécution.
