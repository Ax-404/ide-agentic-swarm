# Utiliser ide-agentic sur un autre projet

Pour que le swarm (pi, Seeds, Mulch, worktrees) **agisse directement sur la construction d’un autre projet**, il faut que les scripts tournent **depuis la racine de ce projet**. Deux façons concrètes de faire.

---

## Principe

Les scripts (`swarm-*.sh`) prennent leur **répertoire de travail** comme étant le dépôt à piloter : ils utilisent `scripts/` comme sous-dossier de la racine du projet. Donc soit le swarm **vit à l’intérieur** du projet, soit on l’utilise comme **template** pour créer un nouveau projet qui contient déjà tout.

---

## Option 1 — Copier le swarm dans chaque nouveau projet (recommandé)

À chaque **nouveau projet** sur lequel tu veux utiliser le swarm :

1. **Copier** le swarm dans la racine du projet cible :
   - Soit **à la main** (voir la liste ci-dessous),
   - Soit avec le script d’installation (depuis la racine du projet, où se trouve `swarm-install.sh`) :
     ```bash
     ./swarm-install.sh /chemin/vers/mon-autre-projet
     ```
     Cela copie `scripts/`, `docs/`, `templates/`, `.vscode/tasks.json`, le script `swarm-install.sh` à la racine du projet cible (pour réinstaller ailleurs si besoin), et ajoute `.swarm/` au `.gitignore` du projet cible.

   Ou copier à la main : **`scripts/`**, **`docs/`**, **`templates/`**, **`.vscode/`**, et ajouter **`.swarm/`** au `.gitignore` du projet cible.

2. **À la racine de ce projet** (pas dans ide-agentic) :
   ```bash
   cd /chemin/vers/mon-autre-projet
   git init && git add . && git commit -m "initial"   # si pas déjà un dépôt
   sd init                                            # si tu utilises Seeds
   mulch init && mulch add api                         # si tu utilises Mulch
   ```

3. **Lancer le swarm depuis ce projet** :
   ```bash
   ./scripts/swarm-setup.sh 2
   ./scripts/swarm-dispatch.sh 2
   # ou en une commande (liste de tâches → issues Seeds → pipeline) :
   ./scripts/swarm-coordinate.sh "Tâche 1" "Tâche 2" --test "make test"
   # ou entrée en langage naturel (un prompt → LLM décompose en sous-tâches → coordinateur) :
   export LITELLM_API_BASE="http://ton-proxy:4000"   # ou OPENROUTER_API_KEY pour swarm-prompt.sh
   ./scripts/swarm-prompt.sh "Ajoute l'authentification et les logs" --test "make test"
   # etc.
   ```

Tout se passe **dans** `mon-autre-projet` : `.swarm/`, `.seeds/`, `.mulch/` y sont créés, les worktrees sont des branches de ce dépôt, et pi travaille sur le code de ce projet.

**En résumé** : tu mets une copie des scripts (et de la config/doc) dans chaque projet où tu veux le swarm ; ce dossier agit alors directement sur la construction de ce projet, car tu exécutes les commandes depuis sa racine.

---

## Option 2 — Utiliser ide-agentic comme template pour un nouveau projet

Si tu veux que **chaque nouveau projet naisse déjà avec le swarm** :

1. **Créer le nouveau dépôt** à partir de ide-agentic (clone ou “Use this template” sur GitHub).
2. **Renommer / adapter** : garder `scripts/`, `docs/`, `templates/`, `.vscode/`, `.gitignore`, et remplacer le contenu “ide-agentic” par le code de ton vrai projet (ou repartir d’un dépôt vide en gardant uniquement ces dossiers).
3. **Initialiser** dans ce nouveau dépôt : `git init` (ou déjà fait), `sd init`, `mulch init` si besoin.

Ensuite, tout le swarm (dispatch, run, merge, etc.) s’utilise comme dans ide-agentic, mais sur le code de ce nouveau projet.

---

## Ce qu’il ne faut pas faire

- **Lancer les scripts depuis ide-agentic en ciblant un autre répertoire** : les scripts ne prennent pas de “répertoire cible” en argument ; ils utilisent toujours le répertoire parent de `scripts/` comme racine du projet. Donc il faut soit les avoir **copiés dans** le projet cible (option 1), soit avoir **créé le projet à partir** du template (option 2).

---

## Récap

| Objectif | Action |
|----------|--------|
| Faire tourner le swarm sur **un projet existant** | Copier `scripts/`, `docs/`, `templates/`, `.vscode/`, et les règles `.gitignore` utiles dans la racine de ce projet, puis exécuter les commandes depuis cette racine. |
| **Créer un nouveau projet** déjà équipé du swarm | Partir du repo ide-agentic (template ou clone), garder les dossiers swarm et y mettre le code du nouveau projet. |

**Entrée par prompt (langage naturel)** : avec Seeds et LLM configuré (`LITELLM_API_BASE` ou `OPENROUTER_API_KEY`), tu peux lancer tout le flux depuis une seule phrase : `./scripts/swarm-prompt.sh "Ta demande"` — le LLM décompose en sous-tâches, le coordinateur crée les issues et lance le pipeline. Voir [workflows/phase6-workflow.md §13](workflows/phase6-workflow.md) (entrée en langage naturel).

Dans les deux cas, **le dossier qui contient `scripts/` est le projet sur lequel le swarm agit** : c’est là que sont créés `.swarm/`, `.seeds/`, etc., et que les agents modifient le code.
