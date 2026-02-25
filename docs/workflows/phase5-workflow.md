# Phase 5 — Évolution (IDE, autres clients, coûts)

Intégration dans l’IDE, utilisation d’autres clients que pi avec le même proxy, et suivi des coûts / tokens.

---

## 1. Utiliser le proxy depuis Cursor ou VS Code

Le proxy LiteLLM expose une API **OpenAI-compatible**. Pour que Cursor (ou VS Code avec une extension type OpenAI) utilise ce proxy :

### Cursor

- **Settings** → recherche « API » ou « OpenAI ».
- Renseigner une **Custom API Base URL** (ou équivalent) : l’URL de ton proxy, par ex. `http://macmini.ton-tailnet.ts.net:4000` (via Tailscale) ou `http://localhost:4000` si le proxy tourne en local.
- Choisir un **modèle** correspondant à un `model_name` configuré côté proxy (ex. `gpt-4o`, `claude-sonnet`).
- La clé API : selon ta config LiteLLM (clé factice si le proxy n’exige pas d’auth, ou clé virtuelle du proxy).

Ainsi, les appels du Chat Cursor partent vers ton Mac Mini (LiteLLM) au lieu d’OpenAI/Anthropic direct.

### VS Code (extensions type “OpenAI”, “Chat”, etc.)

- Même principe : **Base URL** = URL du proxy LiteLLM, **API Key** selon la config du proxy.
- Les extensions qui acceptent une « OpenAI-compatible endpoint » fonctionnent avec le même réglage.

### Lancer les commandes swarm depuis l’IDE

Tu peux exécuter les scripts swarm sans quitter l’éditeur :

- **VS Code / Cursor** : **Terminal** → onglet intégré, puis lancer par ex. `./scripts/swarm-dispatch.sh 2`, `./scripts/swarm-dashboard.sh --watch`, etc.
- **Tâches** : des tâches sont définies dans `.vscode/tasks.json` (Dispatch, Dashboard, Logs, Watchdog, etc.) ; **Terminal → Run Task** (ou raccourci) pour les lancer.

Le répertoire de travail du terminal doit être la **racine du projet** (où se trouvent `scripts/` et `.swarm/`).

---

## 2. Autres clients que pi (API OpenAI-compatible)

Tout client qui peut envoyer des requêtes **Chat Completions** vers une URL personnalisée peut utiliser le proxy.

- **URL** : celle du proxy (ex. `http://<mac-mini-tailscale>:4000`).
- **Modèle** : un `model_name` défini dans la config LiteLLM du proxy.
- **En-têtes** : en général `Authorization: Bearer <clé>` si le proxy l’exige ; sinon une clé factice peut suffire.

### Exemple avec `curl`

```bash
curl -X POST "http://macmini.ton-tailnet.ts.net:4000/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-dummy" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### Autres exemples

- **CLI** : tout outil qui permet de définir l’URL du proxy (ex. `LITELLM_API_BASE` ou `OPENROUTER_API_KEY`) et un `model` : configurer l’URL du proxy et le nom de modèle.
- **Scripts (Python, Node, etc.)** : utiliser le SDK OpenAI en pointant `openai.api_base` (ou équivalent) vers l’URL du proxy ; le reste du code reste identique.

pi n’est qu’un client possible ; la logique d’orchestration (worktrees, Seeds, scripts swarm) reste utilisable avec d’autres clients tant qu’ils travaillent dans le même dépôt et peuvent lancer des commandes (terminal, scripts) pour dispatch, merge, etc.

---

## 3. Coûts et tokens

### Côté proxy LiteLLM

- **En-tête de réponse** : LiteLLM peut renvoyer le coût calculé dans l’en-tête `x-litellm-response-cost`.
- **Base de données** : en configurant une base (ex. PostgreSQL) pour le proxy, tu peux activer le **spend tracking** et interroger par utilisateur ou globalement (voir [LiteLLM Cost Tracking](https://docs.litellm.ai/docs/proxy/cost_tracking)).
- **Endpoints** : avec une DB configurée, des endpoints du type `/global/spend/report` (ou équivalent) permettent d’obtenir des rapports de coût par période.

### Script local `swarm-costs.sh`

Le script `./scripts/swarm-costs.sh` :

- Compte les événements **agent_start** dans `.swarm/logs/events.log` (nombre de sessions agents lancées).
- Affiche un rappel pour les coûts réels : configurer le proxy LiteLLM avec une base de données et/ou consulter les logs et en-têtes du proxy.

Les coûts réels (tokens, prix) dépendent du proxy et des modèles utilisés ; ils ne sont pas calculés dans les scripts swarm.

### Résumé

| Besoin              | Où le faire |
|---------------------|-------------|
| Coût par requête    | En-tête `x-litellm-response-cost` ou logs LiteLLM. |
| Coût global / user  | Configurer une DB pour le proxy + endpoints LiteLLM (spend tracking). |
| Nombre de sessions  | `./scripts/swarm-costs.sh` (à partir de `events.log`). |
