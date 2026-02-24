# Exemple de sous-tâche pour agent-1

À copier dans `.swarm/agent-1/TASK.md` après `./scripts/swarm-setup.sh 2`.

## Objectif

Ajouter un module de validation des entrées : une fonction `validateInput(schema, data)` qui retourne `{ ok: true, data }` ou `{ ok: false, errors: [...] }`.

## Fichiers concernés

- Créer `src/validator.ts` (ou .js selon le projet)
- Ajouter les tests dans `src/validator.test.ts` ou `tests/validator.test.ts`

## Contraintes

- Ne pas modifier les autres fichiers du projet sauf pour exporter le module si nécessaire.
- Utiliser un schéma simple (ex. objet avec champs requis/optionnels).

## Critère de fin

- [ ] `validateInput` implémentée et exportée
- [ ] Au moins 2 tests (cas valide + cas invalide)
- [ ] Pas de régression sur le reste du projet
