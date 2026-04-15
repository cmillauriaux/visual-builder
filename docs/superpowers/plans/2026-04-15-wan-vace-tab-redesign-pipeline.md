# WAN VACE Tab — Redesign Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactoriser l'onglet Wan VACE en 5 sections progressives : générer toutes les frames brutes, sous-échantillonner, appliquer BiRefNet en batch, exporter — sans relancer la génération.

**Architecture:** Machine d'état (IDLE/GENERATING/FRAMES_READY/BG_PROCESSING) dans `ai_studio_wan_vace_tab.gd` ; nouveau `apply_birefnet()` + `_build_birefnet_workflow()` dans `ComfyUIClient` réutilisant le pipeline `generate()` existant.

**Tech Stack:** GDScript 4.6, GUT 9.3.0, ComfyUI (BiRefNetRMBG node), ApngBuilder existant.

---

## Fichiers touchés

| Fichier | Action |
|---|---|
| `src/services/comfyui_client.gd` | Modifier : ajouter `WorkflowType.BIREFNET_ONLY`, `_build_birefnet_workflow()`, `apply_birefnet()` |
| `specs/services/test_comfyui_client.gd` | Modifier : ajouter tests pour `_build_birefnet_workflow` |
| `plugins/ai_studio/ai_studio_wan_vace_tab.gd` | Modifier : refactor complet sections 1–5, machine d'état |

---

## Contexte codebase (à lire avant de commencer)

- **`src/services/comfyui_client.gd`** : classe Node. `build_workflow()` est publique et dispatche vers des builders privés selon `WorkflowType`. `generate()` prend un chemin de fichier image, upload + prompt + poll + download, émet `generation_completed(image: Image)`. `generate_sequence()` idem pour les séquences, émet `sequence_completed(images: Array)`.
- **`plugins/ai_studio/ai_studio_wan_vace_tab.gd`** : classe RefCounted. `build_tab()` construit l'UI dans un `ScrollContainer`. `_client` est le Node ComfyUIClient actif. Les fonctions helpers : `_show_status/success/error()`, `_set_inputs_enabled()`, `_update_generate_button()`.
- **`specs/services/test_comfyui_client.gd`** : tests GUT, charge le script via `load("res://src/services/comfyui_client.gd")`, crée des instances et appelle `build_workflow()` directement.
- **Godot 4.6** — pas de type `Array[Image]` dans les signatures lambdas, utiliser `Array` non-typé. `roundi()` existe. `maxi()` existe.

---

## Task 1 : `_build_birefnet_workflow` + tests

**Files:**
- Modify: `src/services/comfyui_client.gd`
- Modify: `specs/services/test_comfyui_client.gd`

- [ ] **Step 1 : Écrire les tests qui échouent**

À la fin de `specs/services/test_comfyui_client.gd`, ajouter :

```gdscript
func test_build_birefnet_workflow_has_correct_nodes():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("frame.png", "", 1, false, 1.0, 1,
		ComfyUIClientScript.WorkflowType.BIREFNET_ONLY)
	assert_true(wf.has("br:src"), "LoadImage absent")
	assert_eq(wf["br:src"]["class_type"], "LoadImage")
	assert_true(wf.has("br:birefnet"), "BiRefNetRMBG absent")
	assert_eq(wf["br:birefnet"]["class_type"], "BiRefNetRMBG")
	assert_true(wf.has("br:save"), "SaveImage absent")
	assert_eq(wf["br:save"]["class_type"], "SaveImage")

func test_build_birefnet_workflow_uses_source_filename():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("frame_007.png", "", 1, false, 1.0, 1,
		ComfyUIClientScript.WorkflowType.BIREFNET_ONLY)
	assert_eq(wf["br:src"]["inputs"]["image"], "frame_007.png")

func test_build_birefnet_workflow_connects_nodes():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("frame.png", "", 1, false, 1.0, 1,
		ComfyUIClientScript.WorkflowType.BIREFNET_ONLY)
	assert_eq(wf["br:birefnet"]["inputs"]["image"][0], "br:src")
	assert_eq(wf["br:save"]["inputs"]["images"][0], "br:birefnet")

func test_build_birefnet_workflow_alpha_background():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("frame.png", "", 1, false, 1.0, 1,
		ComfyUIClientScript.WorkflowType.BIREFNET_ONLY)
	assert_eq(wf["br:birefnet"]["inputs"]["background"], "Alpha")
```

- [ ] **Step 2 : Vérifier que les tests échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client.gd -glog=2 2>&1 | tail -10
```

Attendu : FAIL (WorkflowType.BIREFNET_ONLY undefined).

- [ ] **Step 3 : Ajouter `BIREFNET_ONLY` à l'enum**

Dans `src/services/comfyui_client.gd`, trouver la ligne de l'enum (ligne ~20) :
```gdscript
enum WorkflowType { CREATION = 0, EXPRESSION = 1, OUTPAINT = 2, UPSCALE = 3, ENHANCE = 4, UPSCALE_ENHANCE = 5, BLINK = 6, INPAINT = 7, LORA_CREATE_FLUX = 8, ILLUSTRIOUS = 9, ASSEMBLER = 10, ZIMAGE_DECLINER = 11, WAN_VACE = 12, WAN_VACE_POSE = 13, WAN_VACE_DWPOSE_PREVIEW = 14, WAN_I2V = 15, FLUX_DECLINER_CONTROL = 16 }
```
Remplacer par :
```gdscript
enum WorkflowType { CREATION = 0, EXPRESSION = 1, OUTPAINT = 2, UPSCALE = 3, ENHANCE = 4, UPSCALE_ENHANCE = 5, BLINK = 6, INPAINT = 7, LORA_CREATE_FLUX = 8, ILLUSTRIOUS = 9, ASSEMBLER = 10, ZIMAGE_DECLINER = 11, WAN_VACE = 12, WAN_VACE_POSE = 13, WAN_VACE_DWPOSE_PREVIEW = 14, WAN_I2V = 15, FLUX_DECLINER_CONTROL = 16, BIREFNET_ONLY = 17 }
```

- [ ] **Step 4 : Ajouter le dispatch dans `build_workflow()`**

Dans `build_workflow()`, juste avant la ligne `if workflow_type == WorkflowType.WAN_VACE_DWPOSE_PREVIEW:`, ajouter :
```gdscript
	if workflow_type == WorkflowType.BIREFNET_ONLY:
		return _build_birefnet_workflow(filename)
```

- [ ] **Step 5 : Ajouter `_build_birefnet_workflow()`**

À la fin du fichier (avant la dernière ligne), ajouter :
```gdscript
## Workflow BiRefNet seul : retire le fond d'une image et retourne du RGBA transparent.
func _build_birefnet_workflow(source_filename: String) -> Dictionary:
	return {
		"br:src": {
			"class_type": "LoadImage",
			"inputs": {"image": source_filename}
		},
		"br:birefnet": {
			"class_type": "BiRefNetRMBG",
			"inputs": {
				"model": "BiRefNet-general",
				"mask_blur": 0,
				"mask_offset": 0,
				"invert_output": false,
				"refine_foreground": true,
				"background": "Alpha",
				"background_color": "#222222",
				"image": ["br:src", 0]
			}
		},
		"br:save": {
			"class_type": "SaveImage",
			"inputs": {
				"filename_prefix": "birefnet_frame",
				"images": ["br:birefnet", 0]
			}
		}
	}
```

- [ ] **Step 6 : Vérifier que les tests passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client.gd -glog=2 2>&1 | tail -10
```

Attendu : 4 nouveaux tests PASS.

- [ ] **Step 7 : Vérifier la compilation**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . --import 2>&1 | grep -E "ERROR|SCRIPT ERROR|Parse Error"
```

Attendu : aucune erreur.

- [ ] **Step 8 : Commit**

```bash
git add src/services/comfyui_client.gd specs/services/test_comfyui_client.gd
git commit -m "feat: add WorkflowType.BIREFNET_ONLY + _build_birefnet_workflow"
```

---

## Task 2 : `apply_birefnet()` dans ComfyUIClient

**Files:**
- Modify: `src/services/comfyui_client.gd`

`apply_birefnet()` sauvegarde l'image dans un fichier temp, puis appelle `generate()` qui gère tout (upload, prompt, poll, download) et émet `generation_completed(image)`.

- [ ] **Step 1 : Ajouter `apply_birefnet()` dans `comfyui_client.gd`**

Juste avant `_build_birefnet_workflow()` (à la fin du fichier), ajouter :

```gdscript
## Applique BiRefNet sur une image en mémoire.
## Sauvegarde dans un fichier temp, utilise le pipeline generate() standard.
## Émet generation_completed(image: Image) ou generation_failed(error: String).
func apply_birefnet(config: RefCounted, image: Image) -> void:
	var temp_path := ProjectSettings.globalize_path("user://birefnet_temp.png")
	image.save_png(temp_path)
	generate(config, temp_path, "", false, 1.0, 1,
		WorkflowType.BIREFNET_ONLY, 1.0, "", 80, 1.0, [])
```

- [ ] **Step 2 : Vérifier la compilation**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . --import 2>&1 | grep -E "ERROR|SCRIPT ERROR|Parse Error"
```

Attendu : aucune erreur.

- [ ] **Step 3 : Commit**

```bash
git add src/services/comfyui_client.gd
git commit -m "feat: add apply_birefnet() to ComfyUIClient"
```

---

## Task 3 : Tab — refactor vars + section 1

**Files:**
- Modify: `plugins/ai_studio/ai_studio_wan_vace_tab.gd`

Cette tâche remplace les vars supprimées par les nouvelles, nettoie la section 1 de `build_tab()`, et met à jour `_on_generate_pressed`.

- [ ] **Step 1 : Remplacer le bloc de vars (lignes 22–98)**

Remplacer tout le bloc de déclarations de variables d'instance (de `# --- UI : source image ---` jusqu'à `var _selected_image_index: int = -1`) par :

```gdscript
# --- UI : source image ---
var _source_preview: TextureRect
var _source_path_label: Label
var _choose_source_btn: Button
var _choose_gallery_btn: Button

# --- UI : mode toggle ---
var _mode_no_pose_btn: Button
var _mode_pose_btn: Button
var _pose_panel: VBoxContainer

# --- UI : pose panel ---
var _pose_preview: TextureRect
var _pose_path_label: Label
var _choose_pose_btn: Button
var _skeleton_preview: TextureRect
var _estimate_pose_btn: Button
var _strength_slider: HSlider
var _strength_value_label: Label

# --- UI : paramètres ---
var _prompt_input: TextEdit
var _steps_slider: HSlider
var _steps_value_label: Label
var _cfg_slider: HSlider
var _cfg_value_label: Label
var _cfg_hint: Label
var _denoise_slider: HSlider
var _denoise_value_label: Label
var _duration_slider: HSlider
var _duration_value_label: Label
var _fps_slider: HSlider
var _fps_value_label: Label
# --- UI : LORAs ---
var _loras_vbox: VBoxContainer
var _lora_option: OptionButton
# --- UI : génération ---
var _generate_btn: Button
var _cancel_btn: Button
var _status_label: Label
var _progress_bar: ProgressBar
var _debug_save_video_check: CheckBox

# --- UI : résultats (section 2) ---
var _results_section: VBoxContainer
var _frame_count_label: Label
var _result_grid: HFlowContainer
var _preview_rect: TextureRect
var _preview_timer: Timer
var _anim_frame_index: int = 0
var _grid_textures: Dictionary = {}

# --- UI : sélection (section 3) ---
var _spin_start: SpinBox
var _spin_end: SpinBox
var _spin_n: SpinBox

# --- UI : fond transparent (section 4) ---
var _bg_btn: Button
var _bg_progress_label: Label

# --- UI : export (section 5) ---
var _export_panel: VBoxContainer
var _export_prefix_input: LineEdit
var _export_name_input: LineEdit
var _export_frames_btn: Button
var _export_apng_btn: Button

# State
const STATE_IDLE := 0
const STATE_GENERATING := 1
const STATE_FRAMES_READY := 2
const STATE_BG_PROCESSING := 3

var _state: int = STATE_IDLE
var _client: Node = null
var _birefnet_client: Node = null
var _birefnet_index: int = 0
var _source_image_path: String = ""
var _pose_image_path: String = ""
var _pose_estimated: bool = false
var _pose_mode: bool = false
var _all_frames: Array = []
var _selected_frames: Array = []
var _selected_all_indices: Array = []
var _selected_loras: Array = []
```

- [ ] **Step 2 : Supprimer les contrôles obsolètes dans `build_tab()`**

Dans `build_tab()`, supprimer les blocs suivants (ils seront absents de la nouvelle UI) :

a) Le bloc `# --- Frames à extraire ---` (lignes ~411–425)
b) Le bloc `# --- Fond transparent ---` avec `_remove_bg_check` et `_transparent_output_check` (lignes ~427–436)
c) Le bloc `# --- Grille résultats ---` jusqu'à la fin de `build_tab()` (lignes ~470–622) — cette partie sera réécrite dans Task 4

Après suppression, `build_tab()` doit se terminer juste après le bloc `_progress_bar` et le `HSeparator` suivant (ligne ~468).

- [ ] **Step 3 : Mettre à jour `_on_generate_pressed()`**

Remplacer le corps de `_on_generate_pressed()` par :

```gdscript
func _on_generate_pressed() -> void:
	_save_config_fn.call()
	if _client != null:
		_client.cancel()
		_client.queue_free()
	_client = Node.new()
	_client.set_script(ComfyUIClient)
	_parent_window.add_child(_client)
	_client.sequence_completed.connect(_on_sequence_completed)
	_client.generation_failed.connect(_on_generation_failed)
	_client.generation_progress.connect(_on_generation_progress)
	_all_frames.clear()
	_selected_frames.clear()
	_set_state(STATE_GENERATING)
	_show_status("Lancement...")
	var config = _get_config_fn.call()
	var neg = _neg_input.text.strip_edges()
	var workflow_type = ComfyUIClient.WorkflowType.WAN_VACE_POSE if _pose_mode \
		else ComfyUIClient.WorkflowType.WAN_I2V
	_client.generate_sequence(
		config, _source_image_path, _prompt_input.text,
		false,
		_cfg_slider.value, int(_steps_slider.value),
		workflow_type,
		_denoise_slider.value, neg,
		1, float(_duration_slider.value),
		_pose_image_path if _pose_mode else "",
		_strength_slider.value,
		int(_fps_slider.value),
		_selected_loras.duplicate(),
		false,
		_debug_save_video_check.button_pressed
	)
```

- [ ] **Step 4 : Mettre à jour `_on_sequence_completed()`**

Remplacer le corps de `_on_sequence_completed()` par :

```gdscript
func _on_sequence_completed(images: Array) -> void:
	_all_frames = images
	_client = null
	if images.is_empty():
		_set_state(STATE_IDLE)
		_show_error("Aucune frame générée")
		return
	_build_results_ui()
	_set_state(STATE_FRAMES_READY)
	_show_success("Séquence générée (%d frames)" % images.size())
```

- [ ] **Step 5 : Mettre à jour `_on_generation_failed()`**

Remplacer le corps de `_on_generation_failed()` par :

```gdscript
func _on_generation_failed(error: String) -> void:
	_show_error("Erreur : " + error)
	_client = null
	_birefnet_client = null
	_set_state(STATE_IDLE if _all_frames.is_empty() else STATE_FRAMES_READY)
	_update_generate_button()
```

- [ ] **Step 6 : Mettre à jour `_on_cancel_pressed()`**

Remplacer par :

```gdscript
func _on_cancel_pressed() -> void:
	if _client != null:
		_client.cancel()
	if _birefnet_client != null:
		_birefnet_client.cancel()
		_birefnet_client.queue_free()
		_birefnet_client = null
	_cancel_btn.disabled = true
```

- [ ] **Step 7 : Mettre à jour `_set_inputs_enabled()`**

Remplacer le corps par (refs aux sliders supprimés retirées) :

```gdscript
func _set_inputs_enabled(enabled: bool) -> void:
	_neg_input.editable = enabled
	_prompt_input.editable = enabled
	_choose_source_btn.disabled = not enabled
	_choose_gallery_btn.disabled = not enabled or _story_base_path == ""
	_choose_pose_btn.disabled = not enabled
	_mode_no_pose_btn.disabled = not enabled
	_mode_pose_btn.disabled = not enabled
	_steps_slider.editable = enabled
	_cfg_slider.editable = enabled
	_denoise_slider.editable = enabled
	_duration_slider.editable = enabled
	_fps_slider.editable = enabled
	_estimate_pose_btn.disabled = not enabled or _pose_image_path == ""
	if _lora_option != null:
		_lora_option.disabled = not enabled
```

- [ ] **Step 8 : Ajouter `_set_state()` et `_update_generate_button()` mis à jour**

Ajouter la méthode `_set_state()` dans la section `# Private logic` :

```gdscript
func _set_state(new_state: int) -> void:
	_state = new_state
	if _results_section != null:
		_results_section.visible = _state >= STATE_FRAMES_READY
	if _export_panel != null:
		_export_panel.visible = _state >= STATE_FRAMES_READY
		_export_frames_btn.disabled = _state == STATE_BG_PROCESSING or _selected_frames.is_empty()
		_export_apng_btn.disabled = _state == STATE_BG_PROCESSING or _selected_frames.is_empty()
	if _bg_btn != null:
		_bg_btn.disabled = _state != STATE_FRAMES_READY or _selected_frames.is_empty()
	_cancel_btn.disabled = _state != STATE_GENERATING and _state != STATE_BG_PROCESSING
	_set_inputs_enabled(_state == STATE_IDLE or _state == STATE_FRAMES_READY)
	_update_generate_button()
```

Remplacer `_update_generate_button()` par :

```gdscript
func _update_generate_button() -> void:
	if _generate_btn == null:
		return
	if _state == STATE_GENERATING or _state == STATE_BG_PROCESSING:
		_generate_btn.disabled = true
		return
	var has_url = _get_config_fn.call().get_url() != ""
	var has_prompt = _prompt_input.text.strip_edges() != ""
	var has_source = _source_image_path != ""
	var pose_ready = not _pose_mode or _pose_estimated
	_generate_btn.disabled = not (has_url and has_prompt and has_source and pose_ready)
```

- [ ] **Step 9 : Supprimer les fonctions mortes**

Supprimer les fonctions suivantes (elles référencent des vars supprimées) :
- `_add_result_cell()` — sera remplacée dans Task 4
- `_select_frame()` — remplacée
- `_on_save_selected()` — remplacée
- `_do_save_selected()` — remplacée
- `_clear_result_grid()` — remplacée
- `_on_export_frames()` — remplacée dans Task 6
- `_on_export_apng()` — remplacée dans Task 6
- `_on_preview_toggled()` — remplacée
- `_start_preview()` — remplacée dans Task 4
- `_stop_preview()` — remplacée dans Task 4
- `_on_preview_tick()` — remplacée dans Task 4

- [ ] **Step 10 : Vérifier la compilation**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . --import 2>&1 | grep -E "ERROR|SCRIPT ERROR|Parse Error"
```

Attendu : aucune erreur (le tab est temporairement incomplet mais compilable).

- [ ] **Step 11 : Commit**

```bash
cd plugins/ai_studio && git add ai_studio_wan_vace_tab.gd && git commit -m "refactor: tab vars + section 1 cleanup, remove dead UI"
cd ../.. && git add plugins/ai_studio && git commit -m "refactor: wan vace tab — vars + section 1"
```

---

## Task 4 : Tab — sections 2 & 3 (résultats + sélection)

**Files:**
- Modify: `plugins/ai_studio/ai_studio_wan_vace_tab.gd`

- [ ] **Step 1 : Ajouter la construction des sections 2+3 dans `build_tab()`**

À la fin de `build_tab()` (après le `HSeparator` suivant le `_progress_bar`), ajouter :

```gdscript
	# ── Section 2 : Résultats ────────────────────────────────
	_results_section = VBoxContainer.new()
	_results_section.visible = false
	_results_section.add_theme_constant_override("separation", 8)
	vbox.add_child(_results_section)

	_results_section.add_child(HSeparator.new())

	_frame_count_label = Label.new()
	_frame_count_label.text = "Frames générées : 0"
	_results_section.add_child(_frame_count_label)

	# Preview animation
	_preview_rect = TextureRect.new()
	_preview_rect.custom_minimum_size = Vector2(0, 200)
	_preview_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_section.add_child(_preview_rect)

	# Grille
	var grid_scroll = ScrollContainer.new()
	grid_scroll.custom_minimum_size.y = 160
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_section.add_child(grid_scroll)

	_result_grid = HFlowContainer.new()
	_result_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_grid.add_theme_constant_override("h_separation", 4)
	_result_grid.add_theme_constant_override("v_separation", 4)
	grid_scroll.add_child(_result_grid)

	# ── Section 3 : Sélection ────────────────────────────────
	_results_section.add_child(HSeparator.new())

	var sel_title = Label.new()
	sel_title.text = "── Sélection ──"
	_results_section.add_child(sel_title)

	var sel_hbox = HBoxContainer.new()
	sel_hbox.add_theme_constant_override("separation", 8)
	_results_section.add_child(sel_hbox)

	var lbl_start = Label.new(); lbl_start.text = "Début :"
	sel_hbox.add_child(lbl_start)
	_spin_start = SpinBox.new()
	_spin_start.min_value = 1; _spin_start.max_value = 1; _spin_start.value = 1
	_spin_start.value_changed.connect(_on_selection_changed)
	sel_hbox.add_child(_spin_start)

	var lbl_end = Label.new(); lbl_end.text = "Fin :"
	sel_hbox.add_child(lbl_end)
	_spin_end = SpinBox.new()
	_spin_end.min_value = 1; _spin_end.max_value = 1; _spin_end.value = 1
	_spin_end.value_changed.connect(_on_selection_changed)
	sel_hbox.add_child(_spin_end)

	var lbl_n = Label.new(); lbl_n.text = "N frames :"
	sel_hbox.add_child(lbl_n)
	_spin_n = SpinBox.new()
	_spin_n.min_value = 1; _spin_n.max_value = 1; _spin_n.value = 1
	_spin_n.value_changed.connect(_on_selection_changed)
	sel_hbox.add_child(_spin_n)

	# Timer preview
	_preview_timer = Timer.new()
	_preview_timer.one_shot = false
	_preview_timer.timeout.connect(_on_preview_tick)
	_parent_window.add_child(_preview_timer)
```

- [ ] **Step 2 : Ajouter `_build_results_ui()` — appelé après génération**

Dans la section `# Private logic`, ajouter :

```gdscript
func _build_results_ui() -> void:
	var total := _all_frames.size()
	_frame_count_label.text = "Frames générées : %d" % total

	# Remplir la grille
	for child in _result_grid.get_children():
		child.queue_free()
	_grid_textures.clear()
	for i in range(total):
		var cell := VBoxContainer.new()
		_result_grid.add_child(cell)
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(100, 75)
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture = ImageTexture.create_from_image(_all_frames[i])
		cell.add_child(tex)
		_grid_textures[i] = tex
		var num_lbl := Label.new()
		num_lbl.text = str(i + 1)
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(num_lbl)

	# Configurer les spinboxes
	_spin_start.max_value = total
	_spin_start.value = 1
	_spin_end.max_value = total
	_spin_end.value = total
	_spin_n.max_value = total
	_spin_n.value = mini(8, total)

	# Calculer la sélection initiale (toutes les frames si N == total)
	_recompute_selection()
```

- [ ] **Step 3 : Ajouter `_recompute_selection()`**

```gdscript
func _recompute_selection() -> void:
	var start := int(_spin_start.value) - 1  # 0-based
	var end := int(_spin_end.value) - 1      # 0-based
	var n := int(_spin_n.value)

	# Clamp n à la plage disponible
	var max_n := end - start + 1
	if n > max_n:
		n = max_n
		_spin_n.value = n

	_selected_frames.clear()
	_selected_all_indices.clear()

	if n == 1:
		_selected_frames.append(_all_frames[start])
		_selected_all_indices.append(start)
	else:
		for i in range(n):
			var idx := roundi(start + float(i) * float(end - start) / float(n - 1))
			_selected_frames.append(_all_frames[idx])
			_selected_all_indices.append(idx)

	_start_preview()

	if _bg_btn != null:
		_bg_btn.disabled = _state != STATE_FRAMES_READY or _selected_frames.is_empty()
	if _export_panel != null:
		_export_frames_btn.disabled = _state == STATE_BG_PROCESSING or _selected_frames.is_empty()
		_export_apng_btn.disabled = _state == STATE_BG_PROCESSING or _selected_frames.is_empty()
```

- [ ] **Step 4 : Ajouter `_on_selection_changed()`, `_start_preview()`, `_stop_preview()`, `_on_preview_tick()`**

```gdscript
func _on_selection_changed(_val: float) -> void:
	if _all_frames.is_empty():
		return
	# Garder start <= end
	if _spin_start.value > _spin_end.value:
		_spin_end.value = _spin_start.value
	# Mettre à jour max de _spin_n
	var range_size := int(_spin_end.value) - int(_spin_start.value) + 1
	_spin_n.max_value = range_size
	_recompute_selection()


func _start_preview() -> void:
	if _selected_frames.is_empty():
		return
	_anim_frame_index = 0
	_preview_rect.texture = ImageTexture.create_from_image(_selected_frames[0])
	var fps := maxi(1, int(_fps_slider.value))
	_preview_timer.wait_time = 1.0 / fps
	_preview_timer.start()


func _stop_preview() -> void:
	_preview_timer.stop()


func _on_preview_tick() -> void:
	if _selected_frames.is_empty():
		_stop_preview()
		return
	_anim_frame_index = (_anim_frame_index + 1) % _selected_frames.size()
	_preview_rect.texture = ImageTexture.create_from_image(_selected_frames[_anim_frame_index])
```

- [ ] **Step 5 : Vérifier la compilation**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . --import 2>&1 | grep -E "ERROR|SCRIPT ERROR|Parse Error"
```

Attendu : aucune erreur.

- [ ] **Step 6 : Commit**

```bash
cd plugins/ai_studio && git add ai_studio_wan_vace_tab.gd && git commit -m "feat: tab sections 2+3 — results grid, preview, selection spinboxes"
cd ../.. && git add plugins/ai_studio && git commit -m "feat: wan vace tab sections 2+3"
```

---

## Task 5 : Tab — section 4 (BiRefNet batch)

**Files:**
- Modify: `plugins/ai_studio/ai_studio_wan_vace_tab.gd`

- [ ] **Step 1 : Ajouter la section 4 dans `build_tab()`**

À la fin du bloc `_results_section` dans `build_tab()`, juste avant la ligne qui ajoute `_preview_timer`, ajouter :

```gdscript
	# ── Section 4 : Fond transparent ─────────────────────────
	_results_section.add_child(HSeparator.new())

	var bg_title := Label.new()
	bg_title.text = "── Fond transparent ──"
	_results_section.add_child(bg_title)

	var bg_hbox := HBoxContainer.new()
	bg_hbox.add_theme_constant_override("separation", 8)
	_results_section.add_child(bg_hbox)

	_bg_btn = Button.new()
	_bg_btn.text = "Appliquer BiRefNet sur sélection"
	_bg_btn.disabled = true
	_bg_btn.pressed.connect(_on_apply_birefnet)
	bg_hbox.add_child(_bg_btn)

	_bg_progress_label = Label.new()
	_bg_progress_label.text = ""
	_bg_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg_hbox.add_child(_bg_progress_label)
```

- [ ] **Step 2 : Ajouter `_on_apply_birefnet()` — démarre le batch**

```gdscript
func _on_apply_birefnet() -> void:
	if _selected_frames.is_empty():
		return
	_birefnet_index = 0
	_bg_progress_label.text = "0/%d frames..." % _selected_frames.size()
	_set_state(STATE_BG_PROCESSING)
	_show_status("BiRefNet en cours...")
	_birefnet_client = Node.new()
	_birefnet_client.set_script(ComfyUIClient)
	_parent_window.add_child(_birefnet_client)
	_birefnet_client.generation_completed.connect(_on_birefnet_frame_done)
	_birefnet_client.generation_failed.connect(_on_birefnet_failed)
	var config = _get_config_fn.call()
	_birefnet_client.apply_birefnet(config, _selected_frames[0])
```

- [ ] **Step 3 : Ajouter `_on_birefnet_frame_done()` — traite chaque frame**

```gdscript
func _on_birefnet_frame_done(processed: Image) -> void:
	# Remplacer dans selected_frames et all_frames
	_selected_frames[_birefnet_index] = processed
	var all_idx: int = _selected_all_indices[_birefnet_index]
	_all_frames[all_idx] = processed

	# Mettre à jour le thumbnail dans la grille
	if _grid_textures.has(all_idx):
		_grid_textures[all_idx].texture = ImageTexture.create_from_image(processed)

	_birefnet_index += 1
	_bg_progress_label.text = "%d/%d frames..." % [_birefnet_index, _selected_frames.size()]

	if _birefnet_index < _selected_frames.size():
		# Prochaine frame
		var config = _get_config_fn.call()
		_birefnet_client.apply_birefnet(config, _selected_frames[_birefnet_index])
	else:
		# Batch terminé
		_birefnet_client.queue_free()
		_birefnet_client = null
		_bg_progress_label.text = "✓ %d frames traitées" % _selected_frames.size()
		_set_state(STATE_FRAMES_READY)
		_show_success("BiRefNet appliqué (%d frames)" % _selected_frames.size())
		_start_preview()
```

- [ ] **Step 4 : Ajouter `_on_birefnet_failed()`**

```gdscript
func _on_birefnet_failed(error: String) -> void:
	_show_error("BiRefNet erreur frame %d : %s" % [_birefnet_index + 1, error])
	if _birefnet_client != null:
		_birefnet_client.queue_free()
		_birefnet_client = null
	_bg_progress_label.text = "Erreur frame %d" % (_birefnet_index + 1)
	_set_state(STATE_FRAMES_READY)
```

- [ ] **Step 5 : Vérifier la compilation**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . --import 2>&1 | grep -E "ERROR|SCRIPT ERROR|Parse Error"
```

Attendu : aucune erreur.

- [ ] **Step 6 : Commit**

```bash
cd plugins/ai_studio && git add ai_studio_wan_vace_tab.gd && git commit -m "feat: tab section 4 — BiRefNet batch sequential"
cd ../.. && git add plugins/ai_studio && git commit -m "feat: wan vace tab section 4 birefnet batch"
```

---

## Task 6 : Tab — section 5 (export) + wiring final

**Files:**
- Modify: `plugins/ai_studio/ai_studio_wan_vace_tab.gd`

- [ ] **Step 1 : Ajouter la section 5 dans `build_tab()`**

Après `_results_section` dans `build_tab()`, ajouter une section export autonome hors de `_results_section` (elle est ajoutée à `vbox` directement) :

```gdscript
	# ── Section 5 : Export ───────────────────────────────────
	_export_panel = VBoxContainer.new()
	_export_panel.visible = false
	_export_panel.add_theme_constant_override("separation", 6)
	vbox.add_child(_export_panel)

	_export_panel.add_child(HSeparator.new())

	var export_title := Label.new()
	export_title.text = "── Export ──"
	_export_panel.add_child(export_title)

	var frames_export_hbox := HBoxContainer.new()
	frames_export_hbox.add_theme_constant_override("separation", 6)
	_export_panel.add_child(frames_export_hbox)

	var prefix_lbl := Label.new()
	prefix_lbl.text = "Préfixe :"
	prefix_lbl.custom_minimum_size.x = 64
	frames_export_hbox.add_child(prefix_lbl)

	_export_prefix_input = LineEdit.new()
	_export_prefix_input.placeholder_text = "wan_vace"
	_export_prefix_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frames_export_hbox.add_child(_export_prefix_input)

	_export_frames_btn = Button.new()
	_export_frames_btn.text = "→ foregrounds"
	_export_frames_btn.disabled = true
	_export_frames_btn.pressed.connect(_on_export_frames)
	frames_export_hbox.add_child(_export_frames_btn)

	var apng_hbox := HBoxContainer.new()
	apng_hbox.add_theme_constant_override("separation", 6)
	_export_panel.add_child(apng_hbox)

	var apng_lbl := Label.new()
	apng_lbl.text = "Nom APNG :"
	apng_lbl.custom_minimum_size.x = 64
	apng_hbox.add_child(apng_lbl)

	_export_name_input = LineEdit.new()
	_export_name_input.placeholder_text = "animation"
	_export_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apng_hbox.add_child(_export_name_input)

	_export_apng_btn = Button.new()
	_export_apng_btn.text = "→ animations"
	_export_apng_btn.disabled = true
	_export_apng_btn.pressed.connect(_on_export_apng)
	apng_hbox.add_child(_export_apng_btn)
```

- [ ] **Step 2 : Ajouter `_on_export_frames()` (utilise `_selected_frames`)**

```gdscript
const ApngBuilderClass = preload("res://src/services/apng_builder.gd")

func _on_export_frames() -> void:
	if _story_base_path == "":
		_show_error("Aucune story chargée.")
		return
	if _selected_frames.is_empty():
		_show_error("Aucune frame sélectionnée.")
		return
	var prefix := _export_prefix_input.text.strip_edges()
	if prefix == "":
		prefix = "wan_vace"
	var format_error := ImageRenameService.validate_name_format(prefix)
	if format_error != "":
		_show_error(format_error)
		return
	var dir_path := _story_base_path + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir_path)
	for i in range(_selected_frames.size()):
		var file_path := dir_path + "/%s_%04d.png" % [prefix, i + 1]
		(_selected_frames[i] as Image).save_png(file_path)
	GalleryCacheService.clear_dir(dir_path)
	_show_success("%d frame(s) exportée(s) → foregrounds/" % _selected_frames.size())
```

- [ ] **Step 3 : Ajouter `_on_export_apng()` (utilise `_selected_frames` + fps correct)**

```gdscript
func _on_export_apng() -> void:
	if _story_base_path == "":
		_show_error("Aucune story chargée.")
		return
	if _selected_frames.is_empty():
		_show_error("Aucune frame sélectionnée.")
		return
	var anim_name := _export_name_input.text.strip_edges()
	if anim_name == "":
		anim_name = "animation"
	var format_error := ImageRenameService.validate_name_format(anim_name)
	if format_error != "":
		_show_error(format_error)
		return
	var dir_path := _story_base_path + "/assets/animations"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file_path := dir_path + "/" + anim_name + ".apng"
	var apng_bytes := ApngBuilderClass.build(_selected_frames, int(_fps_slider.value))
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(apng_bytes)
		f.close()
		_show_success("APNG exporté → animations/" + anim_name + ".apng")
	else:
		_show_error("Impossible d'écrire : " + file_path)
```

- [ ] **Step 4 : Vérifier la compilation complète**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . --import 2>&1 | grep -E "ERROR|SCRIPT ERROR|Parse Error"
```

Attendu : aucune erreur.

- [ ] **Step 5 : Lancer les tests spécifiques**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client.gd -glog=2 2>&1 | tail -5
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_apng_builder.gd -glog=2 2>&1 | tail -5
```

Attendu : tous les tests PASS.

- [ ] **Step 6 : Commit final**

```bash
cd plugins/ai_studio && git add ai_studio_wan_vace_tab.gd && git commit -m "feat: tab sections 5 + wiring — export uses selected_frames"
cd ../.. && git add plugins/ai_studio src/services/comfyui_client.gd specs/services/test_comfyui_client.gd
git commit -m "feat: wan vace tab redesign — 5 sections progressives, BiRefNet batch, sous-échantillonnage"
```
