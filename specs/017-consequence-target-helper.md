# 017 — ConsequenceTargetHelper

## Contexte

Les fichiers `ending_editor.gd` et `condition_editor.gd` dupliquaient ~115 lignes de code identique pour la gestion des cibles de conséquences : constantes, variables d'état, et fonctions de peuplement des dropdowns.

## Solution

`ConsequenceTargetHelper` (RefCounted) centralise :
- Les constantes `CONSEQUENCE_TYPES`, `CONSEQUENCE_LABELS`, `REDIRECT_TYPES` (dérivées de `Consequence.VALID_TYPES` / `REDIRECT_TYPES`)
- L'état des cibles disponibles (`available_sequences`, `available_conditions`, `available_scenes`, `available_chapters`, `variable_names`)
- Les fonctions `set_available_targets()`, `get_targets_for_type()`, `populate_target_dropdown()`

Les deux éditeurs délèguent à une instance de `_target_helper`.

## Fichier

`src/ui/consequence_target_helper.gd`
