# Pi coding agent — vérification pour le swarm

Ce document résume la vérification faite avec un clone temporaire de [pi-mono](https://github.com/badlogic/pi-mono) pour s’assurer que **pi** peut être utilisé à la place d’Aider dans le swarm.

**Clone temporaire :** `git clone https://github.com/badlogic/pi-mono.git .pi-mono-temp` (le dossier `.pi-mono-temp/` est dans `.gitignore`).

**Extension IDE (VS Code / Cursor) :** [pi-vs-claude-code](https://github.com/ax402/pi-vs-claude-code) — permet d’utiliser pi depuis l’éditeur.

---

## Résultat : pi peut être fonctionnel pour le swarm

### 1. Mode headless (équivalent de `swarm-run-headless.sh`)

- **Print mode** : `pi -p "prompt"` ou **stdin** : `echo "prompt" | pi` → envoie le message, affiche la réponse, puis **exit**. Pas de TUI.
- Quand stdin est connecté (pipe), le mode print est activé automatiquement.
- **Équivalent Aider** : au lieu de `aider --model "$MODEL" --message-file "$MESSAGE_FILE" --yes .`, on peut faire :
  ```bash
  cd "$AGENT_DIR"
  build_message | pi --model sonnet-4.6
  ```
  où `build_message` produit le rappel de rôle (optionnel) + le contenu de TASK.md.

- **Rappel de rôle (Scout, etc.)** : pi accepte `--append-system-prompt "Rôle: Scout (lecture seule)..."` ou on inclut ce bloc dans le message envoyé (stdin ou premier argument).

### 2. Mode interactif (équivalent de `swarm-run.sh`)

- Lancer pi dans le worktree : `cd .swarm/agent-1 && pi` ou `pi "Lis TASK.md et fais la tâche"`.
- Pi utilise le répertoire courant comme contexte ; `AGENTS.md` / `SYSTEM.md` dans le projet ou `~/.pi/agent/` sont chargés.

### 3. Modèle et API

- Pi gère **OpenRouter** (`OPENROUTER_API_KEY`), **Anthropic**, **OpenAI**, etc. (voir [docs/providers.md](https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent/docs) dans le repo).
- `--model <pattern>` pour choisir le modèle (ex. `pi --model sonnet-4.6`).
- Pas de variable `LITELLM_API_BASE` native ; pour un proxy LiteLLM il faudrait soit un provider personnalisé (pi `models.json` / extension), soit utiliser OpenRouter qui pointe vers le proxy.

### 4. Fichiers analysés dans pi-mono

- `packages/coding-agent/src/modes/print-mode.ts` : mode single-shot, `initialMessage` + `messages[]`, sortie texte ou JSON puis exit.
- `packages/coding-agent/src/main.ts` : stdin piped → `parsed.print = true`, contenu stdin ajouté à `parsed.messages`.
- `packages/coding-agent/README.md` : CLI Reference, `-p` / `--print`, `--append-system-prompt`, `--model`, exemples.

---

## Adaptation des scripts swarm pour utiliser pi

Pour remplacer Aider par pi, il faudrait notamment :

1. **swarm-run-headless.sh** : au lieu d’appeler `aider --model ... --message-file ... --yes .`, construire le message (rôle + TASK.md) et le passer à pi via stdin :  
   `build_message | pi --model "${MODEL}"` (en étant déjà `cd` dans le worktree).
2. **swarm-run.sh** : lancer `pi` (ou `pi "..."`) dans le worktree au lieu de `aider --model "$MODEL" .`.
3. **Prérequis** : installer pi (`npm install -g @mariozechner/pi-coding-agent`) et configurer les clés API (OpenRouter, Anthropic, etc.) comme indiqué dans la doc pi.
4. **Rôle** : utiliser `--append-system-prompt "Rôle: Scout..."` ou inclure le rappel dans le message stdin.

**Modification appliquée** : le swarm utilise désormais **pi** par défaut. Les scripts swarm-check.sh, swarm-run.sh, swarm-run-headless.sh, swarm-pipeline.sh, swarm-sling.sh et la doc ont été mis à jour en conséquence.
