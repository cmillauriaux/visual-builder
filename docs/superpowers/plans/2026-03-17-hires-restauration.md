# Onglet Restauration (HiRes Fix) — Plan d'implémentation

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter un 4e onglet "Restauration" dans le Studio IA permettant de lancer un pass img2img (même résolution) sur une image existante pour supprimer artefacts/bruit, puis remplacer la source avec backup automatique.

**Architecture:** Nouveau fichier `plugins/ai_studio/ai_studio_hires_tab.gd` (extends RefCounted, même pattern que UpscaleTab). Nouveau `WorkflowType.HIRES` dans `comfyui_client.gd` utilisant le même mécanisme img2img que le workflow Expression mais sans détection de visage. Le tab est câblé dans `ai_studio_dialog.gd`.

**Tech Stack:** GDScript 4, Godot 4.6.1, ComfyUI (img2img via Flux 2 Klein + VAEEncode + SplitSigmas), GUT 9.3.0 (tests)

---

## Fichiers concernés

| Fichier | Action | Rôle |
|---------|--------|------|
| `src/services/comfyui_client.gd` | Modifier | Ajouter `WorkflowType.HIRES`, `HIRES_WORKFLOW_TEMPLATE`, `_build_hires_workflow()` |
| `plugins/ai_studio/ai_studio_hires_tab.gd` | Créer | UI + logique de l'onglet Restauration |
| `plugins/ai_studio/ai_studio_dialog.gd` | Modifier | Instancier et câbler `HiResTab` |
| `specs/services/test_comfyui_client.gd` | Modifier | Tests pour `WorkflowType.HIRES` |
| `specs/plugins/ai_studio/test_ai_studio_hires_tab.gd` | Créer | Tests GUT du nouvel onglet |
| `specs/plugins/ai_studio/test_ai_studio_plugin.gd` | Modifier | Vérifier instanciation 4e tab (si pertinent) |

---

## Task 1 : WorkflowType.HIRES dans ComfyUI client

**Files:**
- Modify: `src/services/comfyui_client.gd`
- Test: `specs/services/test_comfyui_client.gd`

- [ ] **Step 1.1 : Écrire les tests qui échouent**

Ajouter à la fin de `specs/services/test_comfyui_client.gd` :

```gdscript
func test_workflow_type_hires_exists():
	var client = ComfyUIClientScript.new()
	# WorkflowType.HIRES doit valoir 3
	assert_eq(client.WorkflowType.HIRES, 3)

func test_build_workflow_hires_uses_source_as_latent():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("img.png", "high quality", 42, true, 7.0, 25, 3, 0.3, "")
	# L'image source doit être chargée
	assert_eq(wf["76"]["inputs"]["image"], "img.png")
	# Le prompt doit être appliqué
	assert_eq(wf["75:74"]["inputs"]["text"], "high quality")
	# Le seed doit être appliqué
	assert_eq(wf["75:73"]["inputs"]["noise_seed"], 42)
	# CFG appliqué
	assert_eq(wf["75:63"]["inputs"]["cfg"], 7.0)
	# SplitSigmas présent (denoise control)
	assert_true(wf.has("split_sigmas"))
	# L'encodage latent de la source est utilisé (img2img)
	assert_eq(wf["75:64"]["inputs"]["latent_image"], ["75:79:78", 0])
	# Pas de détection de visage
	assert_false(wf.has("99"))
	assert_false(wf.has("100"))
	# SaveImage pointe directement sur VAEDecode (pas de BiRefNet)
	assert_eq(wf["9"]["inputs"]["images"], ["75:65", 0])

func test_build_workflow_hires_denoise_controls_split_step():
	var client = ComfyUIClientScript.new()
	# denoise=0.3, steps=25 → split_step = max(1, round(25 * (1-0.3))) = max(1, 18) = 18
	var wf = client.build_workflow("img.png", "", 0, true, 7.0, 25, 3, 0.3, "")
	assert_eq(wf["split_sigmas"]["inputs"]["step"], 18)

func test_build_workflow_hires_negative_prompt_applied():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("img.png", "sharp", 0, true, 7.0, 25, 3, 0.3, "blurry")
	# Le negative prompt crée un noeud CLIPTextEncode supplémentaire
	assert_true(wf.has("75:83"))
	assert_eq(wf["75:83"]["inputs"]["text"], "blurry")
```

- [ ] **Step 1.2 : Lancer les tests pour vérifier qu'ils échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_comfyui_client.gd 2>&1 | tail -20
```

Attendu : échec sur les 4 nouveaux tests (`test_workflow_type_hires_exists`, etc.)

- [ ] **Step 1.3 : Ajouter `WorkflowType.HIRES = 3` à l'enum**

Dans `src/services/comfyui_client.gd`, ligne 11, remplacer :

```gdscript
enum WorkflowType { CREATION = 0, EXPRESSION = 1, UPSCALE = 2 }
```

par :

```gdscript
enum WorkflowType { CREATION = 0, EXPRESSION = 1, UPSCALE = 2, HIRES = 3 }
```

- [ ] **Step 1.4 : Ajouter `HIRES_WORKFLOW_TEMPLATE`**

Ajouter juste avant la ligne `func is_generating()` (après `}` qui clôt `UPSCALE_WORKFLOW_TEMPLATE`) :

```gdscript
# --- HiRes Fix workflow template (Flux 2 Klein, img2img full-image, même résolution) ---
# Identique au workflow Expression SANS les noeuds de détection de visage (99,100,101,102,103,106).
# La sortie SaveImage pointe directement sur VAEDecode (75:65) — pas de BiRefNet.
# Paramètres dynamiques : 76.inputs.image, 75:74.inputs.text, 75:73.inputs.noise_seed,
#                         75:63.inputs.cfg, 75:62.inputs.steps + SplitSigmas calculé
const HIRES_WORKFLOW_TEMPLATE: Dictionary = {
	"9": {
		"class_type": "SaveImage",
		"inputs": {
			"filename_prefix": "HiResFix",
			"images": ["75:65", 0]
		}
	},
	"76": {
		"class_type": "LoadImage",
		"inputs": {
			"image": ""
		}
	},
	"75:61": {
		"class_type": "KSamplerSelect",
		"inputs": {
			"sampler_name": "euler"
		}
	},
	"75:64": {
		"class_type": "SamplerCustomAdvanced",
		"inputs": {
			"noise": ["75:73", 0],
			"guider": ["75:63", 0],
			"sampler": ["75:61", 0],
			"sigmas": ["75:62", 0],
			"latent_image": ["75:66", 0]
		}
	},
	"75:65": {
		"class_type": "VAEDecode",
		"inputs": {
			"samples": ["75:64", 0],
			"vae": ["75:72", 0]
		}
	},
	"75:73": {
		"class_type": "RandomNoise",
		"inputs": {
			"noise_seed": 0
		}
	},
	"75:70": {
		"class_type": "UNETLoader",
		"inputs": {
			"unet_name": "flux-2-klein-9b-fp8.safetensors",
			"weight_dtype": "default"
		}
	},
	"75:71": {
		"class_type": "CLIPLoader",
		"inputs": {
			"clip_name": "qwen_3_8b_fp8mixed.safetensors",
			"type": "flux2",
			"device": "default"
		}
	},
	"75:72": {
		"class_type": "VAELoader",
		"inputs": {
			"vae_name": "flux2-vae.safetensors"
		}
	},
	"75:66": {
		"class_type": "EmptyFlux2LatentImage",
		"inputs": {
			"width": ["75:81", 0],
			"height": ["75:81", 1],
			"batch_size": 1
		}
	},
	"75:80": {
		"class_type": "ImageScaleToTotalPixels",
		"inputs": {
			"upscale_method": "lanczos",
			"megapixels": 1,
			"resolution_steps": 1,
			"image": ["76", 0]
		}
	},
	"75:63": {
		"class_type": "CFGGuider",
		"inputs": {
			"cfg": 7.0,
			"model": ["75:70", 0],
			"positive": ["75:79:77", 0],
			"negative": ["75:79:76", 0]
		}
	},
	"75:62": {
		"class_type": "Flux2Scheduler",
		"inputs": {
			"steps": 25,
			"width": ["75:81", 0],
			"height": ["75:81", 1]
		}
	},
	"75:74": {
		"class_type": "CLIPTextEncode",
		"inputs": {
			"text": "",
			"clip": ["75:71", 0]
		}
	},
	"75:81": {
		"class_type": "GetImageSize",
		"inputs": {
			"image": ["75:80", 0]
		}
	},
	"75:79:76": {
		"class_type": "ReferenceLatent",
		"inputs": {
			"conditioning": ["75:82", 0],
			"latent": ["75:79:78", 0]
		}
	},
	"75:79:78": {
		"class_type": "VAEEncode",
		"inputs": {
			"pixels": ["75:80", 0],
			"vae": ["75:72", 0]
		}
	},
	"75:79:77": {
		"class_type": "ReferenceLatent",
		"inputs": {
			"conditioning": ["75:74", 0],
			"latent": ["75:79:78", 0]
		}
	},
	"75:82": {
		"class_type": "ConditioningZeroOut",
		"inputs": {
			"conditioning": ["75:74", 0]
		}
	}
}
```

- [ ] **Step 1.5 : Ajouter `_build_hires_workflow()` et le câbler dans `build_workflow()`**

Ajouter la méthode juste avant `_build_expression_workflow` :

```gdscript
func _build_hires_workflow(filename: String, prompt_text: String, seed: int, cfg: float, steps: int, denoise: float, negative_prompt: String) -> Dictionary:
	var wf = HIRES_WORKFLOW_TEMPLATE.duplicate(true)
	wf["76"]["inputs"]["image"] = filename
	wf["75:74"]["inputs"]["text"] = prompt_text
	wf["75:73"]["inputs"]["noise_seed"] = seed
	wf["75:63"]["inputs"]["cfg"] = cfg
	wf["75:62"]["inputs"]["steps"] = steps
	_apply_negative_prompt(wf, negative_prompt)
	# img2img : partir du latent encodé de l'image source (pas d'un canvas vierge)
	wf["75:64"]["inputs"]["latent_image"] = ["75:79:78", 0]
	# SplitSigmas : contrôle du denoise (même logique que le workflow Expression)
	var split_step = max(1, roundi(steps * (1.0 - denoise)))
	wf["split_sigmas"] = {
		"class_type": "SplitSigmas",
		"inputs": {
			"sigmas": ["75:62", 0],
			"step": split_step
		}
	}
	wf["75:64"]["inputs"]["sigmas"] = ["split_sigmas", 1]
	# EmptyFlux2LatentImage n'est pas utilisé (on encode la source)
	wf.erase("75:66")
	return wf
```

Dans `build_workflow()`, ajouter le cas HIRES **avant** le cas EXPRESSION :

```gdscript
func build_workflow(filename: String, prompt_text: String, seed: int, remove_background: bool = true, cfg: float = 1.0, steps: int = 4, workflow_type: int = WorkflowType.CREATION, denoise: float = 0.5, negative_prompt: String = "", face_box_size: int = 80) -> Dictionary:
	if workflow_type == WorkflowType.UPSCALE:
		return _build_upscale_workflow(filename, prompt_text, seed, denoise, _upscale_model_name, _upscale_tile_size, _upscale_target_w, _upscale_target_h, negative_prompt)
	if workflow_type == WorkflowType.HIRES:
		return _build_hires_workflow(filename, prompt_text, seed, cfg, steps, denoise, negative_prompt)
	if workflow_type == WorkflowType.EXPRESSION:
		return _build_expression_workflow(filename, prompt_text, seed, remove_background, cfg, steps, denoise, negative_prompt, face_box_size)
	# ... reste inchangé (CREATION)
```

- [ ] **Step 1.6 : Lancer les tests et vérifier qu'ils passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_comfyui_client.gd 2>&1 | tail -20
```

Attendu : tous les tests passent (anciens + nouveaux)

- [ ] **Step 1.7 : Commit**

```bash
git add src/services/comfyui_client.gd specs/services/test_comfyui_client.gd
git commit -m "feat(comfyui): add WorkflowType.HIRES with img2img restoration workflow"
```

---

## Task 2 : Créer `ai_studio_hires_tab.gd`

**Files:**
- Create: `plugins/ai_studio/ai_studio_hires_tab.gd`
- Create: `specs/plugins/ai_studio/test_ai_studio_hires_tab.gd`

- [ ] **Step 2.1 : Écrire les tests qui échouent**

Créer `specs/plugins/ai_studio/test_ai_studio_hires_tab.gd` :

```gdscript
extends GutTest

const HiResTab = preload("res://plugins/ai_studio/ai_studio_hires_tab.gd")


func test_has_required_public_methods() -> void:
	var tab := HiResTab.new()
	assert_true(tab.has_method("initialize"))
	assert_true(tab.has_method("build_tab"))
	assert_true(tab.has_method("update_generate_button"))
	assert_true(tab.has_method("update_cfg_hint"))
	assert_true(tab.has_method("cancel_generation"))
	assert_true(tab.has_method("setup"))


func test_compute_backup_path_simple() -> void:
	# Fonction pure testable sans UI
	assert_eq(
		HiResTab._compute_backup_path("/story/assets/foregrounds/perso_001.png"),
		"/story/assets/foregrounds/perso_001_original.png"
	)


func test_compute_backup_path_with_underscores() -> void:
	assert_eq(
		HiResTab._compute_backup_path("/path/to/char_happy_v2.png"),
		"/path/to/char_happy_v2_original.png"
	)


func test_compute_backup_path_at_root() -> void:
	assert_eq(
		HiResTab._compute_backup_path("/img.png"),
		"//img_original.png"
	)


func test_cancel_generation_safe_when_no_client() -> void:
	# cancel_generation() ne doit pas crasher si aucun client actif
	var tab := HiResTab.new()
	# Simuler initialize minimal pour éviter null ref
	tab._url_input = LineEdit.new()
	tab._token_input = LineEdit.new()
	tab._neg_input = TextEdit.new()
	tab.cancel_generation()  # Ne doit pas lever d'erreur
	tab._url_input.queue_free()
	tab._token_input.queue_free()
	tab._neg_input.queue_free()


func test_update_generate_button_disabled_when_no_source() -> void:
	var tab := HiResTab.new()
	var url_input := LineEdit.new()
	url_input.text = "http://localhost:8188"
	var token_input := LineEdit.new()
	var neg_input := TextEdit.new()
	tab._url_input = url_input
	tab._token_input = token_input
	tab._neg_input = neg_input
	var btn := Button.new()
	tab._generate_btn = btn
	tab._source_image_path = ""  # Pas de source
	tab.update_generate_button()
	assert_true(btn.disabled)
	url_input.queue_free()
	token_input.queue_free()
	neg_input.queue_free()
	btn.queue_free()


func test_update_generate_button_disabled_when_no_url() -> void:
	var tab := HiResTab.new()
	var url_input := LineEdit.new()
	url_input.text = ""  # Pas d'URL
	var token_input := LineEdit.new()
	var neg_input := TextEdit.new()
	tab._url_input = url_input
	tab._token_input = token_input
	tab._neg_input = neg_input
	var btn := Button.new()
	tab._generate_btn = btn
	tab._source_image_path = "/some/image.png"
	tab.update_generate_button()
	assert_true(btn.disabled)
	url_input.queue_free()
	token_input.queue_free()
	neg_input.queue_free()
	btn.queue_free()


func test_update_generate_button_enabled_when_url_and_source() -> void:
	var tab := HiResTab.new()
	var url_input := LineEdit.new()
	url_input.text = "http://localhost:8188"
	var token_input := LineEdit.new()
	var neg_input := TextEdit.new()
	tab._url_input = url_input
	tab._token_input = token_input
	tab._neg_input = neg_input
	var btn := Button.new()
	btn.disabled = true
	tab._generate_btn = btn
	tab._source_image_path = "/some/image.png"
	tab.update_generate_button()
	assert_false(btn.disabled)
	url_input.queue_free()
	token_input.queue_free()
	neg_input.queue_free()
	btn.queue_free()
```

- [ ] **Step 2.2 : Lancer les tests pour vérifier qu'ils échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/plugins/ai_studio/test_ai_studio_hires_tab.gd 2>&1 | tail -20
```

Attendu : erreur de chargement du script (fichier inexistant)

- [ ] **Step 2.3 : Créer `ai_studio_hires_tab.gd`**

Créer `plugins/ai_studio/ai_studio_hires_tab.gd` :

```gdscript
extends RefCounted

const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")
const ImageFileDialog = preload("res://src/ui/shared/image_file_dialog.gd")

# Shared refs (set via initialize)
var _parent_window: Window
var _url_input: LineEdit
var _token_input: LineEdit
var _neg_input: TextEdit
var _show_preview_fn: Callable
var _open_gallery_fn: Callable
var _save_config_fn: Callable
var _story_base_path: String = ""

# UI widgets
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
var _denoise_slider: HSlider
var _denoise_value_label: Label
var _generate_btn: Button
var _cancel_btn: Button
var _result_preview: TextureRect
var _dim_label: Label
var _status_label: Label
var _progress_bar: ProgressBar
var _accept_btn: Button
var _reject_btn: Button
var _regenerate_btn: Button
var _backup_info_label: Label

# State
var _source_image_path: String = ""
var _generated_image: Image = null
var _client: Node = null


func initialize(
	parent_window: Window,
	url_input: LineEdit,
	token_input: LineEdit,
	neg_input: TextEdit,
	show_preview_fn: Callable,
	open_gallery_fn: Callable,
	save_config_fn: Callable,
	_resolve_path_fn: Callable  # Non utilisé, mais requis pour la cohérence de l'interface
) -> void:
	_parent_window = parent_window
	_url_input = url_input
	_token_input = token_input
	_neg_input = neg_input
	_show_preview_fn = show_preview_fn
	_open_gallery_fn = open_gallery_fn
	_save_config_fn = save_config_fn


func build_tab(tab_container: TabContainer) -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "Restauration"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(scroll)

	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	scroll.add_child(hbox)

	hbox.add_child(_build_params_column())
	hbox.add_child(_build_result_column())


func setup(story_base_path: String, has_story: bool) -> void:
	_story_base_path = story_base_path
	if _choose_gallery_btn:
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


# ========================================================
# Pure functions (testables sans UI)
# ========================================================

static func _compute_backup_path(source_path: String) -> String:
	var dir = source_path.get_base_dir()
	var basename = source_path.get_file().get_basename()
	return dir + "/" + basename + "_original.png"


# ========================================================
# UI construction
# ========================================================

func _build_params_column() -> Control:
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)

	# Source image
	var source_label = Label.new()
	source_label.text = "Image source :"
	vbox.add_child(source_label)

	var source_hbox = HBoxContainer.new()
	source_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(source_hbox)

	_source_preview = TextureRect.new()
	_source_preview.custom_minimum_size = Vector2(72, 72)
	_source_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_source_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_source_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_source_preview.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _source_preview.texture:
				_show_preview_fn.call(_source_preview.texture, _source_image_path.get_file())
	)
	source_hbox.add_child(_source_preview)

	var source_vbox = VBoxContainer.new()
	source_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_hbox.add_child(source_vbox)

	_source_path_label = Label.new()
	_source_path_label.text = "Aucune image sélectionnée"
	_source_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_vbox.add_child(_source_path_label)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 4)
	source_vbox.add_child(btn_hbox)

	_choose_source_btn = Button.new()
	_choose_source_btn.text = "📂 Importer…"
	_choose_source_btn.pressed.connect(_on_choose_source)
	btn_hbox.add_child(_choose_source_btn)

	_choose_gallery_btn = Button.new()
	_choose_gallery_btn.text = "🖼 Galerie…"
	_choose_gallery_btn.pressed.connect(_on_choose_from_gallery)
	_choose_gallery_btn.disabled = true
	btn_hbox.add_child(_choose_gallery_btn)

	vbox.add_child(HSeparator.new())

	# Prompt
	var prompt_label = Label.new()
	prompt_label.text = "Prompt de restauration :"
	vbox.add_child(prompt_label)

	_prompt_input = TextEdit.new()
	_prompt_input.custom_minimum_size.y = 56
	_prompt_input.placeholder_text = "high quality, sharp details, clean skin, beautiful eyes…"
	vbox.add_child(_prompt_input)

	# CFG
	var cfg_hbox = HBoxContainer.new()
	cfg_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(cfg_hbox)

	var cfg_label = Label.new()
	cfg_label.text = "CFG :"
	cfg_label.custom_minimum_size.x = 56
	cfg_hbox.add_child(cfg_label)

	_cfg_slider = HSlider.new()
	_cfg_slider.min_value = 1.0
	_cfg_slider.max_value = 30.0
	_cfg_slider.step = 0.5
	_cfg_slider.value = 7.0
	_cfg_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cfg_slider.value_changed.connect(func(val: float):
		_cfg_value_label.text = str(snapped(val, 0.1))
		if _cfg_hint:
			_cfg_hint.visible = (_neg_input.text.strip_edges() != "") and val < 3.0
	)
	cfg_hbox.add_child(_cfg_slider)

	_cfg_value_label = Label.new()
	_cfg_value_label.text = "7.0"
	_cfg_value_label.custom_minimum_size.x = 32
	cfg_hbox.add_child(_cfg_value_label)

	_cfg_hint = Label.new()
	_cfg_hint.text = "⚠ CFG faible avec negative prompt"
	_cfg_hint.add_theme_font_size_override("font_size", 11)
	_cfg_hint.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	_cfg_hint.visible = false
	vbox.add_child(_cfg_hint)

	# Steps
	var steps_hbox = HBoxContainer.new()
	steps_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(steps_hbox)

	var steps_label = Label.new()
	steps_label.text = "Steps :"
	steps_label.custom_minimum_size.x = 56
	steps_hbox.add_child(steps_label)

	_steps_slider = HSlider.new()
	_steps_slider.min_value = 1
	_steps_slider.max_value = 50
	_steps_slider.step = 1
	_steps_slider.value = 25
	_steps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steps_slider.value_changed.connect(func(val: float):
		_steps_value_label.text = str(int(val))
	)
	steps_hbox.add_child(_steps_slider)

	_steps_value_label = Label.new()
	_steps_value_label.text = "25"
	_steps_value_label.custom_minimum_size.x = 32
	steps_hbox.add_child(_steps_value_label)

	# Denoise
	var denoise_hbox = HBoxContainer.new()
	denoise_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(denoise_hbox)

	var denoise_label = Label.new()
	denoise_label.text = "Denoise :"
	denoise_label.custom_minimum_size.x = 56
	denoise_hbox.add_child(denoise_label)

	_denoise_slider = HSlider.new()
	_denoise_slider.min_value = 0.0
	_denoise_slider.max_value = 1.0
	_denoise_slider.step = 0.05
	_denoise_slider.value = 0.3
	_denoise_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_denoise_slider.value_changed.connect(func(val: float):
		_denoise_value_label.text = str(snapped(val, 0.01))
	)
	denoise_hbox.add_child(_denoise_slider)

	_denoise_value_label = Label.new()
	_denoise_value_label.text = "0.30"
	_denoise_value_label.custom_minimum_size.x = 32
	denoise_hbox.add_child(_denoise_value_label)

	var denoise_hint = Label.new()
	denoise_hint.text = "0.0 = fidèle à la source · 1.0 = libre"
	denoise_hint.add_theme_font_size_override("font_size", 11)
	denoise_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(denoise_hint)

	# Generate + Cancel buttons
	var gen_hbox = HBoxContainer.new()
	gen_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(gen_hbox)

	_generate_btn = Button.new()
	_generate_btn.text = "✨ Restaurer"
	_generate_btn.disabled = true
	_generate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_generate_btn.pressed.connect(_on_generate_pressed)
	gen_hbox.add_child(_generate_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "✕ Annuler"
	_cancel_btn.visible = false
	_cancel_btn.pressed.connect(func():
		cancel_generation()
		_set_inputs_enabled(true)
		_show_status("")
		_update_generate_button()
	)
	gen_hbox.add_child(_cancel_btn)

	return vbox


func _build_result_column() -> Control:
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)

	var result_label = Label.new()
	result_label.text = "Résultat :"
	vbox.add_child(result_label)

	# Result preview
	_result_preview = TextureRect.new()
	_result_preview.custom_minimum_size = Vector2(200, 200)
	_result_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_result_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_result_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_preview.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _result_preview.texture:
				_show_preview_fn.call(_result_preview.texture, "Résultat Restauration")
	)
	vbox.add_child(_result_preview)

	_dim_label = Label.new()
	_dim_label.text = ""
	_dim_label.add_theme_font_size_override("font_size", 11)
	_dim_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(_dim_label)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.visible = false
	_progress_bar.custom_minimum_size.y = 8
	_progress_bar.indeterminate = true
	vbox.add_child(_progress_bar)

	_backup_info_label = Label.new()
	_backup_info_label.text = ""
	_backup_info_label.add_theme_font_size_override("font_size", 11)
	_backup_info_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
	_backup_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_backup_info_label.visible = false
	vbox.add_child(_backup_info_label)

	var action_hbox = HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(action_hbox)

	_accept_btn = Button.new()
	_accept_btn.text = "✓ Accepter et remplacer"
	_accept_btn.disabled = true
	_accept_btn.pressed.connect(_on_accept_pressed)
	_accept_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	action_hbox.add_child(_accept_btn)

	_reject_btn = Button.new()
	_reject_btn.text = "✕ Rejeter"
	_reject_btn.disabled = true
	_reject_btn.pressed.connect(_on_reject_pressed)
	action_hbox.add_child(_reject_btn)

	_regenerate_btn = Button.new()
	_regenerate_btn.text = "↻ Regénérer"
	_regenerate_btn.disabled = true
	_regenerate_btn.pressed.connect(_on_generate_pressed)
	vbox.add_child(_regenerate_btn)

	return vbox


# ========================================================
# Private logic
# ========================================================

func _on_choose_source() -> void:
	var dialog = ImageFileDialog.new()
	dialog.file_selected.connect(func(path: String): _set_source(path))
	_parent_window.add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))


func _on_choose_from_gallery() -> void:
	_open_gallery_fn.call(func(path: String): _set_source(path))


func _set_source(path: String) -> void:
	_source_image_path = path
	_source_path_label.text = path.get_file()
	_load_preview(_source_preview, path)
	_update_backup_info()
	_update_generate_button()


func _update_backup_info() -> void:
	if _source_image_path == "" or _backup_info_label == null:
		return
	var backup_path = _compute_backup_path(_source_image_path)
	_backup_info_label.text = "Backup : " + backup_path.get_file()
	_backup_info_label.visible = true


func _update_generate_button() -> void:
	if _generate_btn == null:
		return
	var has_url = _url_input.text.strip_edges() != ""
	var has_source = _source_image_path != ""
	_generate_btn.disabled = not (has_url and has_source)


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
	_cancel_btn.visible = true
	_accept_btn.disabled = true
	_reject_btn.disabled = true
	_regenerate_btn.disabled = true
	_generated_image = null
	_result_preview.texture = null
	_dim_label.text = ""
	_set_inputs_enabled(false)
	_show_status("Lancement de la restauration…")

	var config = ComfyUIConfig.new()
	config.set_url(_url_input.text.strip_edges())
	config.set_token(_token_input.text.strip_edges())

	_client.generate(
		config,
		_source_image_path,
		_prompt_input.text.strip_edges(),
		false,  # remove_background non utilisé pour HIRES
		_cfg_slider.value,
		int(_steps_slider.value),
		ComfyUIClient.WorkflowType.HIRES,
		_denoise_slider.value,
		_neg_input.text.strip_edges()
	)


func _on_generation_completed(image: Image) -> void:
	_generated_image = image
	_result_preview.texture = ImageTexture.create_from_image(image)
	_dim_label.text = "%d × %d px (même résolution que la source)" % [image.get_width(), image.get_height()]
	_cancel_btn.visible = false
	_show_success("Restauration terminée !")
	_accept_btn.disabled = false
	_reject_btn.disabled = false
	_regenerate_btn.disabled = false
	_set_inputs_enabled(true)
	_update_generate_button()


func _on_generation_failed(error: String) -> void:
	_cancel_btn.visible = false
	_show_error("Erreur : " + error)
	_regenerate_btn.disabled = false
	_set_inputs_enabled(true)
	_update_generate_button()


func _on_generation_progress(status: String) -> void:
	_show_status(status)


func _on_accept_pressed() -> void:
	if _generated_image == null or _source_image_path == "":
		return

	var backup_path = _compute_backup_path(_source_image_path)
	if not FileAccess.file_exists(backup_path):
		var err = DirAccess.copy_absolute(_source_image_path, backup_path)
		if err != OK:
			_show_error("Backup échoué (%s). Source non modifiée." % error_string(err))
			return

	var save_err = _generated_image.save_png(_source_image_path)
	if save_err != OK:
		_show_error("Échec de la sauvegarde (%s)." % error_string(save_err))
		return

	_reset_to_empty()


func _on_reject_pressed() -> void:
	_generated_image = null
	_result_preview.texture = null
	_accept_btn.disabled = true
	_reject_btn.disabled = true
	_regenerate_btn.disabled = true
	_show_status("")


func _reset_to_empty() -> void:
	_source_image_path = ""
	_source_path_label.text = "Aucune image sélectionnée"
	_source_preview.texture = null
	_generated_image = null
	_result_preview.texture = null
	_dim_label.text = ""
	_cancel_btn.visible = false
	_accept_btn.disabled = true
	_reject_btn.disabled = true
	_regenerate_btn.disabled = true
	_backup_info_label.visible = false
	_show_status("")
	_update_generate_button()


func _set_inputs_enabled(enabled: bool) -> void:
	_url_input.editable = enabled
	_token_input.editable = enabled
	_neg_input.editable = enabled
	_choose_source_btn.disabled = not enabled
	if _story_base_path == "":
		_choose_gallery_btn.disabled = true
	else:
		_choose_gallery_btn.disabled = not enabled
	_prompt_input.editable = enabled
	_cfg_slider.editable = enabled
	_steps_slider.editable = enabled
	_denoise_slider.editable = enabled


func _show_status(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_progress_bar.visible = message != ""


func _show_success(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_progress_bar.visible = false


func _show_error(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_progress_bar.visible = false


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

- [ ] **Step 2.4 : Lancer les tests pour vérifier qu'ils passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/plugins/ai_studio/test_ai_studio_hires_tab.gd 2>&1 | tail -20
```

Attendu : tous les tests passent

- [ ] **Step 2.5 : Commit**

```bash
git add plugins/ai_studio/ai_studio_hires_tab.gd specs/plugins/ai_studio/test_ai_studio_hires_tab.gd
git commit -m "feat(ai-studio): add HiRes restoration tab with backup-and-replace"
```

---

## Task 3 : Intégrer le tab dans `ai_studio_dialog.gd`

**Files:**
- Modify: `plugins/ai_studio/ai_studio_dialog.gd`
- Modify: `specs/plugins/ai_studio/test_ai_studio_plugin.gd`

- [ ] **Step 3.1 : Écrire le test qui échoue**

Ajouter à `specs/plugins/ai_studio/test_ai_studio_plugin.gd` :

```gdscript
func test_ai_studio_dialog_has_four_tabs() -> void:
	# Vérifier que le dialog expose bien 4 onglets après construction
	var AIStudioDialog = load("res://plugins/ai_studio/ai_studio_dialog.gd")
	var dialog = AIStudioDialog.new()
	add_child_autofree(dialog)
	await get_tree().process_frame
	# Trouver le TabContainer dans le dialog
	var tab_container: TabContainer = null
	for child in dialog.get_children():
		if child is MarginContainer:
			for c2 in child.get_children():
				if c2 is VBoxContainer:
					for c3 in c2.get_children():
						if c3 is TabContainer:
							tab_container = c3
	assert_not_null(tab_container, "TabContainer non trouvé dans le dialog")
	assert_eq(tab_container.get_tab_count(), 4)
	assert_eq(tab_container.get_tab_title(3), "Restauration")
```

- [ ] **Step 3.2 : Lancer le test pour vérifier qu'il échoue**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/plugins/ai_studio/test_ai_studio_plugin.gd 2>&1 | tail -20
```

Attendu : échec sur `test_ai_studio_dialog_has_four_tabs` (3 tabs trouvés au lieu de 4)

- [ ] **Step 3.3 : Modifier `ai_studio_dialog.gd`**

**3.3a** — Ajouter le preload (ligne 16, après `UpscaleTab`) :

```gdscript
const HiResTab = preload("res://plugins/ai_studio/ai_studio_hires_tab.gd")
```

**3.3b** — Ajouter la variable membre (ligne 48, après `_upscale_tab`) :

```gdscript
var _hires_tab: RefCounted = null
```

**3.3c** — Dans `_build_ui()`, dans le bloc de création des tabs (lignes 134–147), ajouter après `_upscale_tab` :

```gdscript
_hires_tab = HiResTab.new()

_hires_tab.initialize(self, _url_input, _token_input, _negative_prompt_input,
    _show_image_preview, _open_gallery_source_picker, _save_config, _resolve_unique_path)

_hires_tab.build_tab(_tab_container)
```

**3.3d** — Dans `setup()` (ligne 67–69), ajouter :

```gdscript
_hires_tab.setup(story_base_path, has_story)
```

**3.3e** — Dans `_on_close()` (ligne 73–75), ajouter :

```gdscript
_hires_tab.cancel_generation()
```

**3.3f** — Dans `_update_all_generate_buttons()` (ligne 200–202), ajouter :

```gdscript
_hires_tab.update_generate_button()
```

**3.3g** — Dans `_update_cfg_hints()` (ligne 205–209), ajouter après la ligne `_expr_tab.update_cfg_hint(has_negative)` :

```gdscript
_hires_tab.update_cfg_hint(has_negative)
```

- [ ] **Step 3.4 : Lancer les tests pour vérifier qu'ils passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/plugins/ai_studio/test_ai_studio_plugin.gd 2>&1 | tail -20
```

Attendu : tous les tests passent, y compris `test_ai_studio_dialog_has_four_tabs`

- [ ] **Step 3.5 : Lancer la suite complète**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd 2>&1 | tail -30
```

Attendu : 0 failures, coverage ≥ 65%

- [ ] **Step 3.6 : Commit final**

```bash
git add plugins/ai_studio/ai_studio_dialog.gd specs/plugins/ai_studio/test_ai_studio_plugin.gd
git commit -m "feat(ai-studio): wire HiRes tab into Studio IA dialog as 4th tab"
```

---

## Vérification finale

- [ ] Lancer `/check-global-acceptance` (obligatoire avant de déclarer terminé)
