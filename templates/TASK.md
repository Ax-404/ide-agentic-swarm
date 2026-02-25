# Tâche pour cet agent

Décris ici la sous-tâche que cet agent doit réaliser. Aider lira ce fichier (ou tu peux copier-coller le contenu dans le chat). Quand les issues sont créées par le coordinateur / dispatch, le contenu ci-dessous est généré à partir du **titre** et de la **description** de l’issue Seeds. Pour donner un vrai « system prompt » à l’agent (rôle dans la situation actuelle), mets dans la **description de l’issue** un bloc « Rôle et contexte » — voir `docs/ROLES.md` section « System prompt dans TASK.md ».

---

## Rôle et contexte pour cette tâche

*(Optionnel. À remplir dans la description de l’issue Seeds ; repris ici par dispatch/sling.)*

Exemple pour un **Builder** : « Tu agis en Builder. Contexte : les tâches X et Y sont faites ; tu reçois la tâche Z. Rester cohérent avec les choix existants. »

Exemple pour un **Reviewer** : « Tu agis en Reviewer sur le module auth. Contexte : le Builder a livré JWT + écran login. Mission : revoir le code (qualité, tests, conventions), produire un rapport bloquant / important / suggestion. »

Exemple pour un **Scout** : « Tu agis en Scout : exploration et rapport uniquement, sans modifier le code. Contexte : préparation évolution API. Explorer le dépôt et produire un rapport : stack, fichiers clés, recommandations. »

---

## Objectif

[Exemple: Implémenter la fonction de validation des entrées dans `src/validator.ts`]

## Fichiers concernés

- [ ] `chemin/vers/fichier1`
- [ ] `chemin/vers/fichier2`

## Contraintes

- Ne pas modifier les autres parties du projet sans nécessité.
- Écrire des tests si pertinent.

## Critère de fin

- [ ] Code implémenté et cohérent avec le reste du projet
- [ ] Pas de régression sur les tests existants

## En cas de blocage ou pour passer la main

Si tu bloques (conflit, ambiguïté, besoin d’aide) ou si tu termines une partie et qu’un autre agent doit prendre la suite, envoie un message via le système mail (depuis la racine du dépôt) :

- **Demande d’aide** : `../../scripts/swarm-mail.sh send --to coordinator --type help_request --body "Description du blocage (fichier, erreur, question)"`
- **Passer la main à un autre agent** : `../../scripts/swarm-mail.sh send --to agent-X --type handoff --body "Ce qui a été fait et ce qu’il reste à faire" [--issue-id <id-issue-seeds>]`

Le coordinateur ou un humain verra ces messages (dashboard : `./scripts/swarm-dashboard.sh` ou `./scripts/swarm-mail.sh show`).
