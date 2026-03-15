# AI Studio Dialog Split Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Découper `ai_studio_dialog.gd` (2116 lignes) en 4 fichiers sans changer les comportements.

**Architecture:** 3 contrôleurs `RefCounted` (un par onglet) reçoivent les inputs partagés via `initialize()` et construisent leur onglet via `build_tab()`. L'orchestrateur garde le code partagé (config, galerie, preview, fonctions statiques testées).

**Tech Stack:** GDScript 4.6.1, GUT 9.3.0, pas de scène `.tscn`.

**Spec:** `docs/superpowers/specs/2026-03-15-ai-studio-dialog-split-design.md`

---

## Fichiers touchés

| Action | Fichier |
|--------|---------|
| Modifier | `src/ui/dialogs/ai_studio_dialog.gd` |
| Créer | `src/ui/dialogs/ai_studio_decliner_tab.gd` |
| Créer | `src/ui/dialogs/ai_studio_expressions_tab.gd` |
| Créer | `src/ui/dialogs/ai_studio_upscale_tab.gd` |
| Modifier | `specs/ui/dialogs/test_ai_studio_dialog.gd` |

---

## Chunk 1 : Créer `ai_studio_decliner_tab.gd`

### Task 1 : Créer le contrôleur Décliner

**Files:**
- Create: `src/ui/dialogs/ai_studio_decliner_tab.gd`

- [ ] **Step 1 : Créer le fichier avec l'interface**

  Lire `src/ui/dialogs/ai_studio_dialog.gd` pour extraire tout le code préfixé `_decl_`.

  Le fichier doit `extends RefCounted` et contenir :

  **Variables d'état** (depuis les lignes 41-64 du fichier original, renommées sans préfixe `_decl_`) :
  ```gdscript
  extends RefCounted

  const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
  const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")
  const ImageFileDialog = preload("res://src/ui/shared/image_file_dialog.gd")
  const ImageRenameService = preload("res://src/services/image_rename_service.gd")

  # Shared refs (set via initialize)
  var _parent_window: Window
  var _url_input: LineEdit
  var _token_input: LineEdit
  var _neg_input: TextEdit
  var _show_preview_fn: Callable
  var _open_gallery_fn: Callable
  var _save_config_fn: Callable
  var _resolve_path_fn: Callable
  var _story_base_path: String = ""

  # UI widgets (ex _decl_*)
  var _workflow_option: OptionButton
  var _source_preview: TextureRect
  var _source_path_label: Label
  var _choose_source_btn: Button
  var _choose_gallery_btn: Button
  var _prompt_input: TextEdit
  var _cfg_slider: HSlider
  var _cfg_value_label: Label
  var _cfg_hint: Label
  var _steps_slider: HSlider
  var _steps_value_label: Label
  var _generate_btn: Button
  var _result_preview: TextureRect
  var _status_label: Label
  var _progress_bar: ProgressBar
  var _name_input: LineEdit
  var _save_btn: Button
  var _regenerate_btn: Button

  # State
  var _client: Node = null
  var _source_image_path: String = ""
  var _generated_image: Image = null
  ```

  **Interface publique** :
  ```gdscript
  func initialize(
      parent_window: Window,
      url_input: LineEdit,
      token_input: LineEdit,
      neg_input: TextEdit,
      show_preview_fn: Callable,
      open_gallery_fn: Callable,
      save_config_fn: Callable,
      resolve_path_fn: Callable
  ) -> void:
      _parent_window = parent_window
      _url_input = url_input
      _token_input = token_input
      _neg_input = neg_input
      _show_preview_fn = show_preview_fn
      _open_gallery_fn = open_gallery_fn
      _save_config_fn = save_config_fn
      _resolve_path_fn = resolve_path_fn

  func build_tab(tab_container: TabContainer) -> void:
      # Copier le contenu de _build_decliner_tab() du fichier original,
      # en remplaçant add_child(dialog) par _parent_window.add_child(dialog),
      # et en enlevant le préfixe _decl_ de toutes les variables.

  func setup(story_base_path: String, has_story: bool) -> void:
      _story_base_path = story_base_path
      _choose_gallery_btn.disabled = not has_story

  func update_generate_button() -> void:
      _update_generate_button()

  func update_cfg_hint(has_negative: bool) -> void:
      if _cfg_hint:
          _cfg_hint.visible = has_negative and _cfg_slider.value < 3.0

  func cancel_generation() -> void:
      if _client != null:
          _client.cancel()
          _client.queue_free()
          _client = null
  ```

  **Toutes les fonctions privées** : copier depuis le fichier original les fonctions `_on_decl_*`, `_decl_*`, en supprimant le préfixe `_decl_`. Remplacer :
  - `add_child(...)` → `_parent_window.add_child(...)`
  - `_url_input` / `_token_input` / `_negative_prompt_input` → `_url_input` / `_token_input` / `_neg_input`
  - `_story_base_path` → `_story_base_path` (inchangé, local)
  - `_show_image_preview(...)` → `_show_preview_fn.call(...)`
  - `_open_gallery_source_picker(...)` → `_open_gallery_fn.call(...)`
  - `_save_config()` → `_save_config_fn.call()`
  - `GalleryCacheService` → inchangé (class_name global)

  Inclure `_load_preview()` copié depuis l'original (lignes 1927–1935).

- [ ] **Step 2 : Pas de test séparé — vérification à l'étape Task 5**

  Le fichier ne peut pas être testé indépendamment (pas de `_ready`, dépend de l'orchestrateur). La vérification se fait via les tests existants après mise à jour de l'orchestrateur et des tests.

---

## Chunk 2 : Créer `ai_studio_expressions_tab.gd`

### Task 2 : Créer le contrôleur Expressions

**Files:**
- Create: `src/ui/dialogs/ai_studio_expressions_tab.gd`

- [ ] **Step 1 : Créer le fichier**

  Même structure que le DeclinerTab. Extraire tout le code préfixé `_expr_`.

  Imports nécessaires :
  ```gdscript
  const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
  const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")
  const ImageFileDialog = preload("res://src/ui/shared/image_file_dialog.gd")
  const ExpressionQueueService = preload("res://src/services/expression_queue_service.gd")
  const ImageRenameService = preload("res://src/services/image_rename_service.gd")
  ```

  Constantes dupliquées depuis l'orchestrateur :
  ```gdscript
  const ELEMENTARY_EXPRESSIONS := [
      "smile", "sad", "shy", "grumpy", "laughing out loud",
      "angry", "surprised", "scared", "bored", "speaking",
      "happy", "calm", "crying", "determined", "exhausted",
      "annoyed",
  ]

  const ADVANCED_EXPRESSIONS := [
      "worried", "neutral", "disgusted", "confused", "proud",
      "embarrassed", "idle", "thinking", "listening", "cheerful",
      "confident", "playful", "curious", "warm", "friendly",
      "joyful", "serene", "enthusiastic", "excited", "hopeful",
      "jealous", "dreamy", "mischievous", "relieved", "suspicious",
      "tender", "desperate", "nostalgic", "seductive",
  ]
  ```

  Variables d'état (depuis lignes 66-102, sans préfixe `_expr_`) :
  ```gdscript
  var _source_preview: TextureRect
  var _source_path_label: Label
  var _choose_source_btn: Button
  var _choose_gallery_btn: Button
  var _prefix_input: LineEdit
  var _cfg_slider: HSlider
  var _cfg_value_label: Label
  var _cfg_hint: Label
  var _steps_slider: HSlider
  var _steps_value_label: Label
  var _denoise_slider: HSlider
  var _denoise_value_label: Label
  var _face_box_slider: HSlider
  var _face_box_value_label: Label
  var _elementary_checkboxes: Array = []
  var _advanced_checkboxes: Array = []
  var _elementary_select_all_btn: Button
  var _advanced_select_all_btn: Button
  var _custom_container: VBoxContainer
  var _custom_input: LineEdit
  var _add_custom_btn: Button
  var _generate_btn: Button
  var _cancel_btn: Button
  var _status_label: Label
  var _progress_bar: ProgressBar
  var _results_grid: GridContainer
  var _save_all_btn: Button
  var _preview_btn: Button
  var _context_menu: PopupMenu

  var _source_image_path: String = ""
  var _client: Node = null
  var _queue: RefCounted = null
  var _generating: bool = false
  var _context_index: int = -1

  var _image_preview: Control = null  # Set via set_image_preview()
  ```

  Interface publique spécifique Expressions :
  ```gdscript
  func set_image_preview(image_preview: Control) -> void:
      _image_preview = image_preview
  ```

  `_on_delete_item` (renommé depuis `_on_expr_delete_item`) **doit** appeler `_update_preview_button()` à la fin — c'est l'appel qui était dans le wrapper `_on_preview_delete` supprimé.

  `_on_item_failed` accède directement aux internals de `_image_preview` :
  ```gdscript
  if _image_preview and _image_preview.visible and _image_preview.get_current_queue_index() == idx:
      _image_preview._filename_label.text = ...
      _image_preview._regenerating = false
      _image_preview._regenerate_btn.disabled = false
      _image_preview._delete_btn.disabled = false
  ```
  C'est un accès aux membres privés de `ImagePreviewPopup`, accepté dans cette approche légère.

  `build_tab()` doit appeler `_load_custom_expressions()` à la fin (comme dans l'original).

  Fonctions à copier depuis l'original (sans préfixe `_expr_`) :
  - `_build_expressions_tab` → `build_tab`
  - Toutes les `_on_expr_*` → `_on_*`
  - Toutes les `_expr_*` → `_*`
  - `_update_group_select_all_btn` → inchangé (pas de préfixe `_expr_`)
  - `_get_selected_expressions`, `_load_custom_expressions`, `_save_custom_expressions`, etc.
  - `_build_results_grid`, `_create_grid_cell`, `_update_grid_cell_status`, `_update_grid_cell_image`
  - `_build_preview_collection`

  Inclure `_load_preview()` (copie identique).
  Inclure `_resolve_unique_path()` reçu via Callable : remplacer les appels `_resolve_unique_path(...)` par `_resolve_path_fn.call(...)`.

- [ ] **Step 2 : Pas de test séparé — vérification à Task 5**

---

## Chunk 3 : Créer `ai_studio_upscale_tab.gd`

### Task 3 : Créer le contrôleur Upscale

**Files:**
- Create: `src/ui/dialogs/ai_studio_upscale_tab.gd`

- [ ] **Step 1 : Créer le fichier**

  Imports :
  ```gdscript
  const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
  const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")
  const ImageFileDialog = preload("res://src/ui/shared/image_file_dialog.gd")
  ```

  Variables d'état (depuis lignes 104-128, sans préfixe `_upscale_`) :
  ```gdscript
  var _source_preview: TextureRect
  var _source_path_label: Label
  var _choose_source_btn: Button
  var _choose_gallery_btn: Button
  var _max_dim_input: SpinBox
  var _dim_feedback_label: Label
  var _model_option: OptionButton
  var _denoise_slider: HSlider
  var _denoise_value_label: Label
  var _tile_btns: Array = []
  var _selected_tile_size: int = 512
  var _prompt_input: TextEdit
  var _generate_btn: Button
  var _result_preview: TextureRect
  var _status_label: Label
  var _progress_bar: ProgressBar
  var _save_btn: Button
  var _regenerate_btn: Button

  var _source_image_path: String = ""
  var _original_size: Vector2i = Vector2i.ZERO
  var _generated_image: Image = null
  var _client: Node = null
  ```

  `update_cfg_hint` n'est **pas** implémenté dans ce tab.

  `_compute_upscale_target` : dupliquer la static function depuis l'original (c'est aussi une copie locale ; l'orchestrateur garde la sienne pour les tests) :
  ```gdscript
  static func _compute_upscale_target(original: Vector2i, max_dim: int) -> Vector2i:
      if original == Vector2i.ZERO:
          return Vector2i.ZERO
      var scale = float(max_dim) / float(max(original.x, original.y))
      return Vector2i(roundi(original.x * scale), roundi(original.y * scale))
  ```

  Remplacer `_resolve_unique_path(...)` → `_resolve_path_fn.call(...)`.
  Remplacer `add_child(...)` → `_parent_window.add_child(...)`.
  Remplacer `_negative_prompt_input` → `_neg_input`.

- [ ] **Step 2 : Pas de test séparé — vérification à Task 5**

---

## Chunk 4 : Réécrire l'orchestrateur

### Task 4 : Réécrire `ai_studio_dialog.gd`

**Files:**
- Modify: `src/ui/dialogs/ai_studio_dialog.gd`

- [ ] **Step 1 : Réécrire le fichier**

  L'orchestrateur garde :
  - Tous les `preload` existants (ComfyUIClient, ComfyUIConfig, ImagePreviewPopup, ImageFileDialog, ImageRenameService, ImageCategoryService, ExpressionQueueService)
  - Les 3 nouveaux preloads des tabs :
    ```gdscript
    const DeclinerTab = preload("res://src/ui/dialogs/ai_studio_decliner_tab.gd")
    const ExpressionsTab = preload("res://src/ui/dialogs/ai_studio_expressions_tab.gd")
    const UpscaleTab = preload("res://src/ui/dialogs/ai_studio_upscale_tab.gd")
    ```
  - Constantes (inchangées pour les tests) :
    ```gdscript
    const ELEMENTARY_EXPRESSIONS := [...] # identique à l'original
    const ADVANCED_EXPRESSIONS := [...]   # identique à l'original
    ```
  - Variables partagées :
    ```gdscript
    var _story = null
    var _story_base_path: String = ""
    var _category_service: RefCounted = null
    var _tab_container: TabContainer
    var _url_input: LineEdit
    var _token_input: LineEdit
    var _negative_prompt_input: TextEdit
    var _image_preview: Control
    var _decl_tab: RefCounted = null
    var _expr_tab: RefCounted = null
    var _upscale_tab: RefCounted = null
    ```
  - `_ready()` : inchangé
  - `setup()` : délègue à chaque tab
    ```gdscript
    func setup(story, story_base_path: String) -> void:
        _story = story
        _story_base_path = story_base_path
        _category_service = ImageCategoryService.new()
        if story_base_path != "":
            _category_service.load_from(story_base_path)
        var has_story = story_base_path != ""
        _decl_tab.setup(story_base_path, has_story)
        _expr_tab.setup(story_base_path, has_story)
        _upscale_tab.setup(story_base_path, has_story)
    ```
  - `_on_close()` : appelle `cancel_generation()` sur chaque tab + queue_free
  - `_build_ui()` : construit le header partagé, crée les tabs, appelle `initialize()` puis `build_tab()` sur chacun, puis `set_image_preview()` sur `_expr_tab`, puis connecte les signaux du preview :
    ```gdscript
    func _build_ui() -> void:
        # ... (header partagé : URL, token, neg prompt — identique à l'original)
        _decl_tab = DeclinerTab.new()
        _expr_tab = ExpressionsTab.new()
        _upscale_tab = UpscaleTab.new()

        var common_args = [self, _url_input, _token_input, _negative_prompt_input,
            _show_image_preview, _open_gallery_source_picker, _save_config, _resolve_unique_path]
        _decl_tab.initialize(common_args[0], common_args[1], common_args[2], common_args[3],
            common_args[4], common_args[5], common_args[6], common_args[7])
        _expr_tab.initialize(common_args[0], common_args[1], common_args[2], common_args[3],
            common_args[4], common_args[5], common_args[6], common_args[7])
        _upscale_tab.initialize(common_args[0], common_args[1], common_args[2], common_args[3],
            common_args[4], common_args[5], common_args[6], common_args[7])

        _decl_tab.build_tab(_tab_container)
        _expr_tab.build_tab(_tab_container)
        _upscale_tab.build_tab(_tab_container)

        # Image preview overlay
        _image_preview = Control.new()
        _image_preview.set_script(ImagePreviewPopup)
        _image_preview.regenerate_requested.connect(_expr_tab._on_regenerate_item)
        _image_preview.delete_requested.connect(_expr_tab._on_delete_item)
        add_child(_image_preview)
        _expr_tab.set_image_preview(_image_preview)
        # ... (bottom bar : Fermer button)
    ```
  - `_load_config()`, `_save_config()` : identiques à l'original
  - `_update_all_generate_buttons()` :
    ```gdscript
    func _update_all_generate_buttons() -> void:
        _decl_tab.update_generate_button()
        _expr_tab.update_generate_button()
        _upscale_tab.update_generate_button()
    ```
  - `_update_cfg_hints()` :
    ```gdscript
    func _update_cfg_hints() -> void:
        var has_negative = _negative_prompt_input.text.strip_edges() != ""
        _decl_tab.update_cfg_hint(has_negative)
        _expr_tab.update_cfg_hint(has_negative)
    ```
  - `_show_image_preview()`, `_open_gallery_source_picker()`, `_list_gallery_images()` : identiques à l'original
  - Statics conservées (identiques à l'original) :
    ```gdscript
    static func _resolve_unique_path(dir_path: String, filename: String) -> String: ...
    static func _compute_upscale_target(original: Vector2i, max_dim: int) -> Vector2i: ...
    ```

  **Supprimer** de l'orchestrateur : tout le code `_decl_*`, `_expr_*`, `_upscale_*`, `_build_decliner_tab()`, `_build_expressions_tab()`, `_build_upscale_tab()`, les wrappers `_on_preview_regenerate`, `_on_preview_delete`.

- [ ] **Step 2 : Vérification syntaxique rapide**

  Lancer Godot en mode headless pour vérifier l'absence d'erreurs de script (sans lancer les tests) :
  ```bash
  GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
  timeout 30 $GODOT --headless --path . --quit 2>&1 | head -50
  ```
  Attendu : pas d'erreurs `Parse Error` ou `Identifier not found`.

---

## Chunk 5 : Mettre à jour les tests

### Task 5 : Mettre à jour `test_ai_studio_dialog.gd`

**Files:**
- Modify: `specs/ui/dialogs/test_ai_studio_dialog.gd`

- [ ] **Step 1 : Appliquer la règle de renommage**

  Règle générale : `_dialog._PREFIX_MEMBER` → `_dialog._PREFIX_tab.MEMBER_without_prefix`

  Les remplacements à effectuer **dans tout le fichier** :

  Décliner :
  - `_dialog._decl_` → `_dialog._decl_tab._` (supprime préfixe `decl_`)
  - `_dialog._update_decl_generate_button()` → `_dialog._decl_tab.update_generate_button()`
  - `_dialog._on_decl_save_pressed()` → `_dialog._decl_tab._on_save_pressed()`
  - `_dialog._on_decl_generate_pressed()` → `_dialog._decl_tab._on_generate_pressed()`

  Expressions :
  - `_dialog._expr_` → `_dialog._expr_tab._` (supprime préfixe `expr_`)
  - `_dialog._update_expr_generate_button()` → `_dialog._expr_tab.update_generate_button()`
  - `_dialog._update_expr_preview_button()` → `_dialog._expr_tab._update_preview_button()`
  - `_dialog._expr_set_inputs_enabled(...)` → `_dialog._expr_tab._set_inputs_enabled(...)`
  - `_dialog._get_selected_expressions()` → `_dialog._expr_tab._get_selected_expressions()`
  - `_dialog._build_results_grid()` → `_dialog._expr_tab._build_results_grid()`
  - `_dialog._build_preview_collection()` → `_dialog._expr_tab._build_preview_collection()`
  - `_dialog._add_custom_expression_ui(...)` → `_dialog._expr_tab._add_custom_expression_ui(...)`
  - `_dialog._on_expr_add_custom()` → `_dialog._expr_tab._on_add_custom()`
  - `_dialog._on_expr_save_all_pressed()` → `_dialog._expr_tab._on_save_all_pressed()`

  Upscale :
  - `_dialog._upscale_` → `_dialog._upscale_tab._` (supprime préfixe `upscale_`)
  - `_dialog._update_upscale_generate_button()` → `_dialog._upscale_tab.update_generate_button()`

  **Inchangés** :
  - `_dialog._story_base_path`
  - `_dialog._tab_container`
  - `_dialog._url_input`
  - `_dialog._token_input`
  - `_dialog._negative_prompt_input`
  - `AIStudioDialog.ELEMENTARY_EXPRESSIONS`
  - `AIStudioDialog.ADVANCED_EXPRESSIONS`
  - `AIStudioDialog._resolve_unique_path(...)`
  - `AIStudioDialog._compute_upscale_target(...)`

  **Attention** : `_dialog._negative_prompt_input` dans `_decl_set_inputs_enabled` — cette logique est maintenant dans le tab, donc les tests qui appellaient `_dialog._decl_set_inputs_enabled(true)` deviennent `_dialog._decl_tab._set_inputs_enabled(true)`.

- [ ] **Step 2 : Lancer les tests**

  ```bash
  GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
  timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/dialogs/test_ai_studio_dialog.gd 2>&1 | tail -30
  ```
  Attendu : tous les tests passent (0 failures).

- [ ] **Step 3 : Si des tests échouent**

  Lire l'erreur, identifier la variable ou méthode manquante, et appliquer la règle de renommage correctement. Corriger dans le fichier de test et relancer.

---

## Chunk 6 : Lancer tous les tests et commit

### Task 6 : Validation finale et commit

**Files:** aucun

- [ ] **Step 1 : Lancer tous les tests GUT**

  ```bash
  GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
  timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd 2>&1 | tail -40
  ```
  Attendu : couverture ≥ 65%, 0 failures.

- [ ] **Step 2 : Commit**

  ```bash
  git add src/ui/dialogs/ai_studio_decliner_tab.gd \
          src/ui/dialogs/ai_studio_expressions_tab.gd \
          src/ui/dialogs/ai_studio_upscale_tab.gd \
          src/ui/dialogs/ai_studio_dialog.gd \
          specs/ui/dialogs/test_ai_studio_dialog.gd
  git commit -m "refactor(ui): split ai_studio_dialog into 3 tab controllers (2116→~250 lines)"
  ```
