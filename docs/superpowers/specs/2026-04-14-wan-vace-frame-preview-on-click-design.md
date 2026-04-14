# WAN VACE — Prévisualisation des frames au clic

## Goal

Ouvrir le popup plein écran `_show_preview_fn` au clic simple sur n'importe quelle miniature de la grille de résultats.

## Architecture

Modification d'une seule fonction dans `plugins/ai_studio/ai_studio_wan_vace_tab.gd` : `_add_result_cell`.

Le handler `gui_input` du `TextureRect` de chaque cellule appelle déjà `_select_frame(image, index)`. On y ajoute un appel à `_show_preview_fn.call(tex_rect.texture, "Frame %d" % (index + 1))` dans la même branche conditionnelle.

## Comportement

- **Clic sur miniature** → sélectionne la frame (panel `_selected_cell_vbox` mis à jour) + ouvre le popup plein écran.
- **Clic sur `_selected_preview`** (200×200) → ouvre aussi le popup (comportement inchangé).
- Le panel de sauvegarde (renommage + bouton "Sauvegarder") reste intact.

## Fichiers modifiés

- `plugins/ai_studio/ai_studio_wan_vace_tab.gd` — fonction `_add_result_cell` (ligne ~625)

## Tests

- `specs/services/test_comfyui_client_wan_vace.gd` — pas de nouveaux tests nécessaires (logique UI pure, pas de logique métier testable avec GUT headless).
