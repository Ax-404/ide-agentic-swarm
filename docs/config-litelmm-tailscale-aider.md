# Configuration LiteLLM + Mac Mini / MacBook M1 + Tailscale + Aider

Guide pour héberger le proxy LiteLLM sur un Mac Mini M2, y accéder depuis un MacBook M1 via Tailscale, et configurer Aider pour l’utiliser.

---

## 1. Prérequis

- **Mac Mini M2** : serveur proxy (allumé sur le réseau, idéalement sans veille)
- **MacBook M1** : machine de travail (Aider, terminal)
- **Tailscale** : installé et connecté sur les deux machines, même compte
- **Python 3** ou **Docker** sur le Mac Mini (pour LiteLLM)

---

## 2. Tailscale

### Sur les deux machines

- Installer Tailscale : [tailscale.com/download](https://tailscale.com/download)
- Se connecter avec le même compte (ou même tailnet)
- Noter le **nom MagicDNS** du Mac Mini : dans l’app Tailscale → nom de la machine (ex. `macmini`) ou `macmini.ton-tailnet.ts.net`

### Vérifier la connectivité

Sur le MacBook :

```bash
ping macmini.ton-tailnet.ts.net
```

(Remplace par le vrai nom Tailscale de ton Mac Mini.)

---

## 3. Mac Mini M2 — installation du proxy LiteLLM

### Option A : avec pip

```bash
pip install 'litellm[proxy]'
# ou
pipx install 'litellm[proxy]'
```

### Option B : avec Docker

```bash
docker pull ghcr.io/berriai/litellm:main-latest
```

### Fichier de configuration (Mac Mini)

Créer un fichier `config.yaml` (ex. dans `~/litellm/config.yaml`) :

```yaml
# Exemple : modèles via différents providers
# Remplace les clés par tes vraies clés (variables d’env recommandées)

model_list:
  # OpenAI
  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
      api_key: os.environ/OPENAI_API_KEY

  # Anthropic
  - model_name: claude-sonnet
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY

  # Open source / autres (exemples)
  # - model_name: kimi-k2
  #   litellm_params:
  #     model: moonshot/kimi-k2
  #     api_key: os.environ/MOONSHOT_API_KEY
  # - model_name: glm-5
  #   litellm_params:
  #     model: zai/glm-5
  #     api_key: os.environ/ZAI_API_KEY
  # - model_name: minimax-m2
  #   litellm_params:
  #     model: minimax/minimax-m2
  #     api_key: os.environ/MINIMAX_API_KEY
```

Les clés sont lues depuis les variables d’environnement (ex. `OPENAI_API_KEY`, etc.) — ne pas mettre les clés en clair dans le fichier.

### Lancer le proxy (Mac Mini)

Le proxy doit écouter sur toutes les interfaces pour être joignable via Tailscale (et LAN) :

```bash
litellm --config /chemin/vers/config.yaml --host 0.0.0.0 --port 4000
```

Avec Docker :

```bash
docker run -d \
  --name litellm \
  -v /chemin/vers/config.yaml:/app/config.yaml \
  -e OPENAI_API_KEY=xxx \
  -e ANTHROPIC_API_KEY=xxx \
  -p 4000:4000 \
  ghcr.io/berriai/litellm:main-latest \
  --config /app/config.yaml --host 0.0.0.0 --port 4000
```

(Adapter les chemins et les variables d’env selon ton setup.)

### Vérifier depuis le Mac Mini

```bash
curl http://127.0.0.1:4000/health
```

---

## 4. MacBook M1 — configurer Aider pour utiliser le proxy

### URL du proxy via Tailscale

Utilise l’**adresse Tailscale du Mac Mini** (nom MagicDNS ou IP 100.x.x.x) :

- Nom : `http://macmini.ton-tailnet.ts.net:4000`
- Ou IP : `http://100.x.x.x:4000`

### Variables d’environnement (recommandé)

Dans `~/.zshrc` ou `~/.bashrc` (sur le MacBook) :

```bash
# Proxy LiteLLM sur le Mac Mini (via Tailscale)
export OPENAI_API_BASE="http://macmini.ton-tailnet.ts.net:4000"

# Si le proxy attend une clé (optionnel, selon ta config LiteLLM)
# export OPENAI_API_KEY="ta-clé-proxy-ou-sk-xxx"
```

Puis :

```bash
source ~/.zshrc
```

### Lancer Aider

Aider utilisera automatiquement `OPENAI_API_BASE` ; le modèle sera celui configuré sur le proxy (ex. `gpt-4o`, `claude-sonnet`, ou les alias que tu as définis dans `config.yaml`) :

```bash
aider --model gpt-4o
# ou
aider --model claude-sonnet
```

Les appels partent du MacBook → Tailscale → Mac Mini (proxy) → API du provider (OpenAI, Anthropic, etc.).

---

## 5. Récap des flux

| Étape | Où | Quoi |
|-------|-----|------|
| 1 | MacBook | Aider envoie une requête vers `OPENAI_API_BASE` (URL Tailscale du Mac Mini) |
| 2 | Tailscale | Tunnel chiffré MacBook ↔ Mac Mini |
| 3 | Mac Mini | LiteLLM reçoit la requête, appelle l’API du provider (OpenAI, etc.) |
| 4 | Mac Mini | LiteLLM renvoie la réponse au MacBook |
| 5 | MacBook | Aider reçoit la réponse et continue |

---

## 6. Dépannage

- **Proxy injoignable depuis le MacBook**  
  - Vérifier que Tailscale est actif sur les deux machines.  
  - Tester : `curl http://macmini.ton-tailnet.ts.net:4000/health` depuis le MacBook.  
  - Vérifier que le proxy écoute bien sur `0.0.0.0:4000` (pas seulement `127.0.0.1`).

- **Pare-feu Mac Mini**  
  - Autoriser les connexions entrantes sur le port 4000 (ou désactiver temporairement le pare-feu pour tester).

- **Modèle inconnu**  
  - Vérifier que le `model_name` utilisé par Aider est bien déclaré dans `config.yaml` sur le Mac Mini.

- **Clés API**  
  - Les clés des providers (OpenAI, Anthropic, etc.) sont sur le **Mac Mini** (dans l’env ou le fichier de config). Le MacBook n’a besoin que de l’URL du proxy (et éventuellement d’une clé si tu configures l’auth sur le proxy).

---

## 7. Option : garder une config locale sans proxy

Si le Mac Mini est éteint ou inaccessible, tu peux basculer Aider vers l’API directe :

```bash
# Désactiver le proxy (pour utiliser OpenAI / autre directement)
unset OPENAI_API_BASE
# Puis configurer OPENAI_API_KEY etc. pour le provider direct
```

Ou utiliser un fichier `.env` ou un script qui active/désactive `OPENAI_API_BASE` selon que tu es sur le même réseau Tailscale que le Mac Mini ou non.
