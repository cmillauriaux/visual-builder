# Inpaint Tab (Flux Fill) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer le workflow d'inpainting cassé (basé sur Flux2 Klein) par un onglet "Inpaint" dédié utilisant Flux Fill (`flux1-fill-dev.safetensors`), et reverter l'onglet Décliner à son état d'origine.

**Architecture:** Nouveau `INPAINT_FILL_WORKFLOW_TEMPLATE` basé sur `OUTPAINT_WORKFLOW_TEMPLATE` (Flux Fill + InpaintModelConditioning + DifferentialDiffusion) sans `ImagePadForOutpaint`. Nouvel onglet `ai_studio_inpaint_tab.gd` avec dessin de masque rectangulaire. L'onglet Décliner est complètement reverté (suppression de toute la section masque).

**Tech Stack:** GDScript (Godot 4.6.1), GUT 9.3.0, ComfyUI workflow JSON, Flux Fill model

---

## File Structure

| Fichier | Action | Responsabilité |
|---------|--------|----------------|
| `src/services/comfyui_client.gd` | Modifier | `INPAINT_FILL_WORKFLOW_TEMPLATE`, réécriture `_build_inpaint_workflow`, ajout `_inpaint_guidance` + `generate_inpaint()` |
| `specs/services/test_comfyui_client.gd` | Modifier | Remplacer 10 anciens tests inpaint par 10 tests Flux Fill |
| `plugins/ai_studio/ai_studio_inpaint_tab.gd` | CRÉER | Onglet Inpaint complet avec masque interactif |
| `plugins/ai_studio/ai_studio_dialog.gd` | Modifier | Enregistrer le nouvel onglet |
| `plugins/ai_studio/ai_studio_decliner_tab.gd` | Modifier | Revert complet de la section masque |

---

## Task 1 : `comfyui_client.gd` — Flux Fill inpainting (TDD)

**Files:**
- Modify: `specs/services/test_comfyui_client.gd`
- Modify: `src/services/comfyui_client.gd`

- [ ] **Step 1 : Remplacer les 10 anciens tests inpaint par les 10 nouveaux tests Flux Fill**

Dans `specs/services/test_comfyui_client.gd`, remplacer les fonctions suivantes (lignes 289–373) :
- `test_build_inpaint_workflow_has_mask_loader`
- `test_build_inpaint_workflow_has_set_noise_mask`
- `test_build_inpaint_workflow_has_split_sigmas`
- `test_build_inpaint_workflow_no_face_detection`
- `test_build_inpaint_workflow_no_feather_removes_blur`
- `test_build_inpaint_workflow_with_feather_has_blur`
- `test_build_inpaint_workflow_no_bg_removal`
- `test_build_inpaint_workflow_has_mask_convert`
- `test_build_inpaint_workflow_no_reference_latent`
- `test_build_inpaint_workflow_negative_prompt_no_crash`

Par ces 10 nouvelles fonctions :

```gdscript
func test_build_inpaint_fill_workflow_has_ksampler():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_true(wf.has("3"), "KSampler absent")
	assert_eq(wf["3"]["class_type"], "KSampler")


func test_build_inpaint_fill_workflow_uses_flux_fill_model():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_true(wf.has("31"), "UNETLoader absent")
	assert_eq(wf["31"]["inputs"]["unet_name"], "flux1-fill-dev.safetensors")


func test_build_inpaint_fill_workflow_has_inpaint_model_conditioning():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_true(wf.has("38"), "InpaintModelConditioning absent")
	assert_eq(wf["38"]["class_type"], "InpaintModelConditioning")


func test_build_inpaint_fill_workflow_no_image_pad():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_false(wf.has("44"), "ImagePadForOutpaint présent (doit être absent)")


func test_build_inpaint_fill_workflow_sets_denoise():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 0.75, "", 0, 1.0, [])
	assert_eq(wf["3"]["inputs"]["denoise"], 0.75)


func test_build_inpaint_fill_workflow_has_mask_loader():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask_test.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_true(wf.has("ip:mask"), "ip:mask absent")
	assert_eq(wf["ip:mask"]["inputs"]["image"], "mask_test.png")


func test_build_inpaint_fill_workflow_has_mask_convert():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_true(wf.has("ip:mask_convert"), "ip:mask_convert absent")
	assert_eq(wf["ip:mask_convert"]["class_type"], "ImageToMask")
	assert_eq(wf["ip:mask_convert"]["inputs"]["channel"], "red")


func test_build_inpaint_fill_workflow_no_feather_removes_blur():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 0
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_false(wf.has("ip:blur"), "ip:blur présent alors que feather=0")
	assert_eq(wf["38"]["inputs"]["mask"][0], "ip:grow")


func test_build_inpaint_fill_workflow_with_feather_has_blur():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 20
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_true(wf.has("ip:blur"), "ip:blur absent alors que feather=20")
	assert_eq(wf["38"]["inputs"]["mask"][0], "ip:blur")


func test_build_inpaint_fill_workflow_negative_prompt():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "bad quality", 0, 1.0, [])
	assert_true(wf.has("47"), "CLIPTextEncode négatif absent")
	assert_eq(wf["47"]["inputs"]["text"], "bad quality")
	assert_eq(wf["38"]["inputs"]["negative"], ["47", 0])
	assert_false(wf.has("46"), "ConditioningZeroOut doit être effacé")
```

- [ ] **Step 2 : Vérifier que les tests échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_comfyui_client.gd 2>&1 | tail -30
```

Résultat attendu : les 10 nouveaux tests échouent (`_inpaint_guidance` n'existe pas encore).

- [ ] **Step 3 : Ajouter `var _inpaint_guidance: float = 30.0` dans `comfyui_client.gd`**

Dans `src/services/comfyui_client.gd`, après la ligne `var _mask_bytes_data: PackedByteArray = PackedByteArray()` (ligne ~54) :

```gdscript
var _mask_bytes_data: PackedByteArray = PackedByteArray()
var _inpaint_guidance: float = 30.0
```

- [ ] **Step 4 : Ajouter `INPAINT_FILL_WORKFLOW_TEMPLATE` dans `comfyui_client.gd`**

Après le bloc `OUTPAINT_WORKFLOW_TEMPLATE` (après la ligne `}` qui ferme ce const, vers la ligne ~537), ajouter :

```gdscript
# --- Inpainting workflow template (Flux Fill + masque utilisateur) ---
# Basé sur OUTPAINT_WORKFLOW_TEMPLATE sans ImagePadForOutpaint (nœud 44).
# L'image source est câblée directement dans InpaintModelConditioning.pixels.
# Le masque PNG généré par l'utilisateur est injecté dynamiquement.
# Paramètres dynamiques : 17.inputs.image, 23.inputs.text, 3.inputs.seed/steps/denoise,
#                         26.inputs.guidance, 38.inputs.mask=[final_mask_node,0]

const INPAINT_FILL_WORKFLOW_TEMPLATE: Dictionary = {
	"3": {
		"class_type": "KSampler",
		"inputs": {
			"seed": 0,
			"steps": 20,
			"cfg": 0.7,
			"sampler_name": "euler",
			"scheduler": "normal",
			"denoise": 1.0,
			"model": ["39", 0],
			"positive": ["38", 0],
			"negative": ["38", 1],
			"latent_image": ["38", 2]
		}
	},
	"8": {
		"class_type": "VAEDecode",
		"inputs": {
			"samples": ["3", 0],
			"vae": ["32", 0]
		}
	},
	"9": {
		"class_type": "SaveImage",
		"inputs": {
			"filename_prefix": "Inpaint",
			"images": ["8", 0]
		}
	},
	"17": {
		"class_type": "LoadImage",
		"inputs": {
			"image": ""
		}
	},
	"23": {
		"class_type": "CLIPTextEncode",
		"inputs": {
			"text": "",
			"clip": ["34", 0]
		}
	},
	"26": {
		"class_type": "FluxGuidance",
		"inputs": {
			"guidance": 30.0,
			"conditioning": ["23", 0]
		}
	},
	"31": {
		"class_type": "UNETLoader",
		"inputs": {
			"unet_name": "flux1-fill-dev.safetensors",
			"weight_dtype": "default"
		}
	},
	"32": {
		"class_type": "VAELoader",
		"inputs": {
			"vae_name": "ae.safetensors"
		}
	},
	"34": {
		"class_type": "DualCLIPLoader",
		"inputs": {
			"clip_name1": "clip_l.safetensors",
			"clip_name2": "t5xxl_fp16.safetensors",
			"type": "flux",
			"device": "default"
		}
	},
	"38": {
		"class_type": "InpaintModelConditioning",
		"inputs": {
			"noise_mask": false,
			"positive": ["26", 0],
			"negative": ["46", 0],
			"vae": ["32", 0],
			"pixels": ["17", 0],
			"mask": ["ip:blur", 0]
		}
	},
	"39": {
		"class_type": "DifferentialDiffusion",
		"inputs": {
			"strength": 1,
			"model": ["31", 0]
		}
	},
	"46": {
		"class_type": "ConditioningZeroOut",
		"inputs": {
			"conditioning": ["23", 0]
		}
	}
}
```

- [ ] **Step 5 : Remplacer `_build_inpaint_workflow` par la version Flux Fill**

Dans `src/services/comfyui_client.gd`, remplacer la fonction `_build_inpaint_workflow` entière (de la ligne `func _build_inpaint_workflow(...)` jusqu'au `return wf` final inclus) par :

```gdscript
func _build_inpaint_workflow(filename: String, mask_filename: String, prompt_text: String, seed: int, guidance: float, steps: int, denoise: float, negative_prompt: String, mask_feather: int) -> Dictionary:
	var wf = INPAINT_FILL_WORKFLOW_TEMPLATE.duplicate(true)
	wf["17"]["inputs"]["image"] = filename
	wf["23"]["inputs"]["text"] = prompt_text
	wf["3"]["inputs"]["seed"] = seed
	wf["3"]["inputs"]["steps"] = steps
	wf["3"]["inputs"]["denoise"] = denoise
	wf["26"]["inputs"]["guidance"] = guidance

	wf["ip:mask"] = {
		"class_type": "LoadImage",
		"inputs": {"image": mask_filename}
	}
	wf["ip:mask_convert"] = {
		"class_type": "ImageToMask",
		"inputs": {"image": ["ip:mask", 0], "channel": "red"}
	}
	wf["ip:grow"] = {
		"class_type": "GrowMask",
		"inputs": {"expand": mask_feather, "tapered_corners": true, "mask": ["ip:mask_convert", 0]}
	}

	var final_mask_node: String
	if mask_feather <= 0:
		final_mask_node = "ip:grow"
	else:
		var blur_kernel: int = min(99, max(3, mask_feather)) | 1
		var blur_sigma: float = minf(50.0, maxf(1.0, mask_feather * 0.5))
		wf["ip:blur"] = {
			"class_type": "ImpactGaussianBlurMask",
			"inputs": {"kernel_size": blur_kernel, "sigma": blur_sigma, "mask": ["ip:grow", 0]}
		}
		final_mask_node = "ip:blur"

	wf["38"]["inputs"]["mask"] = [final_mask_node, 0]

	if negative_prompt.strip_edges() != "":
		wf["47"] = {
			"class_type": "CLIPTextEncode",
			"inputs": {"text": negative_prompt, "clip": ["34", 0]}
		}
		wf["38"]["inputs"]["negative"] = ["47", 0]
		wf.erase("46")

	if _debug_mask:
		wf["debug_mask_to_image"] = {
			"class_type": "MaskToImage",
			"inputs": {"mask": [final_mask_node, 0]}
		}
		wf["9"]["inputs"]["images"] = ["debug_mask_to_image", 0]

	return wf
```

- [ ] **Step 6 : Mettre à jour le dispatch `WorkflowType.INPAINT` dans `build_workflow`**

Dans `src/services/comfyui_client.gd`, remplacer la ligne :

```gdscript
	if workflow_type == WorkflowType.INPAINT:
		return _build_inpaint_workflow(filename, _mask_filename, prompt_text, seed, remove_background, cfg, steps, denoise, negative_prompt, _mask_feather, megapixels, loras)
```

par :

```gdscript
	if workflow_type == WorkflowType.INPAINT:
		return _build_inpaint_workflow(filename, _mask_filename, prompt_text, seed, _inpaint_guidance, steps, denoise, negative_prompt, _mask_feather)
```

- [ ] **Step 7 : Ajouter `generate_inpaint()` après `generate_outpaint()`**

Dans `src/services/comfyui_client.gd`, après la fonction `generate_outpaint` (après sa ligne de fermeture `}`), ajouter :

```gdscript
func generate_inpaint(config: RefCounted, source_image_path: String, prompt_text: String, mask_bytes: PackedByteArray, mask_feather: int, guidance: float, steps: int, denoise: float, negative_prompt: String) -> void:
	if _generating:
		_fail("Une génération est déjà en cours")
		return

	_generating = true
	_cancelled = false
	_config = config
	_workflow_type = WorkflowType.INPAINT
	_steps = steps
	_denoise = denoise
	_negative_prompt = negative_prompt
	_remove_background = false
	_megapixels = 1.0
	_loras = []
	_inpaint_guidance = guidance
	_mask_filename = "inpaint_mask_%d.png" % randi()
	_mask_bytes_data = mask_bytes
	_mask_feather = mask_feather

	generation_progress.emit("Chargement de l'image source...")

	var file = FileAccess.open(source_image_path, FileAccess.READ)
	if file == null:
		_generating = false
		_fail("Impossible d'ouvrir l'image : " + source_image_path)
		return
	var file_bytes = file.get_buffer(file.get_length())
	file.close()
	var filename = source_image_path.get_file()

	if _config.is_runpod():
		generation_progress.emit("Envoi vers RunPod...")
		_do_runpod_run(filename, file_bytes, prompt_text)
	else:
		generation_progress.emit("Upload de l'image vers ComfyUI...")
		_do_upload(filename, file_bytes, prompt_text)
```

- [ ] **Step 8 : Lancer les tests et vérifier qu'ils passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_comfyui_client.gd 2>&1 | tail -20
```

Résultat attendu : 10 nouveaux tests PASS, 0 FAIL.

- [ ] **Step 9 : Commit**

```bash
git add src/services/comfyui_client.gd specs/services/test_comfyui_client.gd
git commit -m "feat: rewrite inpaint workflow using Flux Fill (INPAINT_FILL_WORKFLOW_TEMPLATE)"
```

---

## Task 2 : Créer `ai_studio_inpaint_tab.gd`

**Files:**
- Create: `plugins/ai_studio/ai_studio_inpaint_tab.gd`

- [ ] **Step 1 : Créer le fichier `ai_studio_inpaint_tab.gd`**

Créer `plugins/ai_studio/ai_studio_inpaint_tab.gd` avec le contenu complet suivant :

```gdscript
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")
const ImageFileDialog = preload("res://src/ui/shared/image_file_dialog.gd")
const ImageRenameService = preload("res://src/services/image_rename_service.gd")

# Shared refs (set via initialize)
var _parent_window: Window
var _get_config_fn: Callable
var _neg_input: TextEdit
var _show_preview_fn: Callable
var _open_gallery_fn: Callable
var _save_config_fn: Callable
var _resolve_path_fn: Callable
var _story_base_path: String = ""

# UI widgets
var _source_preview: TextureRect
var _source_path_label: Label
var _choose_source_btn: Button
var _choose_gallery_btn: Button
var _mask_overlay: Panel
var _preview_wrapper: Control
var _mask_coords_label: Label
var _mask_clear_btn: Button
var _mask_feather_slider: HSlider
var _mask_feather_value_label: Label
var _mask_debug_checkbox: CheckBox
var _prompt_input: TextEdit
var _guidance_slider: HSlider
var _guidance_value_label: Label
var _steps_slider: HSlider
var _steps_value_label: Label
var _denoise_slider: HSlider
var _denoise_value_label: Label
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
var _mask_rect: Rect2i = Rect2i()
var _mask_drawing: bool = false
var _mask_draw_start: Vector2 = Vector2.ZERO
var _source_image_size: Vector2i = Vector2i.ZERO


func initialize(
	parent_window: Window,
	get_config_fn: Callable,
	neg_input: TextEdit,
	show_preview_fn: Callable,
	open_gallery_fn: Callable,
	save_config_fn: Callable,
	resolve_path_fn: Callable
) -> void:
	_parent_window = parent_window
	_get_config_fn = get_config_fn
	_neg_input = neg_input
	_show_preview_fn = show_preview_fn
	_open_gallery_fn = open_gallery_fn
	_save_config_fn = save_config_fn
	_resolve_path_fn = resolve_path_fn


func build_tab(tab_container: TabContainer) -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "Inpaint"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# Image source
	var source_label = Label.new()
	source_label.text = "Image source :"
	vbox.add_child(source_label)

	var source_hbox = HBoxContainer.new()
	vbox.add_child(source_hbox)

	_preview_wrapper = Control.new()
	_preview_wrapper.custom_minimum_size = Vector2(128, 96)
	_preview_wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_preview_wrapper.clip_contents = true
	source_hbox.add_child(_preview_wrapper)

	_source_preview = TextureRect.new()
	_source_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_source_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_source_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_source_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_source_preview.gui_input.connect(func(event: InputEvent):
		if _source_preview.texture != null:
			_handle_mask_input(event)
	)
	_preview_wrapper.add_child(_source_preview)

	_mask_overlay = Panel.new()
	_mask_overlay.visible = false
	_mask_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask_style = StyleBoxFlat.new()
	mask_style.bg_color = Color(0.2, 0.6, 1.0, 0.15)
	mask_style.border_width_left = 2
	mask_style.border_width_right = 2
	mask_style.border_width_top = 2
	mask_style.border_width_bottom = 2
	mask_style.border_color = Color(0.3, 0.7, 1.0, 1.0)
	_mask_overlay.add_theme_stylebox_override("panel", mask_style)
	_preview_wrapper.add_child(_mask_overlay)

	var source_info = VBoxContainer.new()
	source_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_hbox.add_child(source_info)

	_source_path_label = Label.new()
	_source_path_label.text = "Aucune image sélectionnée"
	_source_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_path_label.clip_text = true
	source_info.add_child(_source_path_label)

	var btn_hbox = HBoxContainer.new()
	source_info.add_child(btn_hbox)

	_choose_source_btn = Button.new()
	_choose_source_btn.text = "Parcourir..."
	_choose_source_btn.pressed.connect(_on_choose_source)
	btn_hbox.add_child(_choose_source_btn)

	_choose_gallery_btn = Button.new()
	_choose_gallery_btn.text = "Galerie..."
	_choose_gallery_btn.pressed.connect(_on_choose_from_gallery)
	btn_hbox.add_child(_choose_gallery_btn)

	# Mask section
	vbox.add_child(HSeparator.new())
	var mask_title = Label.new()
	mask_title.text = "Masque (clique-glisse sur l'aperçu) :"
	vbox.add_child(mask_title)

	var mask_coords_row = HBoxContainer.new()
	mask_coords_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mask_coords_row)

	var zone_lbl = Label.new()
	zone_lbl.text = "Zone :"
	mask_coords_row.add_child(zone_lbl)

	_mask_coords_label = Label.new()
	_mask_coords_label.text = "—"
	_mask_coords_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mask_coords_row.add_child(_mask_coords_label)

	_mask_clear_btn = Button.new()
	_mask_clear_btn.text = "Effacer"
	_mask_clear_btn.pressed.connect(func():
		_mask_rect = Rect2i()
		_update_mask_overlay()
		_update_mask_coords_label()
		_update_generate_button()
	)
	mask_coords_row.add_child(_mask_clear_btn)

	var feather_row = HBoxContainer.new()
	feather_row.add_theme_constant_override("separation", 8)
	vbox.add_child(feather_row)

	var feather_lbl = Label.new()
	feather_lbl.text = "Fondu :"
	feather_row.add_child(feather_lbl)

	_mask_feather_slider = HSlider.new()
	_mask_feather_slider.min_value = 0
	_mask_feather_slider.max_value = 100
	_mask_feather_slider.step = 1
	_mask_feather_slider.value = 15
	_mask_feather_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mask_feather_slider.value_changed.connect(func(val: float): _mask_feather_value_label.text = str(int(val)))
	feather_row.add_child(_mask_feather_slider)

	_mask_feather_value_label = Label.new()
	_mask_feather_value_label.text = "15"
	_mask_feather_value_label.custom_minimum_size.x = 28
	feather_row.add_child(_mask_feather_value_label)

	_mask_debug_checkbox = CheckBox.new()
	_mask_debug_checkbox.text = "Debug mask"
	vbox.add_child(_mask_debug_checkbox)

	# Prompt
	vbox.add_child(HSeparator.new())
	var prompt_label = Label.new()
	prompt_label.text = "Prompt :"
	vbox.add_child(prompt_label)

	_prompt_input = TextEdit.new()
	_prompt_input.custom_minimum_size.y = 60
	_prompt_input.placeholder_text = "Décrivez le contenu à générer dans la zone masquée..."
	_prompt_input.text_changed.connect(func(): _update_generate_button())
	vbox.add_child(_prompt_input)

	# Guidance slider
	var guidance_hbox = HBoxContainer.new()
	guidance_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(guidance_hbox)

	var guidance_label = Label.new()
	guidance_label.text = "Guidance :"
	guidance_hbox.add_child(guidance_label)

	_guidance_slider = HSlider.new()
	_guidance_slider.min_value = 1.0
	_guidance_slider.max_value = 100.0
	_guidance_slider.step = 0.5
	_guidance_slider.value = 30.0
	_guidance_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guidance_slider.value_changed.connect(func(val: float): _guidance_value_label.text = str(val))
	guidance_hbox.add_child(_guidance_slider)

	_guidance_value_label = Label.new()
	_guidance_value_label.text = "30.0"
	_guidance_value_label.custom_minimum_size.x = 36
	guidance_hbox.add_child(_guidance_value_label)

	# Steps slider
	var steps_hbox = HBoxContainer.new()
	steps_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(steps_hbox)

	var steps_label = Label.new()
	steps_label.text = "Steps :"
	steps_hbox.add_child(steps_label)

	_steps_slider = HSlider.new()
	_steps_slider.min_value = 1
	_steps_slider.max_value = 50
	_steps_slider.step = 1
	_steps_slider.value = 20
	_steps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steps_slider.value_changed.connect(func(val: float): _steps_value_label.text = str(int(val)))
	steps_hbox.add_child(_steps_slider)

	_steps_value_label = Label.new()
	_steps_value_label.text = "20"
	_steps_value_label.custom_minimum_size.x = 32
	steps_hbox.add_child(_steps_value_label)

	# Denoise slider
	var denoise_hbox = HBoxContainer.new()
	denoise_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(denoise_hbox)

	var denoise_label = Label.new()
	denoise_label.text = "Denoise :"
	denoise_hbox.add_child(denoise_label)

	_denoise_slider = HSlider.new()
	_denoise_slider.min_value = 0.05
	_denoise_slider.max_value = 1.0
	_denoise_slider.step = 0.05
	_denoise_slider.value = 1.0
	_denoise_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_denoise_slider.value_changed.connect(func(val: float): _denoise_value_label.text = "%.2f" % val)
	denoise_hbox.add_child(_denoise_slider)

	_denoise_value_label = Label.new()
	_denoise_value_label.text = "1.00"
	_denoise_value_label.custom_minimum_size.x = 36
	denoise_hbox.add_child(_denoise_value_label)

	# Generate button
	vbox.add_child(HSeparator.new())
	_generate_btn = Button.new()
	_generate_btn.text = "GÉNÉRER"
	_generate_btn.disabled = true
	_generate_btn.pressed.connect(_on_generate_pressed)
	vbox.add_child(_generate_btn)

	# Result section
	_result_preview = TextureRect.new()
	_result_preview.custom_minimum_size = Vector2(0, 128)
	_result_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_result_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_result_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_result_preview)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.indeterminate = true
	_progress_bar.visible = false
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_progress_bar)

	var save_row = HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 8)
	vbox.add_child(save_row)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Nom du fichier (sans extension)"
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.editable = false
	save_row.add_child(_name_input)

	_save_btn = Button.new()
	_save_btn.text = "Sauvegarder"
	_save_btn.disabled = true
	_save_btn.pressed.connect(_on_save_pressed)
	save_row.add_child(_save_btn)

	_regenerate_btn = Button.new()
	_regenerate_btn.text = "Régénérer"
	_regenerate_btn.disabled = true
	_regenerate_btn.pressed.connect(_on_generate_pressed)
	save_row.add_child(_regenerate_btn)


func setup(story_base_path: String, has_story: bool) -> void:
	_story_base_path = story_base_path
	_choose_gallery_btn.disabled = not has_story


func update_generate_button() -> void:
	_update_generate_button()


func update_cfg_hint(_has_negative: bool) -> void:
	pass


func cancel_generation() -> void:
	if _client != null:
		_client.cancel()
		_client.queue_free()
		_client = null


# ========================================================
# Private logic
# ========================================================

func _update_generate_button() -> void:
	if _generate_btn == null:
		return
	var has_url = _get_config_fn.call().get_url() != ""
	var has_source = _source_image_path != ""
	var has_mask = _mask_rect.size.x > 0 and _mask_rect.size.y > 0
	_generate_btn.disabled = not (has_url and has_source and has_mask)


func _on_choose_source() -> void:
	var dialog = ImageFileDialog.new()
	dialog.file_selected.connect(func(path: String):
		_source_image_path = path
		_source_path_label.text = path.get_file()
		_load_source_preview(path)
		_update_generate_button()
	)
	_parent_window.add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))


func _on_choose_from_gallery() -> void:
	_open_gallery_fn.call(func(path: String):
		_source_image_path = path
		_source_path_label.text = path.get_file()
		_load_source_preview(path)
		_update_generate_button()
	)


func _on_generate_pressed() -> void:
	_save_config_fn.call()

	if _client != null:
		_client.cancel()
		_client.queue_free()

	_client = Node.new()
	_client.set_script(ComfyUIClient)
	_parent_window.add_child(_client)

	_client.generation_completed.connect(_on_generation_completed)
	_client.generation_failed.connect(_on_generation_failed)
	_client.generation_progress.connect(_on_generation_progress)

	_generate_btn.disabled = true
	_save_btn.disabled = true
	_regenerate_btn.disabled = true
	_generated_image = null
	_result_preview.texture = null
	_name_input.text = ""
	_name_input.editable = false
	_set_inputs_enabled(false)
	_show_status("Lancement...")

	var config = _get_config_fn.call()
	var neg_prompt = _neg_input.text.strip_edges()
	var mask_bytes = ComfyUIClient.build_mask_bytes(_mask_rect, _source_image_size.x, _source_image_size.y)

	_client._debug_mask = _mask_debug_checkbox.button_pressed

	_client.generate_inpaint(
		config,
		_source_image_path,
		_prompt_input.text,
		mask_bytes,
		int(_mask_feather_slider.value),
		_guidance_slider.value,
		int(_steps_slider.value),
		_denoise_slider.value,
		neg_prompt
	)


func _on_generation_completed(image: Image) -> void:
	_generated_image = image
	var tex = ImageTexture.create_from_image(image)
	_result_preview.texture = tex
	_show_success("Génération terminée !")
	var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	_name_input.text = "ai_inpaint_" + timestamp
	_name_input.editable = true
	_save_btn.disabled = false
	_regenerate_btn.disabled = false
	_set_inputs_enabled(true)
	_update_generate_button()


func _on_generation_failed(error: String) -> void:
	_show_error("Erreur : " + error)
	_regenerate_btn.disabled = false
	_set_inputs_enabled(true)
	_update_generate_button()


func _on_generation_progress(status: String) -> void:
	_show_status(status)


func _on_save_pressed() -> void:
	if _generated_image == null:
		return

	var img_name = _name_input.text.strip_edges()
	if img_name == "":
		var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
		img_name = "ai_inpaint_" + timestamp

	var format_error = ImageRenameService.validate_name_format(img_name)
	if format_error != "":
		_show_error(format_error)
		return

	var dir_path = _story_base_path + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file_path = dir_path + "/" + img_name + ".png"

	if FileAccess.file_exists(file_path):
		var dialog = ConfirmationDialog.new()
		dialog.dialog_text = "L'image « %s » existe déjà.\nVoulez-vous l'écraser ?" % file_path.get_file()
		dialog.ok_button_text = "Écraser"
		_parent_window.add_child(dialog)
		dialog.confirmed.connect(func():
			_do_save(file_path, dir_path)
			dialog.queue_free()
		)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered()
		return

	_do_save(file_path, dir_path)


func _do_save(file_path: String, dir_path: String) -> void:
	_generated_image.save_png(file_path)
	GalleryCacheService.clear_dir(dir_path)
	_show_success("Image sauvegardée : " + file_path.get_file())
	_generated_image = null
	_result_preview.texture = null
	_name_input.text = ""
	_name_input.editable = false
	_save_btn.disabled = true


func _show_status(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_progress_bar.visible = true


func _show_success(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_progress_bar.visible = false


func _show_error(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_progress_bar.visible = false


func _set_inputs_enabled(enabled: bool) -> void:
	_neg_input.editable = enabled
	_prompt_input.editable = enabled
	_choose_source_btn.disabled = not enabled
	_choose_gallery_btn.disabled = not enabled
	_mask_clear_btn.disabled = not enabled
	_mask_debug_checkbox.disabled = not enabled


func _load_source_preview(path: String) -> void:
	if path == "":
		_source_preview.texture = null
		return
	var img = Image.new()
	if img.load(path) == OK:
		_source_preview.texture = ImageTexture.create_from_image(img)
		_source_image_size = Vector2i(img.get_width(), img.get_height())
		_mask_rect = Rect2i()
		_update_mask_overlay()
		_update_mask_coords_label()
	else:
		_source_preview.texture = null


func _handle_mask_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mask_drawing = true
			_mask_draw_start = event.position
			_mask_rect = Rect2i()
			_update_mask_overlay()
			_update_mask_coords_label()
		else:
			_mask_drawing = false
			_update_generate_button()
	elif event is InputEventMouseMotion and _mask_drawing:
		var p1 = _mask_draw_start
		var p2 = event.position
		var display_rect = Rect2(
			Vector2(minf(p1.x, p2.x), minf(p1.y, p2.y)),
			Vector2(absf(p2.x - p1.x), absf(p2.y - p1.y))
		)
		_mask_rect = _display_rect_to_image_rect(display_rect)
		_update_mask_overlay()
		_update_mask_coords_label()


func _display_rect_to_image_rect(display_rect: Rect2) -> Rect2i:
	if _source_preview.texture == null:
		return Rect2i()
	var tex_size = Vector2(
		_source_preview.texture.get_width(),
		_source_preview.texture.get_height()
	)
	var rect_size = _source_preview.size
	if rect_size.x == 0.0 or rect_size.y == 0.0:
		return Rect2i()
	var scale = minf(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	var displayed_size = tex_size * scale
	var img_offset = (rect_size - displayed_size) * 0.5

	var pos_in_img = (display_rect.position - img_offset) / scale
	var size_in_img = display_rect.size / scale

	var ix = clampi(int(pos_in_img.x), 0, int(tex_size.x))
	var iy = clampi(int(pos_in_img.y), 0, int(tex_size.y))
	var iw = clampi(int(size_in_img.x), 0, int(tex_size.x) - ix)
	var ih = clampi(int(size_in_img.y), 0, int(tex_size.y) - iy)
	return Rect2i(ix, iy, iw, ih)


func _update_mask_overlay() -> void:
	if _mask_overlay == null or _source_preview.texture == null:
		if _mask_overlay != null:
			_mask_overlay.visible = false
		return
	if _mask_rect.size.x == 0 or _mask_rect.size.y == 0:
		_mask_overlay.visible = false
		return
	var tex_size = Vector2(
		_source_preview.texture.get_width(),
		_source_preview.texture.get_height()
	)
	var rect_size = _source_preview.size
	if rect_size.x == 0.0 or rect_size.y == 0.0:
		return
	var scale = minf(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	var displayed_size = tex_size * scale
	var img_offset = (rect_size - displayed_size) * 0.5

	_mask_overlay.position = Vector2(_mask_rect.position) * scale + img_offset
	_mask_overlay.size = Vector2(_mask_rect.size) * scale
	_mask_overlay.visible = true


func _update_mask_coords_label() -> void:
	if _mask_coords_label == null:
		return
	if _mask_rect.size.x == 0:
		_mask_coords_label.text = "—"
	else:
		_mask_coords_label.text = "x: %d  y: %d  l: %d  h: %d" % [
			_mask_rect.position.x, _mask_rect.position.y,
			_mask_rect.size.x, _mask_rect.size.y
		]
```

- [ ] **Step 2 : Vérifier absence d'erreurs de parsing**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . --import 2>&1 | grep -i "error\|parse\|SCRIPT" | head -20
```

Résultat attendu : aucune erreur de parsing pour `ai_studio_inpaint_tab.gd`.

- [ ] **Step 3 : Commit**

```bash
git add plugins/ai_studio/ai_studio_inpaint_tab.gd
git commit -m "feat: add ai_studio_inpaint_tab with Flux Fill mask drawing"
```

---

## Task 3 : Enregistrer l'onglet Inpaint dans `ai_studio_dialog.gd`

**Files:**
- Modify: `plugins/ai_studio/ai_studio_dialog.gd`

- [ ] **Step 1 : Ajouter la constante `InpaintTab`**

Dans `plugins/ai_studio/ai_studio_dialog.gd`, après la ligne :
```gdscript
const OutpaintTab = preload("res://plugins/ai_studio/ai_studio_outpaint_tab.gd")
```

Ajouter :
```gdscript
const InpaintTab = preload("res://plugins/ai_studio/ai_studio_inpaint_tab.gd")
```

- [ ] **Step 2 : Ajouter la variable `_inpaint_tab`**

Dans `plugins/ai_studio/ai_studio_dialog.gd`, après la ligne :
```gdscript
var _outpaint_tab: RefCounted = null
```

Ajouter :
```gdscript
var _inpaint_tab: RefCounted = null
```

- [ ] **Step 3 : Instancier et builder l'onglet dans `_build_ui`**

Dans `plugins/ai_studio/ai_studio_dialog.gd`, remplacer :
```gdscript
	_decl_tab = DeclinerTab.new()
	_expr_tab = ExpressionsTab.new()
	_blink_tab = BlinkTab.new()
	_outpaint_tab = OutpaintTab.new()
	_upscale_tab = UpscaleTab.new()
	_enhance_tab = EnhanceTab.new()
	_upscale_enhance_tab = UpscaleEnhanceTab.new()

	for tab in [_decl_tab, _expr_tab, _blink_tab, _outpaint_tab, _upscale_tab, _enhance_tab, _upscale_enhance_tab]:
		tab.initialize(self, _get_config, _negative_prompt_input,
			_show_image_preview, _open_gallery_source_picker, _save_config, _resolve_unique_path)
		tab.build_tab(_tab_container)
```

par :
```gdscript
	_decl_tab = DeclinerTab.new()
	_expr_tab = ExpressionsTab.new()
	_blink_tab = BlinkTab.new()
	_outpaint_tab = OutpaintTab.new()
	_inpaint_tab = InpaintTab.new()
	_upscale_tab = UpscaleTab.new()
	_enhance_tab = EnhanceTab.new()
	_upscale_enhance_tab = UpscaleEnhanceTab.new()

	for tab in [_decl_tab, _expr_tab, _blink_tab, _outpaint_tab, _inpaint_tab, _upscale_tab, _enhance_tab, _upscale_enhance_tab]:
		tab.initialize(self, _get_config, _negative_prompt_input,
			_show_image_preview, _open_gallery_source_picker, _save_config, _resolve_unique_path)
		tab.build_tab(_tab_container)
```

- [ ] **Step 4 : Ajouter `_inpaint_tab.setup()` dans `setup()`**

Dans `plugins/ai_studio/ai_studio_dialog.gd`, dans la fonction `setup()`, après la ligne :
```gdscript
	_outpaint_tab.setup(story_base_path, has_story)
```

Ajouter :
```gdscript
	_inpaint_tab.setup(story_base_path, has_story)
```

- [ ] **Step 5 : Ajouter `_inpaint_tab.cancel_generation()` dans `_on_close()`**

Dans `plugins/ai_studio/ai_studio_dialog.gd`, dans la fonction `_on_close()`, après la ligne :
```gdscript
	_outpaint_tab.cancel_generation()
```

Ajouter :
```gdscript
	_inpaint_tab.cancel_generation()
```

- [ ] **Step 6 : Ajouter `_inpaint_tab.update_generate_button()` dans `_update_all_generate_buttons()`**

Dans `plugins/ai_studio/ai_studio_dialog.gd`, dans la fonction `_update_all_generate_buttons()`, après la ligne :
```gdscript
	_outpaint_tab.update_generate_button()
```

Ajouter :
```gdscript
	_inpaint_tab.update_generate_button()
```

- [ ] **Step 7 : Ajouter `_inpaint_tab` dans le tableau de `_update_cfg_hints()`**

Dans `plugins/ai_studio/ai_studio_dialog.gd`, remplacer :
```gdscript
	for tab in [_decl_tab, _expr_tab, _blink_tab, _outpaint_tab, _upscale_tab, _enhance_tab, _upscale_enhance_tab]:
		tab.update_cfg_hint(has_negative)
```

par :
```gdscript
	for tab in [_decl_tab, _expr_tab, _blink_tab, _outpaint_tab, _inpaint_tab, _upscale_tab, _enhance_tab, _upscale_enhance_tab]:
		tab.update_cfg_hint(has_negative)
```

- [ ] **Step 8 : Vérifier l'absence d'erreurs**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . --import 2>&1 | grep -i "error\|parse\|SCRIPT" | head -20
```

Résultat attendu : aucune erreur.

- [ ] **Step 9 : Commit**

```bash
git add plugins/ai_studio/ai_studio_dialog.gd
git commit -m "feat: register InpaintTab in ai_studio_dialog"
```

---

## Task 4 : Reverter `ai_studio_decliner_tab.gd`

**Files:**
- Modify: `plugins/ai_studio/ai_studio_decliner_tab.gd`

- [ ] **Step 1 : Supprimer les 9 vars widget masque et 4 vars état**

Dans `plugins/ai_studio/ai_studio_decliner_tab.gd`, remplacer le bloc de vars incluant les vars masque :

```gdscript
var _mask_checkbox: CheckBox
var _mask_content: VBoxContainer
var _mask_coords_label: Label
var _mask_feather_slider: HSlider
var _mask_feather_value_label: Label
var _mask_clear_btn: Button
var _mask_debug_checkbox: CheckBox
var _mask_overlay: Panel
var _preview_wrapper: Control
```

par rien (supprimer ces lignes).

Puis supprimer les 4 vars état :

```gdscript
var _mask_rect: Rect2i = Rect2i()
var _mask_drawing: bool = false
var _mask_draw_start: Vector2 = Vector2.ZERO
var _source_image_size: Vector2i = Vector2i.ZERO
```

- [ ] **Step 2 : Reverter la section `source_hbox` — supprimer le wrapper et l'overlay**

Dans `plugins/ai_studio/ai_studio_decliner_tab.gd`, remplacer le bloc du wrapper (qui commence par `_preview_wrapper = Control.new()` jusqu'à `_preview_wrapper.add_child(_mask_overlay)` inclus) :

```gdscript
	_preview_wrapper = Control.new()
	_preview_wrapper.custom_minimum_size = Vector2(64, 64)
	_preview_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_wrapper.clip_contents = true
	source_hbox.add_child(_preview_wrapper)

	_source_preview = TextureRect.new()
	_source_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_source_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_source_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_source_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_source_preview.gui_input.connect(func(event: InputEvent):
		if _mask_checkbox != null and _mask_checkbox.button_pressed and _source_preview.texture != null:
			_handle_mask_input(event)
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _source_preview.texture:
				_show_preview_fn.call(_source_preview.texture, _source_image_path.get_file())
	)
	_preview_wrapper.add_child(_source_preview)

	# Overlay rectangle du masque
	_mask_overlay = Panel.new()
	_mask_overlay.visible = false
	_mask_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask_style = StyleBoxFlat.new()
	mask_style.bg_color = Color(0.2, 0.6, 1.0, 0.15)
	mask_style.border_width_left = 2
	mask_style.border_width_right = 2
	mask_style.border_width_top = 2
	mask_style.border_width_bottom = 2
	mask_style.border_color = Color(0.3, 0.7, 1.0, 1.0)
	_mask_overlay.add_theme_stylebox_override("panel", mask_style)
	_preview_wrapper.add_child(_mask_overlay)
```

par :

```gdscript
	_source_preview = TextureRect.new()
	_source_preview.custom_minimum_size = Vector2(64, 64)
	_source_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_source_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_source_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_source_preview.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _source_preview.texture:
				_show_preview_fn.call(_source_preview.texture, _source_image_path.get_file())
	)
	source_hbox.add_child(_source_preview)
```

- [ ] **Step 3 : Supprimer la section "Masque inpainting" entière dans `build_tab`**

Dans `plugins/ai_studio/ai_studio_decliner_tab.gd`, supprimer le bloc complet qui commence par le commentaire `# Masque inpainting (optionnel)` et se termine par `vbox.add_child(HSeparator.new())` (la séparation qui suit la section masque — celle de la ligne ~237), c'est-à-dire les lignes :

```gdscript
	# Masque inpainting (optionnel)
	vbox.add_child(HSeparator.new())
	var mask_header = HBoxContainer.new()
	mask_header.add_theme_constant_override("separation", 8)
	vbox.add_child(mask_header)

	_mask_checkbox = CheckBox.new()
	_mask_checkbox.text = "Masque inpainting"
	_mask_checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mask_header.add_child(_mask_checkbox)

	_mask_content = VBoxContainer.new()
	_mask_content.visible = false
	_mask_content.add_theme_constant_override("separation", 4)
	vbox.add_child(_mask_content)

	var mask_hint = Label.new()
	mask_hint.text = "Clique-glisse sur l'aperçu pour définir la zone à régénérer."
	mask_hint.add_theme_font_size_override("font_size", 11)
	mask_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	mask_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mask_content.add_child(mask_hint)

	var mask_coords_row = HBoxContainer.new()
	mask_coords_row.add_theme_constant_override("separation", 8)
	_mask_content.add_child(mask_coords_row)

	var coords_lbl = Label.new()
	coords_lbl.text = "Zone :"
	mask_coords_row.add_child(coords_lbl)

	_mask_coords_label = Label.new()
	_mask_coords_label.text = "—"
	_mask_coords_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mask_coords_row.add_child(_mask_coords_label)

	_mask_clear_btn = Button.new()
	_mask_clear_btn.text = "Effacer"
	_mask_clear_btn.pressed.connect(func():
		_mask_rect = Rect2i()
		_update_mask_overlay()
		_update_mask_coords_label()
	)
	mask_coords_row.add_child(_mask_clear_btn)

	var mask_feather_row = HBoxContainer.new()
	mask_feather_row.add_theme_constant_override("separation", 8)
	_mask_content.add_child(mask_feather_row)

	var feather_lbl = Label.new()
	feather_lbl.text = "Fondu :"
	mask_feather_row.add_child(feather_lbl)

	_mask_feather_slider = HSlider.new()
	_mask_feather_slider.min_value = 0
	_mask_feather_slider.max_value = 100
	_mask_feather_slider.step = 1
	_mask_feather_slider.value = 15
	_mask_feather_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mask_feather_slider.value_changed.connect(func(val: float): _mask_feather_value_label.text = str(int(val)))
	mask_feather_row.add_child(_mask_feather_slider)

	_mask_feather_value_label = Label.new()
	_mask_feather_value_label.text = "15"
	_mask_feather_value_label.custom_minimum_size.x = 28
	mask_feather_row.add_child(_mask_feather_value_label)

	_mask_debug_checkbox = CheckBox.new()
	_mask_debug_checkbox.text = "Debug mask"
	_mask_content.add_child(_mask_debug_checkbox)

	_mask_checkbox.toggled.connect(func(on: bool):
		_mask_content.visible = on
		if not on:
			_mask_rect = Rect2i()
			_update_mask_overlay()
			_update_mask_coords_label()
	)

	vbox.add_child(HSeparator.new())
```

- [ ] **Step 4 : Reverter `_on_generate_pressed` — supprimer le bloc masque**

Dans `plugins/ai_studio/ai_studio_decliner_tab.gd`, dans `_on_generate_pressed()`, remplacer :

```gdscript
	var cfg_value = _cfg_slider.value
	var steps_value = int(_steps_slider.value)
	var workflow_type: int = ComfyUIClient.WorkflowType.CREATION
	var neg_prompt = _neg_input.text.strip_edges()
	var mask_bytes = PackedByteArray()
	var mask_feather = 15
	if _mask_checkbox != null and _mask_checkbox.button_pressed and _mask_rect.size.x > 0 and _source_image_size.x > 0:
		mask_bytes = ComfyUIClient.build_mask_bytes(_mask_rect, _source_image_size.x, _source_image_size.y)
		mask_feather = int(_mask_feather_slider.value)
		workflow_type = ComfyUIClient.WorkflowType.INPAINT
	_client._debug_mask = _mask_debug_checkbox != null and _mask_debug_checkbox.button_pressed
	_client.generate(config, _source_image_path, _prompt_input.text, true, cfg_value, steps_value, workflow_type, 0.5, neg_prompt, 80, _megapixels_slider.value, _get_selected_loras(), _source_image2_path, mask_bytes, mask_feather)
```

par :

```gdscript
	var cfg_value = _cfg_slider.value
	var steps_value = int(_steps_slider.value)
	var neg_prompt = _neg_input.text.strip_edges()
	_client.generate(config, _source_image_path, _prompt_input.text, true, cfg_value, steps_value, ComfyUIClient.WorkflowType.CREATION, 0.5, neg_prompt, 80, _megapixels_slider.value, _get_selected_loras(), _source_image2_path)
```

- [ ] **Step 5 : Reverter `_set_inputs_enabled` — supprimer les refs masque**

Dans `plugins/ai_studio/ai_studio_decliner_tab.gd`, remplacer :

```gdscript
func _set_inputs_enabled(enabled: bool) -> void:
	_neg_input.editable = enabled
	_prompt_input.editable = enabled
	_choose_source_btn.disabled = not enabled
	_choose_gallery_btn.disabled = not enabled
	_choose_source2_btn.disabled = not enabled
	_choose_gallery2_btn.disabled = not enabled
	if _mask_clear_btn != null:
		_mask_clear_btn.disabled = not enabled
	if _mask_debug_checkbox != null:
		_mask_debug_checkbox.disabled = not enabled
```

par :

```gdscript
func _set_inputs_enabled(enabled: bool) -> void:
	_neg_input.editable = enabled
	_prompt_input.editable = enabled
	_choose_source_btn.disabled = not enabled
	_choose_gallery_btn.disabled = not enabled
	_choose_source2_btn.disabled = not enabled
	_choose_gallery2_btn.disabled = not enabled
```

- [ ] **Step 6 : Reverter `_load_preview` — supprimer la réinitialisation du masque**

Dans `plugins/ai_studio/ai_studio_decliner_tab.gd`, remplacer :

```gdscript
func _load_preview(tex_rect: TextureRect, path: String) -> void:
	if path == "":
		tex_rect.texture = null
		return
	var img = Image.new()
	if img.load(path) == OK:
		tex_rect.texture = ImageTexture.create_from_image(img)
		if tex_rect == _source_preview:
			_source_image_size = Vector2i(img.get_width(), img.get_height())
			# Réinitialiser le masque quand on change l'image source
			_mask_rect = Rect2i()
			_update_mask_overlay()
			_update_mask_coords_label()
	else:
		tex_rect.texture = null
```

par :

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

- [ ] **Step 7 : Supprimer les 4 méthodes masque**

Dans `plugins/ai_studio/ai_studio_decliner_tab.gd`, supprimer les 4 fonctions suivantes dans leur intégralité :
- `func _handle_mask_input(event: InputEvent) -> void:` (et son corps jusqu'au prochain `func`)
- `func _display_rect_to_image_rect(display_rect: Rect2) -> Rect2i:` (et son corps)
- `func _update_mask_overlay() -> void:` (et son corps)
- `func _update_mask_coords_label() -> void:` (et son corps jusqu'à la fin du fichier)

- [ ] **Step 8 : Lancer les tests**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd 2>&1 | tail -20
```

Résultat attendu : tous les tests passent, 0 FAIL.

- [ ] **Step 9 : Commit**

```bash
git add plugins/ai_studio/ai_studio_decliner_tab.gd
git commit -m "refactor: revert decliner tab to pre-mask state (mask moved to inpaint tab)"
```

---

## Task 5 : Validation finale

**Files:** (aucun)

- [ ] **Step 1 : Lancer l'acceptance globale**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd 2>&1 | tail -30
```

Résultat attendu : 0 FAIL.

- [ ] **Step 2 : Vérifier que le projet se compile sans erreur**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . --import 2>&1 | grep -i "error\|parse\|SCRIPT" | head -20
```

Résultat attendu : aucune erreur fatale.

- [ ] **Step 3 : Commit final de tag si nécessaire**

Si tout passe, le travail est terminé. Indiquer à l'utilisateur que l'onglet Inpaint est prêt pour test avec un vrai serveur ComfyUI.

---

## Self-Review

**Couverture spec :**
- ✅ `INPAINT_FILL_WORKFLOW_TEMPLATE` (basé sur OUTPAINT sans node 44)
- ✅ `_build_inpaint_workflow` réécrit avec Flux Fill
- ✅ `generate_inpaint()` ajouté
- ✅ `ai_studio_inpaint_tab.gd` créé avec masque interactif, guidance, steps, denoise
- ✅ Tab enregistré dans `ai_studio_dialog.gd`
- ✅ Decliner reverté
- ✅ Tests mis à jour (TDD)

**Hors scope (non implémenté, conforme spec) :**
- LoRAs pour Flux Fill (les LoRAs du Décliner sont spécifiques à Flux2 Klein)
- Megapixels (Flux Fill travaille à résolution native)
- Remove background (le résultat inpaint garde le contexte entier)
