# 018 — EffectRowBuilder

## Contexte

`ending_editor.gd` contenait `_create_effect_row()` (~50 lignes) avec du branchement contextuel (redirect vs choice). Les constantes `OPERATION_TYPES/LABELS` redondaient avec `VariableEffect.VALID_OPERATIONS`.

## Solution

- Ajout de `OPERATION_LABELS` dans `variable_effect.gd` à côté de `VALID_OPERATIONS`
- `EffectRowBuilder` (RefCounted, fonction statique `create_effect_row()`) prend l'effet, les noms de variables, et 4 callbacks (var_changed, op_changed, value_changed, delete)
- `ending_editor.gd` délègue au builder avec des lambdas contextuelles

## Fichier

`src/ui/effect_row_builder.gd`
