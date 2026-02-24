# Dépannage (TROUBLESHOOTING)

Commandes de diagnostic et solutions courantes. À lancer **depuis la racine du projet** (où se trouvent `scripts/` et `.seeds/`).

---

## Aider ne répond pas / erreur API

**Symptômes :** Aider tourne mais n’envoie pas de requêtes, ou erreur type « connection refused », « API key », « 401 ».

**À vérifier :**

1. **Proxy / URL**  
   `echo $OPENAI_API_BASE` doit pointer vers votre proxy LiteLLM ou API OpenAI-compatible (ex. `http://macmini.ton-tailnet.ts.net:4000`).  
   Voir [config-litelmm-tailscale-aider.md](config-litelmm-tailscale-aider.md).

2. **Réseau**  
   Si proxy sur une autre machine (ex. Mac Mini) : Tailscale ou VPN actif, test `curl "$OPENAI_API_BASE/v1/models"`.

3. **Clé API**  
   Si le proxy exige une clé : `export OPENAI_API_KEY=sk-...`. Aider lit ces variables d’environnement.

**Diagnostic :**
```bash
./scripts/swarm-check.sh
curl -sS "${OPENAI_API_BASE%/}/v1/models" | head -5
```

---

## sd introuvable / Seeds

**Symptômes :** `Erreur: 'sd' (Seeds) introuvable` ou `command not found: sd`.

**Solution :** Installer Seeds (CLI `sd`) :  
https://github.com/jayminwest/seeds  
(typiquement : clone du repo, `bun install`, `bun link` ou mettre le binaire dans le PATH).

**Vérifier :**
```bash
command -v sd && sd --version
./scripts/swarm-check.sh --require sd
```

---

## Aucune issue ouverte

**Symptômes :** `swarm-dispatch.sh` ne crée pas de worktrees, ou « 0 issues » alors que vous attendez des tâches.

**À vérifier :**

1. **Issues en statut `open`**  
   Seeds ne dispatch que les issues **open**. Les issues déjà `in_progress` ou fermées ne sont pas reprises.

2. **Lister les issues**  
```bash
sd list --status open
# ou lire le stock
cat .seeds/issues.jsonl | jq -r 'select(.status=="open") | "\(.id) \(.title)"'
```

3. **Créer des issues**  
```bash
./scripts/swarm-seeds-create.sh "Titre tâche 1" "Titre tâche 2"
```

**Diagnostic :**
```bash
./scripts/swarm-check.sh --require seeds
sd list
```

---

## Conflit au merge

**Symptômes :** `swarm-merge.sh` ou le pipeline échoue avec conflits git.

**Comportement selon les options :**

- **Pipeline** : utiliser `--on-conflict skip` (ignorer la branche) ou `--on-conflict reopen` (ignorer + rouvrir l’issue Seeds).
- **Merge manuel** : résoudre les conflits dans les fichiers indiqués, puis `git add` et `git commit`, et refaire le merge si besoin.

**Rollback du dernier merge (branche principale) :**
```bash
./scripts/swarm-rollback.sh
```

**Diagnostic :**
```bash
git status
git diff --name-only
```

---

## Mail vide / pas de messages

**Symptômes :** `swarm-mail.sh list` ou `show` n’affiche rien.

**Causes possibles :**

1. **Aucun message envoyé**  
   Les messages sont ajoutés quand un agent exécute `swarm-mail.sh send ...` (depuis un worktree ou via une commande).

2. **Filtres**  
   `list --to coordinator` ne montre que les messages pour `coordinator` (ou `broadcast`). Essayer sans filtre ou `--to broadcast`.

3. **Fichier absent**  
   Le stock est dans `.swarm/mail/messages.jsonl`. S’il n’existe pas, aucun message n’a encore été enregistré.

**Diagnostic :**
```bash
./scripts/swarm-mail.sh show 20
ls -la .swarm/mail/
```

---

## jq manquant

**Symptômes :** Erreur « jq introuvable » ou scripts qui échouent en parsing JSON.

**Solution :** Installer jq (ex. `brew install jq`). Requis pour `swarm-prompt.sh`, recommandé pour `swarm-mail.sh` (send/list/show) et la lecture des JSONL (Seeds, merge).

**Vérifier :**
```bash
./scripts/swarm-check.sh --require jq
```

---

## Worktree / agent introuvable

**Symptômes :** `swarm-run.sh agent-1` ou `swarm-run-headless.sh agent-1` : « Erreur: .swarm/agent-1 introuvable ».

**Cause :** Le worktree n’a pas été créé. Soit vous utilisez Seeds : lancer d’abord `swarm-dispatch.sh N` (ou `swarm-setup.sh N` sans Seeds) pour créer les répertoires `.swarm/agent-1`, etc.

**Diagnostic :**
```bash
ls -la .swarm/
./scripts/swarm-dispatch.sh 2   # crée worktrees si issues open
```

---

## Récap des commandes de diagnostic

| Problème | Commande utile |
|----------|----------------|
| État des prérequis | `./scripts/swarm-check.sh` |
| Issues Seeds (open) | `sd list --status open` |
| Derniers messages mail | `./scripts/swarm-mail.sh show 10` |
| État des agents / PIDs | `./scripts/swarm-dashboard.sh` |
| Logs événements | `./scripts/swarm-logs.sh --tail` |
| Rollback dernier merge | `./scripts/swarm-rollback.sh` |
