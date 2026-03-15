# Design : UI toujours au-dessus des foregrounds

**Date :** 2026-03-15
**Projet :** visual-builder (Godot 4.6.1)

## Contexte

Dans `SequenceVisualEditor`, les foreground wrappers ont `z_index = fg.z_order` (plage utilisateur : -100 à 100). `_overlay_container` (overlays de jeu/preview : choix de dialogue, titres, variables) et `_fx_container` (effets visuels) sont des nœuds siblings du `_canvas` avec `z_index = 0` par défaut.

**Problème :** un foreground avec `z_order > 0` a un z_index effectif positif (car `z_as_relative = true` par défaut, et tous les parents ont z_index = 0), ce qui le rend au-dessus de `_overlay_container` (z_index 0). L'UI de jeu/preview n'est donc pas garantie d'être visible.

Hiérarchie concernée dans `SequenceVisualEditor` :
```
SequenceVisualEditor (Control)
  ├─ _letterbox_bg          (z_index = 0, toujours derrière tout — intentionnel)
  ├─ _canvas                (z_index = 0, DOIT rester à 0 — voir Contraintes)
  │   └─ _fg_container
  │       └─ wrapper        (z_index = fg.z_order, plage -100..100)
  ├─ _fx_container          (z_index = 0 actuellement — BUG)
  └─ _overlay_container     (z_index = 0 actuellement — BUG)
```

## Ordre de rendu cible

```
z_index effectif
  -100 à 100   → foreground wrappers (fg.z_order, contrôlé par l'utilisateur)
       101      → _fx_container  (effets visuels : au-dessus des FG)
      4096      → _overlay_container  (UI jeu/preview : priorité absolue)
```

## Solution

### Constantes à ajouter dans `sequence_visual_editor.gd`

```gdscript
const FX_Z := 101
    # Un cran au-dessus du max fg.z_order (100) — effets visuels sur le contenu
const UI_OVERLAY_Z := 4096
    # Valeur élevée garantissant la visibilité de l'UI sur tout le contenu
    # (le vrai max Godot 4 est 524287 ; 4096 est suffisant et lisible)
```

### Changements de code

Dans `_setup_canvas()` (ou la fonction équivalente qui crée `_fx_container` et `_overlay_container`), immédiatement après l'instanciation des nœuds :

```gdscript
_fx_container.z_index = FX_Z
_overlay_container.z_index = UI_OVERLAY_Z
```

Aucun autre fichier n'est impacté. Si ces nœuds sont définis dans un `.tscn`, la valeur en code prend le dessus sur la valeur sérialisée — c'est intentionnel.

## Contraintes respectées et hypothèses

- La plage utilisateur de `fg.z_order` (-100 à 100) reste inchangée.
- Le SpinBox dans `foreground_properties_panel.gd` (range -100 à 100) reste inchangé.
- **`_canvas.z_index` doit rester à 0.** Tout le schéma de z_index repose sur le fait que les parents des wrappers (`_canvas`, `_fg_container`) ont `z_index = 0`. Si `_canvas.z_index` change, les z_index effectifs des foregrounds changent en conséquence.
- **`_letterbox_bg` est intentionnellement non modifié** : il est en début d'arbre avec z_index = 0, donc toujours derrière le contenu.
- `_fx_container` se retrouve entre les foregrounds et l'overlay UI : les effets s'appliquent sur le contenu, pas sur l'interface.

## Tests

Dans le fichier de test de `SequenceVisualEditor` :

```gdscript
# Valeurs exactes (détectent les régressions sur les constantes)
assert_eq(_visual_editor._fx_container.z_index, SequenceVisualEditor.FX_Z)
assert_eq(_visual_editor._overlay_container.z_index, SequenceVisualEditor.UI_OVERLAY_Z)
assert_eq(SequenceVisualEditor.FX_Z, 101)
assert_eq(SequenceVisualEditor.UI_OVERLAY_Z, 4096)

# Invariants relationnels (détectent les erreurs d'ordre)
assert_gt(_visual_editor._fx_container.z_index, 100)           # FX > max fg.z_order
assert_gt(_visual_editor._overlay_container.z_index, 100)      # overlay > max fg.z_order
assert_lt(_visual_editor._fx_container.z_index,
          _visual_editor._overlay_container.z_index)             # FX < overlay UI
assert_eq(_visual_editor._canvas.z_index, 0)                    # hypothèse structurelle
```
