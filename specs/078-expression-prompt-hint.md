# Champ prompt hint pour les expressions IA

## Résumé

Ajout d'un champ texte facultatif dans l'onglet Expressions du Studio IA permettant de guider le modèle de diffusion avec une description du personnage (ex : "cute girl", "grumpy grandpa"). Ce hint est injecté dans le prompt de chaque expression générée pour améliorer la cohérence des résultats avec le style du personnage.

## Comportement attendu

### Champ UI

- Un `LineEdit` (`_prompt_hint_input`) est ajouté dans l'onglet Expressions, positionné **sous le champ préfixe** (`_prefix_input`) et avant les sliders CFG/Steps.
- Label : "Prompt hint (facultatif)"
- Placeholder : `"Ex: cute girl, grumpy grandpa..."`
- Le champ est **éphémère** : vidé à chaque ouverture du dialog, non persisté entre les sessions.
- Le champ est désactivé pendant la génération (comme les autres inputs).
- Le champ n'influence **pas** l'état du bouton Générer : il reste facultatif (la génération fonctionne avec un hint vide).

### Intégration dans le prompt

- `ExpressionQueueService._build_prompt(expression, hint)` accepte un second paramètre optionnel `hint: String = ""`.
- `ExpressionQueueService.build_queue(expressions, prefix, hint)` accepte un troisième paramètre optionnel `hint: String = ""` et le transmet à `_build_prompt`.
- Quand le hint est **vide**, le prompt reste identique à l'existant :
  `"keep the same person, only change facial expression to {expression}, adjust face muscles only, ..."`
- Quand le hint est **renseigné**, il est injecté entre parenthèses après "person" :
  `"keep the same person ({hint}), only change facial expression to {expression}, adjust face muscles only, ..."`

## Critères d'acceptation

- [ ] Un champ `LineEdit` `_prompt_hint_input` existe dans `_expr_tab` avec le placeholder "Ex: cute girl, grumpy grandpa..."
- [ ] Le champ est positionné après `_prefix_input` et avant les sliders
- [ ] Le champ est désactivé pendant la génération (`_set_inputs_enabled(false)`)
- [ ] Le bouton Générer reste fonctionnel avec un hint vide
- [ ] `_build_prompt("smile", "")` retourne le prompt original sans parenthèses
- [ ] `_build_prompt("smile", "cute girl")` retourne `"keep the same person (cute girl), only change facial expression to smile, ..."`
- [ ] `build_queue(["smile"], "hero", "cute girl")` propage le hint dans le prompt de chaque item
- [ ] `build_queue(["smile"], "hero")` fonctionne sans hint (rétrocompatibilité)
- [ ] Tests unitaires couvrent `_build_prompt` avec et sans hint
- [ ] Tests UI vérifient l'existence et le type du champ `_prompt_hint_input`
