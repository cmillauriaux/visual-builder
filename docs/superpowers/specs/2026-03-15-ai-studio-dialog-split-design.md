# Design : Découpage de `ai_studio_dialog.gd`

Date : 2026-03-15
Statut : Approuvé

## Contexte

`ai_studio_dialog.gd` fait 2116 lignes et contient trois onglets distincts (Décliner, Expressions, Upscale) mélangés avec le code partagé. Le fichier est difficile à naviguer et à maintenir.

## Objectif

Découper le fichier en 4 fichiers sans changer l'architecture ni les comportements. Pas de scenes `.tscn`, pas de signaux supplémentaires, pas de refactoring fonctionnel.

## Structure cible

```
src/ui/dialogs/
  ai_studio_dialog.gd          # Orchestrateur (~250 lignes)
  ai_studio_decliner_tab.gd    # Onglet Décliner (~380 lignes)
  ai_studio_expressions_tab.gd # Onglet Expressions (~560 lignes)
  ai_studio_upscale_tab.gd     # Onglet Upscale (~460 lignes)
```

## Interface des contrôleurs d'onglets

Chaque contrôleur `extends RefCounted` et expose l'interface commune suivante :

```gdscript
func initialize(
    parent_window: Window,      # pour add_child (sous-dialogues, ComfyUI client, ImageFileDialog)
    url_input: LineEdit,        # input partagé, lu au moment de la génération
    token_input: LineEdit,      # input partagé
    neg_input: TextEdit,        # input partagé (negative prompt)
    show_preview_fn: Callable,  # _show_image_preview(texture, filename)
    open_gallery_fn: Callable,  # _open_gallery_source_picker(on_selected)
    save_config_fn: Callable,   # _save_config()
    resolve_path_fn: Callable   # _resolve_unique_path(dir, filename) — static, dans orchestrateur
) -> void

func build_tab(tab_container: TabContainer) -> void
# Construit l'UI de l'onglet et l'ajoute au TabContainer.
# Pour l'onglet Expressions, appelle _load_custom_expressions() à la fin.

func setup(story_base_path: String, has_story: bool) -> void
# Appelé après chargement d'une story. Met à jour _story_base_path
# et active/désactive le bouton "Galerie...".

func update_generate_button() -> void
# Appelé quand l'URL ComfyUI change.

func cancel_generation() -> void
# Appelé au close du dialog pour annuler toute génération en cours.
```

### Méthodes spécifiques aux onglets Décliner et Expressions (pas Upscale)

```gdscript
func update_cfg_hint(has_negative: bool) -> void
# Appelé quand le negative prompt change.
# L'onglet Upscale n'implémente PAS cette méthode (il n'a pas de CFG hint).
```

### Cas particulier : Expressions tab

L'onglet Expressions reçoit une référence à l'`ImagePreviewPopup` via une méthode dédiée :

```gdscript
# Expressions uniquement
func set_image_preview(image_preview: Control) -> void
```

Les signaux `regenerate_requested` et `delete_requested` de `ImagePreviewPopup` sont connectés depuis le dialog principal directement aux méthodes de `_expr_tab`. Le tab `_on_delete_item` (renommé depuis `_on_expr_delete_item`) **inclut** l'appel à `_update_preview_button()` — méthode privée interne au tab, renommée depuis `_update_expr_preview_button()` — qui était dans le wrapper `_on_preview_delete` de l'orchestrateur. Les wrappers sont supprimés.

```gdscript
# Dans ai_studio_dialog.gd, après build_tab des expressions :
_image_preview.regenerate_requested.connect(_expr_tab._on_regenerate_item)
_image_preview.delete_requested.connect(_expr_tab._on_delete_item)
```

L'onglet Expressions accède directement aux champs internes de `ImagePreviewPopup` dans `_on_item_failed` (comme le fait actuellement le code monolithique) : `_image_preview._filename_label`, `_image_preview._regenerating`, `_image_preview._regenerate_btn`, `_image_preview._delete_btn`. C'est acceptable dans le cadre de ce découpage léger.

## Dialog principal (après refactoring)

Garde uniquement :

- Variables : `_tab_container`, `_url_input`, `_token_input`, `_negative_prompt_input`, `_image_preview`, `_story`, `_story_base_path`, `_category_service`
- Variables : `_decl_tab`, `_expr_tab`, `_upscale_tab` (les 3 contrôleurs `RefCounted`)
- `_ready()`, `setup()`, `_on_close()`
- `_build_ui()` : construit le header partagé + TabContainer + barre du bas + ImagePreviewPopup, puis `build_tab()` puis `set_image_preview()` sur `_expr_tab`, puis connecte les signaux du preview
- `_load_config()`, `_save_config()`
- `_update_all_generate_buttons()` : délègue `update_generate_button()` à chaque tab
- `_update_cfg_hints()` : lit `_negative_prompt_input.text`, délègue à `_decl_tab.update_cfg_hint()` et `_expr_tab.update_cfg_hint()` (pas `_upscale_tab`)
- `_show_image_preview()` (helper, passé comme `show_preview_fn`)
- `_open_gallery_source_picker()`, `_list_gallery_images()` (partagé, passé comme `open_gallery_fn`)
- `_resolve_unique_path()` (static, **reste dans l'orchestrateur**)
- `_compute_upscale_target()` (static, **reste dans l'orchestrateur** — appelée dans les tests via `AIStudioDialog._compute_upscale_target(...)`)
- `ELEMENTARY_EXPRESSIONS`, `ADVANCED_EXPRESSIONS` (constantes, **restent dans l'orchestrateur**)

## Migration des variables et fonctions

| Préfixe/nom actuel | Fichier cible | Nouveau nom |
|---|---|---|
| `_decl_*` vars et fonctions | `ai_studio_decliner_tab.gd` | sans préfixe `_decl` |
| `_expr_*` vars et fonctions | `ai_studio_expressions_tab.gd` | sans préfixe `_expr` |
| `_upscale_*` vars et fonctions | `ai_studio_upscale_tab.gd` | sans préfixe `_upscale` |
| `_on_preview_regenerate`, `_on_preview_delete` | supprimés | — |
| `ELEMENTARY_EXPRESSIONS`, `ADVANCED_EXPRESSIONS` | **restent** dans `ai_studio_dialog.gd` | inchangé |
| `_resolve_unique_path()` (static) | **reste** dans `ai_studio_dialog.gd` | inchangé |
| `_compute_upscale_target()` (static) | **reste** dans `ai_studio_dialog.gd` | inchangé |

## Migration des tests (`test_ai_studio_dialog.gd`)

**Règle générale (variables ET méthodes)** : tout accès à `_dialog._PREFIX_MEMBER` où `PREFIX` est `decl_`, `expr_`, ou `upscale_` devient `_dialog._PREFIX_tab.MEMBER_without_prefix`. Cette règle s'applique indistinctement aux variables d'état, aux widgets UI, et aux appels de méthodes.

Exemples :
- `_dialog._decl_workflow_option` → `_dialog._decl_tab._workflow_option`
- `_dialog._decl_choose_gallery_btn` → `_dialog._decl_tab._choose_gallery_btn`
- `_dialog._decl_source_image_path` → `_dialog._decl_tab._source_image_path`
- `_dialog._expr_elementary_checkboxes` → `_dialog._expr_tab._elementary_checkboxes`
- `_dialog._expr_choose_gallery_btn` → `_dialog._expr_tab._choose_gallery_btn`
- `_dialog._expr_queue` → `_dialog._expr_tab._queue`
- `_dialog._expr_generating` → `_dialog._expr_tab._generating`
- `_dialog._expr_custom_container` → `_dialog._expr_tab._custom_container`
- `_dialog._upscale_source_image_path` → `_dialog._upscale_tab._source_image_path`
- `_dialog._upscale_choose_gallery_btn` → `_dialog._upscale_tab._choose_gallery_btn`
- `_dialog._update_decl_generate_button()` → `_dialog._decl_tab.update_generate_button()` (méthode publique du tab)
- `_dialog._update_expr_generate_button()` → `_dialog._expr_tab.update_generate_button()`
- `_dialog._update_upscale_generate_button()` → `_dialog._upscale_tab.update_generate_button()`
- `_dialog._update_expr_preview_button()` → `_dialog._expr_tab._update_preview_button()`
- `_dialog._expr_set_inputs_enabled(...)` → `_dialog._expr_tab._set_inputs_enabled(...)`
- `_dialog._get_selected_expressions()` → `_dialog._expr_tab._get_selected_expressions()`
- `_dialog._build_results_grid()` → `_dialog._expr_tab._build_results_grid()`
- `_dialog._build_preview_collection()` → `_dialog._expr_tab._build_preview_collection()`
- `_dialog._add_custom_expression_ui(...)` → `_dialog._expr_tab._add_custom_expression_ui(...)`
- `_dialog._on_expr_add_custom()` → `_dialog._expr_tab._on_add_custom()`
- `_dialog._on_decl_save_pressed()` → `_dialog._decl_tab._on_save_pressed()`
- `_dialog._on_expr_save_all_pressed()` → `_dialog._expr_tab._on_save_all_pressed()`

Ce qui ne change pas dans les tests :
- `_dialog._story_base_path` → **inchangé** (reste dans l'orchestrateur)
- `_dialog._tab_container` → **inchangé** (reste dans l'orchestrateur)
- `AIStudioDialog.ELEMENTARY_EXPRESSIONS` → **inchangé** (reste dans l'orchestrateur)
- `AIStudioDialog.ADVANCED_EXPRESSIONS` → **inchangé** (reste dans l'orchestrateur)
- `AIStudioDialog._resolve_unique_path(...)` → **inchangé** (reste dans l'orchestrateur)
- `AIStudioDialog._compute_upscale_target(...)` → **inchangé** (reste dans l'orchestrateur)

## Points d'attention

### 1. `add_child` dans les tabs

Les tabs sont des `RefCounted` (pas des `Node`). Toutes les opérations `add_child()` — `ImageFileDialog`, `ConfirmationDialog`, `ComfyUIClient` — passent par `_parent_window.add_child(node)`.

Les handlers "Parcourir..." (`_on_choose_source` dans chaque tab) restent dans le tab et appellent `_parent_window.add_child(dialog)`.

`_open_gallery_source_picker` (qui reste dans l'orchestrateur) fait `add_child(gallery_window)` sur `self` (le Window), ce qui est normal et n'est pas impacté.

### 2. Inputs partagés activés/désactivés

`_set_inputs_enabled()` dans chaque tab modifie `_url_input.editable`, `_token_input.editable`, `_neg_input.editable` via les références reçues dans `initialize()`.

Limitation connue et acceptée : si deux tabs génèrent simultanément (cas impossible en pratique), leurs appels à `_set_inputs_enabled` pourraient entrer en conflit. Ce comportement est identique à l'état actuel du code monolithique.

### 3. `_load_preview()` — dupliqué dans chaque tab

Ce helper de 5 lignes est dupliqué dans chaque tab comme méthode privée identique :

```gdscript
func _load_preview(tex_rect: TextureRect, path: String) -> void:
    if path == "":
        tex_rect.texture = null
        return
    var img = Image.new()
    if img.load(path) == OK:
        tex_rect.texture = ImageTexture.create_from_image(img)
    else:
        tex_rect.texture = null
```

### 4. `_resolve_unique_path()` — reste dans l'orchestrateur, passé en Callable

La static function reste dans `ai_studio_dialog.gd` (les tests l'appellent via `AIStudioDialog._resolve_unique_path(...)`). Les tabs Expressions et Upscale la reçoivent via `resolve_path_fn: Callable` dans `initialize()` et l'appellent via `_resolve_path_fn.call(dir, filename)`.

### 5. `GalleryCacheService` — accessible globalement

Défini avec `class_name` dans le projet, accessible depuis n'importe quel fichier GDScript sans `preload` ni injection.

### 6. `ELEMENTARY_EXPRESSIONS` et `ADVANCED_EXPRESSIONS`

Restent comme constantes de classe dans `ai_studio_dialog.gd`. L'onglet Expressions les lit via preload de l'orchestrateur — ce qui créerait une dépendance circulaire. Pour éviter cela : **les constantes sont dupliquées** dans `ai_studio_expressions_tab.gd`. L'orchestrateur garde ses propres copies (pour les tests). Les deux copies sont identiques.

## Ce qui NE change PAS

- Comportement fonctionnel : aucun
- API publique du dialog (`setup()`, signaux exposés)
- Aucun `.tscn` créé, aucun signal public ajouté
