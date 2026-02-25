# Phase 4 — Robustesse et monitoring

Watchdog, logs centralisés et dashboard minimal pour surveiller les agents et tracer les événements.

---

## Prérequis

- Phase 2/3 en place (worktrees, Seeds, scripts swarm-*).
- `swarm-run.sh` enregistre le PID du processus pi dans `.swarm/agent-X/.pid` au démarrage.

---

## 1. Logs centralisés

Tous les scripts swarm peuvent écrire dans **`.swarm/logs/events.log`** (une ligne par événement : date ISO, type, détails).

**Consulter les logs :**

```bash
# Dernières lignes (défaut: 50)
./scripts/swarm-logs.sh

# Dernières N lignes
./scripts/swarm-logs.sh --lines 100

# Suivre en temps réel
./scripts/swarm-logs.sh --tail
```

**Événements enregistrés :** `agent_start`, `dispatch`, `sling`, `merge`, `watch_dead`, `watch_relaunch` (quand le watchdog détecte un arrêt ou une relance).

**Écrire un événement à la main :**

```bash
./scripts/swarm-log.sh mon_events "détail"
```

---

## 2. Watchdog (surveillance des processus)

Le watchdog vérifie que les processus dont le PID est dans **`.swarm/agent-X/.pid`** sont encore actifs. Si un processus est mort, il log l’événement et optionnellement relance l’agent.

**Une seule vérification :**

```bash
./scripts/swarm-watch.sh --once
```

**Vérification en boucle (toutes les 30 s par défaut) :**

```bash
./scripts/swarm-watch.sh
# ou avec un intervalle personnalisé
./scripts/swarm-watch.sh --interval 15
```

**Avec relance automatique** si un agent est mort :

```bash
./scripts/swarm-watch.sh --relaunch --interval 30
```

**En arrière-plan :**

```bash
nohup ./scripts/swarm-watch.sh --interval 30 &
```

---

## 3. Dashboard (état des agents et des tâches)

**Une fois (instantané) :**

```bash
./scripts/swarm-dashboard.sh
```

Affiche un tableau : **Agent**, **Issue** (Seeds), **Statut issue** (open / in_progress / closed), **PID**, **Actif** (oui/non).  
Plus les dernières lignes du log.

**Rafraîchissement périodique (mode “watch”) :**

```bash
./scripts/swarm-dashboard.sh --watch --interval 5
```

---

## Récap des commandes Phase 4

| Étape           | Commande |
|-----------------|----------|
| Voir les logs   | `./scripts/swarm-logs.sh` ou `./scripts/swarm-logs.sh --tail` |
| Vérifier les PIDs | `./scripts/swarm-watch.sh --once` |
| Watchdog en continu | `./scripts/swarm-watch.sh [--interval N]` |
| Watchdog + relance | `./scripts/swarm-watch.sh --relaunch` |
| État du swarm   | `./scripts/swarm-dashboard.sh` |
| Dashboard en direct | `./scripts/swarm-dashboard.sh --watch` |

---

## Fichiers créés / utilisés

- **`.swarm/logs/events.log`** : log centralisé (créé automatiquement).
- **`.swarm/agent-X/.pid`** : PID du processus pi (créé par `swarm-run.sh`, supprimé par le watchdog si processus mort).
- **`.swarm/agent-X/.relaunch.log`** : sortie de la relance si `--relaunch` est utilisé.
