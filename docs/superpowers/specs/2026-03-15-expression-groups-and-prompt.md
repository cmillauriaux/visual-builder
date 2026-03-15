# Spec — Groupes d'expressions dans l'AI Studio & fix du prompt

**Date :** 2026-03-15
**Statut :** Validé

---

## Contexte

L'onglet "Expressions" de l'AI Studio (`src/ui/dialogs/ai_studio_dialog.gd`) affiche actuellement les 40 expressions par défaut dans un seul `HFlowContainer` avec un unique bouton "Tout cocher/Décocher tout".

Deux problèmes à corriger :

1. **UI** — la liste plate rend difficile la sélection rapide des expressions les plus courantes.
2. **Prompt** — `_build_prompt` dans `expression_queue_service.gd` retourne le nom brut de l'expression (ex. `"smile"`) sans contexte, ce qui donne de mauvais résultats de génération.

---

## Changement 1 — Groupement des expressions en deux sections

### Objectif

Diviser les 40 expressions en deux groupes visuels, chacun avec son propre bouton "Tout cocher/Décocher tout".

### Groupes

**Expressions élémentaires** (16 expressions) :
```
smile, sad, shy, grumpy, laughing out loud, angry, surprised, scared,
bored, speaking, happy, calm, crying, determined, exhausted, annoyed
```

**Expressions avancées** (24 expressions) :
```
worried, neutral, disgusted, confused, proud, embarrassed, idle, thinking,
listening, cheerful, confident, playful, curious, warm, friendly, joyful,
serene, enthusiastic, excited, hopeful, jealous, dreamy, mischievous,
relieved, suspicious, tender, desperate, nostalgic, seductive
```

### Structure UI

Remplacer la section "Expressions :" actuelle par :

```
[Label "Expressions élémentaires"]  [Button "Tout cocher"]
HFlowContainer — elementary checkboxes (16)

HSeparator

[Label "Expressions avancées"]      [Button "Tout cocher"]
HFlowContainer — advanced checkboxes (24)

HSeparator

[Label "Expressions personnalisées :"]   ← inchangé
VBoxContainer — custom expressions       ← inchangé
HBoxContainer — input + bouton Ajouter   ← inchangé
```

### Comportement des boutons "Tout cocher"

- Chaque bouton n'agit que sur les checkboxes de **son groupe**.
- Libellé dynamique : **"Décocher tout"** si toutes les cases du groupe sont cochées, sinon **"Tout cocher"**.
- La mise à jour du libellé se déclenche à chaque `toggled` d'une checkbox du groupe (même logique que l'actuel bouton global).

### Changements dans le code

**`ai_studio_dialog.gd`**

- Remplacer la constante `DEFAULT_EXPRESSIONS` par deux constantes :
  ```gdscript
  const ELEMENTARY_EXPRESSIONS := ["smile", "sad", ...]   # 16 items
  const ADVANCED_EXPRESSIONS := ["worried", "neutral", ...] # 24 items
  ```
- Remplacer `_expr_expression_checkboxes: Array` par deux tableaux :
  ```gdscript
  var _expr_elementary_checkboxes: Array = []
  var _expr_advanced_checkboxes: Array = []
  ```
- Ajouter deux boutons de sélection de groupe :
  ```gdscript
  var _expr_elementary_select_all_btn: Button
  var _expr_advanced_select_all_btn: Button
  ```
- `_get_selected_expressions()` itère sur `_expr_elementary_checkboxes + _expr_advanced_checkboxes + custom`.
- La fonction de mise à jour du libellé du bouton devient `_update_group_select_all_btn(btn, checkboxes)`, appelée lors de chaque toggle dans le groupe.

---

## Changement 2 — Fix du prompt de génération

### Fichier concerné

`src/services/expression_queue_service.gd`, fonction `_build_prompt` (ligne 101).

### Avant

```gdscript
static func _build_prompt(expression: String) -> String:
    return expression
```

### Après

```gdscript
static func _build_prompt(expression: String) -> String:
    return "The same character with a %s expression, keep the eyes color" % expression
```

### Impact

- Le prompt envoyé à ComfyUI pour chaque expression est désormais contextuel.
- Exemple : `"The same character with a smile expression, keep the eyes color"`.
- Aucun autre changement dans le pipeline de génération.

---

## Tests à mettre à jour / ajouter

**`specs/ui/dialogs/test_ai_studio_dialog.gd`**
- Vérifier que `ELEMENTARY_EXPRESSIONS` et `ADVANCED_EXPRESSIONS` sont disjoints et couvrent les 40 expressions.
- Vérifier que les deux boutons "Tout cocher" n'agissent que sur leur groupe.
- Vérifier que `_get_selected_expressions()` retourne les expressions des deux groupes.

**`specs/services/test_expression_queue_service.gd`**
- Vérifier que `_build_prompt("smile")` retourne `"The same character with a smile expression, keep the eyes color"`.

---

## Fichiers modifiés

| Fichier | Nature |
|---|---|
| `src/ui/dialogs/ai_studio_dialog.gd` | UI : split constantes + deux sections + deux boutons |
| `src/services/expression_queue_service.gd` | Fix : `_build_prompt` |
| `specs/ui/dialogs/test_ai_studio_dialog.gd` | Tests : nouveaux groupes |
| `specs/services/test_expression_queue_service.gd` | Tests : nouveau format prompt |
