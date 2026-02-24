# Tâche pour cet agent

Décris ici la sous-tâche que cet agent doit réaliser. Aider lira ce fichier (ou tu peux copier-coller le contenu dans le chat).

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












## exemple

# Tâche pour cet agent

<!-- Tu es un agent de développement. Ta mission est de réaliser une sous-tâche précise dans ce dépôt. Lis le contexte ci-dessous et exécute la tâche sans modifier le reste du projet sans nécessité.

## Objectif

Implémenter la validation des entrées dans `src/auth/validator.ts` : une fonction `validateEmail(email: string)` qui retourne un booléen (regex RFC 5322 simplifiée) et une fonction `validatePassword(pwd: string)` qui vérifie au moins 8 caractères, une majuscule, une minuscule et un chiffre.

## Fichiers concernés

- [ ] `src/auth/validator.ts` (créer ou compléter)
- [ ] `src/auth/validator.test.ts` (tests unitaires)

## Contraintes

- Ne pas modifier les autres modules (API, UI) sauf si une interface doit être mise à jour.
- Utiliser TypeScript strict ; pas de dépendance externe pour la validation (regex et logique native).
- Écrire les tests (Jest ou Vitest selon le projet).

## Critère de fin

- [ ] `validateEmail` et `validatePassword` implémentées et exportées.
- [ ] Tests unitaires passants ; pas de régression sur `npm test`.

## En cas de blocage ou pour passer la main

Si tu bloques (conflit, ambiguïté, besoin d'aide) ou si une autre partie doit être faite par un autre agent, envoie un message depuis la racine du dépôt :

- **Demande d'aide** : `..
 -->

