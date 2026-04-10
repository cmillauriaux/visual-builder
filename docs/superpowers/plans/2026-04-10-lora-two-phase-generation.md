# LORA Two-Phase Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the LORA Generator tab into two phases: Phase 1 generates/imports 6 canonical base images (one per framing type), Phase 2 generates dataset variations using those bases as sources for consistency.

**Architecture:** `lora_training_queue_service.gd` gains a `detect_base()` static method and updated `build_queue(bases, keyword, variations)`. The tab is split into three files: `lora_bases_panel.gd` (Phase 1 UI), `lora_variations_panel.gd` (Phase 2 UI), and `ai_studio_lora_generator_tab.gd` (orchestrator + shared grid).

**Tech Stack:** GDScript 4.6, GUT 9.3 for tests, ComfyUI via existing `ComfyUIClient`, Godot UI nodes only.

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `src/services/lora_training_queue_service.gd` | Add `detect_base()`, update `build_queue()` |
| Modify | `specs/services/test_lora_training_queue_service.gd` | Update + add tests for new API |
| Create | `plugins/ai_studio/lora_bases_panel.gd` | Phase 1: 6 base slots, import/generate, keyword, Phase 1 sliders |
| Create | `plugins/ai_studio/lora_variations_panel.gd` | Phase 2: 100 variation list, checkboxes, Phase 2 sliders, generate button |
| Modify | `plugins/ai_studio/ai_studio_lora_generator_tab.gd` | Slim orchestrator: build layout, connect signals, manage shared grid + both generation workflows |

---

## Task 1: `detect_base()` in LoraTrainingQueueService

**Files:**
- Modify: `src/services/lora_training_queue_service.gd`
- Modify: `specs/services/test_lora_training_queue_service.gd`

- [ ] **Step 1.1: Add tests for `detect_base()` at the top of the test file**

Add after the existing `before_each()` function in `specs/services/test_lora_training_queue_service.gd`:

```gdscript
func test_detect_base_closeup():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("close-up, front view, looking at viewer"), "closeup")

func test_detect_base_full_body():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("full body, front view, standing"), "full_body")

func test_detect_base_buste_upper_body():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("upper body, front view, standing"), "buste")

func test_detect_base_buste_waist_up():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("waist up, three-quarter view, sitting"), "buste")

func test_detect_base_three_quarter():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("portrait, three-quarter left view, looking at viewer"), "three_quarter")

func test_detect_base_profile_over_shoulder():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("portrait, looking over shoulder, neutral expression"), "profile")

func test_detect_base_portrait_default():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("portrait, front view, looking at viewer, smiling"), "portrait")

func test_detect_base_priority_closeup_over_upper_body():
	# "close-up" must win over "upper body" even if both appear
	assert_eq(LoraTrainingQueueServiceScript.detect_base("close-up, upper body, front view"), "closeup")

func test_detect_base_priority_full_body_over_buste():
	assert_eq(LoraTrainingQueueServiceScript.detect_base("full body, upper body, standing"), "full_body")
```

- [ ] **Step 1.2: Run tests to verify they fail**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_lora_training_queue_service.gd 2>&1 | grep -E "FAILED|PASSED|ERROR|detect_base"
```

Expected: FAILED — `detect_base` is not yet defined.

- [ ] **Step 1.3: Add `detect_base()` to `src/services/lora_training_queue_service.gd`**

Add after the `class_name LoraTrainingQueueService` line, before `enum ItemStatus`:

```gdscript
## Détecte le slot de base à utiliser pour une variation donnée.
## Priorité (premier match) :
##   1. "close-up"                         → "closeup"
##   2. "full body"                         → "full_body"
##   3. "upper body" ou "waist up"          → "buste"
##   4. "three-quarter"                     → "three_quarter"
##   5. "looking over shoulder" ou "profile"→ "profile"
##   6. (défaut)                            → "portrait"
static func detect_base(caption: String) -> String:
	if "close-up" in caption:
		return "closeup"
	if "full body" in caption:
		return "full_body"
	if "upper body" in caption or "waist up" in caption:
		return "buste"
	if "three-quarter" in caption:
		return "three_quarter"
	if "looking over shoulder" in caption or "profile" in caption:
		return "profile"
	return "portrait"
```

- [ ] **Step 1.4: Run tests to verify they pass**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_lora_training_queue_service.gd 2>&1 | grep -E "FAILED|PASSED|detect_base"
```

Expected: all 9 `detect_base` tests PASSED.

- [ ] **Step 1.5: Commit**

```bash
git add src/services/lora_training_queue_service.gd \
        specs/services/test_lora_training_queue_service.gd
git commit -m "feat(lora): add detect_base() static method to LoraTrainingQueueService"
```

---

## Task 2: Update `build_queue()` Signature

The new `build_queue(bases, keyword, variations)` takes a bases dict (one path per slot) instead of an array of source images, and creates one variation item per variation (no more "reference image" items — those are managed separately as base cards).

**Files:**
- Modify: `src/services/lora_training_queue_service.gd`
- Modify: `specs/services/test_lora_training_queue_service.gd`

- [ ] **Step 2.1: Rewrite the existing `build_queue` tests** (they use the old signature and will all break)

Replace every test that calls `svc.build_queue(...)` in `specs/services/test_lora_training_queue_service.gd`. The new helper constant to use at the top of the test file:

```gdscript
const BASES_FULL = {
	"closeup":       {"image": null, "path": "img_closeup.png"},
	"portrait":      {"image": null, "path": "img_portrait.png"},
	"three_quarter": {"image": null, "path": "img_3q.png"},
	"profile":       {"image": null, "path": "img_profile.png"},
	"buste":         {"image": null, "path": "img_buste.png"},
	"full_body":     {"image": null, "path": "img_fullbody.png"},
}
```

Replace all existing `test_build_queue_*` and other tests that call `svc.build_queue()` with:

```gdscript
func test_build_queue_creates_one_item_per_variation():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view", "full body, standing", "close-up, face"])
	assert_eq(svc.get_total(), 3, "One item per variation, no source reference items")

func test_build_queue_all_items_pending():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view", "full body, standing"])
	for item in svc.get_all_items():
		assert_eq(item["status"], LoraTrainingQueueServiceScript.ItemStatus.PENDING)

func test_build_queue_source_path_from_detected_base():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["full body, front view, standing"])
	var item = svc.get_all_items()[0]
	assert_eq(item["source_image_path"], "img_fullbody.png", "full body variation uses full_body base path")

func test_build_queue_source_path_closeup():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["close-up, front view, neutral expression"])
	var item = svc.get_all_items()[0]
	assert_eq(item["source_image_path"], "img_closeup.png")

func test_build_queue_source_path_portrait_default():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view, smiling"])
	var item = svc.get_all_items()[0]
	assert_eq(item["source_image_path"], "img_portrait.png")

func test_build_queue_caption_format():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view, smiling"])
	var item = svc.get_all_items()[0]
	assert_eq(item["caption"], "hero, portrait, front view, smiling")

func test_build_queue_empty_variations():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", [])
	assert_eq(svc.get_total(), 0)

func test_get_next_pending_returns_first_pending():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view", "full body, standing"])
	var idx = svc.get_next_pending_index()
	assert_eq(idx, 0)
	assert_eq(svc.get_all_items()[idx]["status"], LoraTrainingQueueServiceScript.ItemStatus.PENDING)

func test_get_next_pending_skips_completed():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view", "full body, standing"])
	svc.mark_completed(0, Image.new())
	var idx = svc.get_next_pending_index()
	assert_eq(idx, 1)

func test_get_next_pending_returns_minus_one_when_no_pending():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view"])
	svc.mark_completed(0, Image.new())
	assert_eq(svc.get_next_pending_index(), -1)

func test_mark_generating_sets_status():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view"])
	svc.mark_generating(0)
	assert_eq(svc.get_all_items()[0]["status"], LoraTrainingQueueServiceScript.ItemStatus.GENERATING)

func test_mark_completed_sets_status_and_image():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view"])
	var img = Image.new()
	svc.mark_completed(0, img)
	var item = svc.get_all_items()[0]
	assert_eq(item["status"], LoraTrainingQueueServiceScript.ItemStatus.COMPLETED)
	assert_eq(item["image"], img)

func test_mark_failed_sets_status():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view"])
	svc.mark_failed(0)
	assert_eq(svc.get_all_items()[0]["status"], LoraTrainingQueueServiceScript.ItemStatus.FAILED)

func test_get_completed_count():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view", "full body, standing"])
	assert_eq(svc.get_completed_count(), 0)
	svc.mark_completed(0, Image.new())
	assert_eq(svc.get_completed_count(), 1)

func test_cancel_sets_pending_to_failed():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view", "full body, standing"])
	svc.cancel()
	for item in svc.get_all_items():
		assert_eq(item["status"], LoraTrainingQueueServiceScript.ItemStatus.FAILED)

func test_is_cancelled():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view"])
	assert_false(svc.is_cancelled())
	svc.cancel()
	assert_true(svc.is_cancelled())

func test_clear_resets_queue():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view"])
	svc.cancel()
	svc.clear()
	assert_eq(svc.get_total(), 0)
	assert_false(svc.is_cancelled())

func test_remove_item():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view", "full body, standing"])
	svc.remove_item(0)
	assert_eq(svc.get_total(), 1)

func test_reset_item():
	var svc = LoraTrainingQueueServiceScript.new()
	svc.build_queue(BASES_FULL, "hero", ["portrait, front view"])
	var img = Image.new()
	svc.mark_completed(0, img)
	svc.reset_item(0)
	var item = svc.get_all_items()[0]
	assert_eq(item["status"], LoraTrainingQueueServiceScript.ItemStatus.PENDING)
	assert_null(item["image"])
```

- [ ] **Step 2.2: Run tests to verify they fail**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_lora_training_queue_service.gd 2>&1 | tail -20
```

Expected: several tests fail because `build_queue` still uses the old signature.

- [ ] **Step 2.3: Replace `build_queue()` in `src/services/lora_training_queue_service.gd`**

Replace the entire `build_queue` function:

```gdscript
## Construit la file depuis un dict de bases, un keyword LoRA et un tableau de variations.
## Pour chaque variation, le source_image_path est la base correspondante (via detect_base()).
## Aucun item "reference image" — les bases sont gérées séparément dans l'orchestrateur.
func build_queue(bases: Dictionary, keyword: String, variations: Array) -> void:
	_items.clear()
	_cancelled = false
	for variation in variations:
		var base_key = detect_base(variation)
		var source_path = bases[base_key]["path"] if bases.has(base_key) else ""
		_items.append({
			"source_image_path": source_path,
			"keyword": keyword,
			"variation_prompt": variation,
			"status": ItemStatus.PENDING,
			"image": null,
			"caption": "%s, %s" % [keyword, variation],
		})
```

- [ ] **Step 2.4: Run tests to verify they pass**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_lora_training_queue_service.gd 2>&1 | tail -10
```

Expected: all tests PASSED.

- [ ] **Step 2.5: Commit**

```bash
git add src/services/lora_training_queue_service.gd \
        specs/services/test_lora_training_queue_service.gd
git commit -m "feat(lora): update build_queue() to use bases dict — one variation item per variation"
```

---

## Task 3: Create `lora_bases_panel.gd`

Phase 1 UI: 6 base slots in a 2-column grid, keyword input, source images, Phase 1 sliders, generate-all button. Signals let the orchestrator handle ComfyUI.

**Files:**
- Create: `plugins/ai_studio/lora_bases_panel.gd`

- [ ] **Step 3.1: Create the file**

```gdscript
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Phase 1 panel: 6 base reference image slots.
## Handles import and emits signals for generation (orchestrated by the tab).

const LoraTrainingQueueService = preload("res://src/services/lora_training_queue_service.gd")

const BASE_SLOTS := [
	{"key": "closeup",       "label": "Close-up",     "prompt": "close-up, front view, looking at viewer, neutral expression, simple background, soft light"},
	{"key": "portrait",      "label": "Portrait",     "prompt": "portrait, front view, looking at viewer, neutral expression, simple background, soft light"},
	{"key": "three_quarter", "label": "3/4",          "prompt": "portrait, three-quarter left view, looking at viewer, neutral expression, simple background, soft light"},
	{"key": "profile",       "label": "Profil",       "prompt": "portrait, looking over shoulder, neutral expression, simple background, rim light"},
	{"key": "buste",         "label": "Buste",        "prompt": "upper body, front view, standing, looking at viewer, neutral expression, simple background, soft light"},
	{"key": "full_body",     "label": "Corps entier", "prompt": "full body, front view, standing, looking at viewer, neutral expression, simple background, soft light"},
]

## Emis quand une base est importée ou mise à jour.
signal bases_changed(bases: Dictionary)
## Emis quand l'utilisateur clique ⚡ sur un slot individuel.
signal generate_slot_pressed(slot_key: String, prompt: String)
## Emis quand l'utilisateur clique "GÉNÉRER TOUTES LES BASES".
signal generate_all_pressed

# ── Shared refs ─────────────────────────────────────────────────

var _parent_window: Window
var _show_preview_fn: Callable

# ── UI refs ─────────────────────────────────────────────────────

var _keyword_input: LineEdit
var _sources_flow: FlowContainer
var _add_images_btn: Button
var _denoise_slider: HSlider
var _denoise_value_label: Label
var _steps_slider: HSlider
var _steps_value_label: Label
var _cfg_slider: HSlider
var _cfg_value_label: Label
var _generate_all_btn: Button
## slot_key → {thumbnail, status_label, import_btn, generate_btn}
var _slot_widgets: Dictionary = {}

# ── State ────────────────────────────────────────────────────────

var _bases: Dictionary = {
	"closeup":       {"image": null, "path": ""},
	"portrait":      {"image": null, "path": ""},
	"three_quarter": {"image": null, "path": ""},
	"profile":       {"image": null, "path": ""},
	"buste":         {"image": null, "path": ""},
	"full_body":     {"image": null, "path": ""},
}
var _source_paths: Array[String] = []

# ── Public API ───────────────────────────────────────────────────

func initialize(parent_window: Window, show_preview_fn: Callable) -> void:
	_parent_window = parent_window
	_show_preview_fn = show_preview_fn


func build(parent: VBoxContainer) -> void:
	# Header
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 4)
	parent.add_child(header_hbox)
	var title_lbl = Label.new()
	title_lbl.text = "① BASES DE RÉFÉRENCE"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	# Keyword
	var kw_lbl = Label.new()
	kw_lbl.text = "Keyword (trigger word) :"
	parent.add_child(kw_lbl)
	_keyword_input = LineEdit.new()
	_keyword_input.placeholder_text = "ex: mychar_v1"
	parent.add_child(_keyword_input)

	parent.add_child(HSeparator.new())

	# 6 base slot grid (2 columns)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	for slot in BASE_SLOTS:
		var widget = _build_slot_widget(slot)
		grid.add_child(widget["root"])
		_slot_widgets[slot["key"]] = widget

	parent.add_child(HSeparator.new())

	# Source images for generation
	var src_lbl = Label.new()
	src_lbl.text = "Sources pour génération :"
	parent.add_child(src_lbl)
	_sources_flow = FlowContainer.new()
	_sources_flow.add_theme_constant_override("h_separation", 4)
	_sources_flow.add_theme_constant_override("v_separation", 4)
	parent.add_child(_sources_flow)
	_add_images_btn = Button.new()
	_add_images_btn.text = "+ Ajouter"
	_add_images_btn.pressed.connect(_on_add_sources_pressed)
	_sources_flow.add_child(_add_images_btn)

	# Phase 1 sliders
	_denoise_slider = _add_slider(parent, "Denoise", 0.0, 1.0, 0.05, 0.55)
	_denoise_value_label = _get_value_label(parent)

	_steps_slider = _add_slider(parent, "Steps", 1, 50, 1, 20)
	_steps_value_label = _get_value_label(parent)

	_cfg_slider = _add_slider(parent, "CFG", 1.0, 10.0, 0.1, 3.5)
	_cfg_value_label = _get_value_label(parent)

	_wire_slider(_denoise_slider, _denoise_value_label, 0.05)
	_wire_slider(_steps_slider, _steps_value_label, 1.0)
	_wire_slider(_cfg_slider, _cfg_value_label, 0.1)

	# Generate-all button
	_generate_all_btn = Button.new()
	_generate_all_btn.text = "⚡ GÉNÉRER TOUTES LES BASES"
	_generate_all_btn.pressed.connect(func(): generate_all_pressed.emit())
	parent.add_child(_generate_all_btn)


func get_bases() -> Dictionary:
	return _bases


func get_keyword() -> String:
	return _keyword_input.text.strip_edges() if _keyword_input != null else ""


func get_source_paths() -> Array[String]:
	return _source_paths


func get_first_source_path() -> String:
	return _source_paths[0] if not _source_paths.is_empty() else ""


func get_denoise() -> float:
	return _denoise_slider.value if _denoise_slider != null else 0.55


func get_steps() -> int:
	return int(_steps_slider.value) if _steps_slider != null else 20


func get_cfg() -> float:
	return _cfg_slider.value if _cfg_slider != null else 3.5


## Appelé par l'orchestrateur pendant la génération d'un slot.
func set_slot_generating(slot_key: String) -> void:
	var w = _slot_widgets.get(slot_key)
	if w == null:
		return
	w["status_label"].text = "⏳ génération..."
	w["status_label"].add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))


## Appelé par l'orchestrateur quand un slot est généré avec succès.
func set_slot_completed(slot_key: String, image: Image, temp_path: String) -> void:
	_set_base(slot_key, image, temp_path)


## Appelé par l'orchestrateur en cas d'échec.
func set_slot_failed(slot_key: String) -> void:
	var w = _slot_widgets.get(slot_key)
	if w == null:
		return
	w["status_label"].text = "✗ échec"
	w["status_label"].add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


func get_slot_prompt(slot_key: String) -> String:
	for slot in BASE_SLOTS:
		if slot["key"] == slot_key:
			return slot["prompt"]
	return ""

# ── Private ──────────────────────────────────────────────────────

func _build_slot_widget(slot: Dictionary) -> Dictionary:
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 80)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)

	var panel_vbox = VBoxContainer.new()
	panel_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_vbox.add_theme_constant_override("separation", 0)
	panel.add_child(panel_vbox)

	var thumb = TextureRect.new()
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb.mouse_filter = Control.MOUSE_FILTER_PASS
	panel_vbox.add_child(thumb)

	var bottom_bar = HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 2)
	panel_vbox.add_child(bottom_bar)

	var name_lbl = Label.new()
	name_lbl.text = slot["label"]
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_child(name_lbl)

	var import_btn = Button.new()
	import_btn.text = "📂"
	import_btn.custom_minimum_size = Vector2(26, 24)
	bottom_bar.add_child(import_btn)

	var generate_btn = Button.new()
	generate_btn.text = "⚡"
	generate_btn.custom_minimum_size = Vector2(26, 24)
	bottom_bar.add_child(generate_btn)

	var status_lbl = Label.new()
	status_lbl.add_theme_font_size_override("font_size", 8)
	status_lbl.text = "— vide"
	status_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	root.add_child(status_lbl)

	var slot_key: String = slot["key"]
	var slot_prompt: String = slot["prompt"]

	thumb.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _bases[slot_key]["image"] != null and _show_preview_fn.is_valid():
				_show_preview_fn.call(_bases[slot_key]["image"])
	)
	import_btn.pressed.connect(func(): _on_import_pressed(slot_key))
	generate_btn.pressed.connect(func(): generate_slot_pressed.emit(slot_key, slot_prompt))

	return {"root": root, "thumbnail": thumb, "status_label": status_lbl,
			"import_btn": import_btn, "generate_btn": generate_btn}


func _set_base(slot_key: String, image: Image, path: String) -> void:
	_bases[slot_key]["image"] = image
	_bases[slot_key]["path"] = path
	var w = _slot_widgets.get(slot_key)
	if w != null:
		w["thumbnail"].texture = ImageTexture.create_from_image(image)
		w["status_label"].text = "✓"
		w["status_label"].add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	bases_changed.emit(_bases)


func _on_import_pressed(slot_key: String) -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Images"])
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_selected.connect(func(path: String):
		var img = Image.new()
		if img.load(path) == OK:
			_set_base(slot_key, img, path)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	_parent_window.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))


func _on_add_sources_pressed() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Images"])
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.files_selected.connect(func(paths: PackedStringArray):
		for p in paths:
			if p not in _source_paths:
				_source_paths.append(p)
		_rebuild_source_thumbnails()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	_parent_window.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))


func _rebuild_source_thumbnails() -> void:
	for child in _sources_flow.get_children():
		child.queue_free()
	for path in _source_paths:
		var hbox = HBoxContainer.new()
		var thumb = TextureRect.new()
		thumb.custom_minimum_size = Vector2(36, 36)
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		var img = Image.new()
		if img.load(path) == OK:
			thumb.texture = ImageTexture.create_from_image(img)
		hbox.add_child(thumb)
		var remove_btn = Button.new()
		remove_btn.text = "×"
		remove_btn.custom_minimum_size = Vector2(20, 20)
		var captured = path
		remove_btn.pressed.connect(func():
			_source_paths.erase(captured)
			_rebuild_source_thumbnails()
		)
		hbox.add_child(remove_btn)
		_sources_flow.add_child(hbox)
	_sources_flow.add_child(_add_images_btn)


func _add_slider(parent: VBoxContainer, label: String,
		min_v: float, max_v: float, step: float, default_v: float) -> HSlider:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)
	var lbl = Label.new()
	lbl.text = label
	lbl.custom_minimum_size.x = 55
	hbox.add_child(lbl)
	var slider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = default_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)
	# Value label placeholder — caller will add it separately via _get_value_label
	return slider


func _get_value_label(parent: VBoxContainer) -> Label:
	# The value label was added to the last HBoxContainer child
	var hbox = parent.get_child(parent.get_child_count() - 1) as HBoxContainer
	var lbl = Label.new()
	lbl.custom_minimum_size.x = 36
	hbox.add_child(lbl)
	return lbl


func _wire_slider(slider: HSlider, value_label: Label, snap: float) -> void:
	value_label.text = str(snapped(slider.value, snap))
	slider.value_changed.connect(func(v: float):
		value_label.text = str(snapped(v, snap))
	)
```

- [ ] **Step 3.2: Verify the file parses (no GDScript errors)**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 10 $GODOT --headless --path . --check-only \
  res://plugins/ai_studio/lora_bases_panel.gd 2>&1
```

Expected: no errors printed, process exits 0.

- [ ] **Step 3.3: Commit**

```bash
git add plugins/ai_studio/lora_bases_panel.gd
git commit -m "feat(lora): add lora_bases_panel.gd — Phase 1 UI with 6 base slots"
```

---

## Task 4: Create `lora_variations_panel.gd`

Phase 2 UI: extracted and adapted from the current tab. Key additions: each row shows an auto-detected base badge, the generate button checks that required bases are not all empty.

**Files:**
- Create: `plugins/ai_studio/lora_variations_panel.gd`

- [ ] **Step 4.1: Create the file**

```gdscript
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Phase 2 panel: 100 predefined dataset variations with checkboxes.
## Emits generate_pressed(selected_variations) for the orchestrator to handle.

const LoraTrainingQueueService = preload("res://src/services/lora_training_queue_service.gd")

## Couleurs des badges par slot key
const BADGE_COLORS := {
	"closeup":       Color(0.3, 0.8, 0.4),   # vert
	"portrait":      Color(0.3, 0.5, 1.0),   # bleu
	"three_quarter": Color(0.7, 0.3, 1.0),   # violet
	"profile":       Color(1.0, 0.6, 0.2),   # orange
	"buste":         Color(0.2, 0.8, 0.9),   # cyan
	"full_body":     Color(1.0, 0.9, 0.2),   # jaune
}

const BADGE_LABELS := {
	"closeup":       "Close-up",
	"portrait":      "Portrait",
	"three_quarter": "3/4",
	"profile":       "Profil",
	"buste":         "Buste",
	"full_body":     "Corps",
}

## Emis quand l'utilisateur clique GÉNÉRER avec les variations sélectionnées.
signal generate_pressed(selected_variations: Array)

# ── UI refs ─────────────────────────────────────────────────────

var _variation_checkboxes: Array = []  # [{checkbox, value}]
var _custom_variations_list: VBoxContainer
var _custom_add_input: LineEdit
var _denoise_slider: HSlider
var _denoise_value_label: Label
var _steps_slider: HSlider
var _steps_value_label: Label
var _cfg_slider: HSlider
var _cfg_value_label: Label
var _generate_btn: Button
var _parent_window: Window

# ── PREDEFINED_VARIATIONS list (same as currently defined in the tab) ────────
# (100 entries — see ai_studio_lora_generator_tab.gd PREDEFINED_VARIATIONS const)
# This panel reads them from the tab constant to stay DRY.
# The tab passes them in via build().

# ── Public API ───────────────────────────────────────────────────

func initialize(parent_window: Window) -> void:
	_parent_window = parent_window


func build(parent: VBoxContainer, predefined_variations: Array) -> void:
	# Header
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 4)
	parent.add_child(header_hbox)
	var title_lbl = Label.new()
	title_lbl.text = "② DÉCLINAISONS"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	# Select all / none row
	var sel_hbox = HBoxContainer.new()
	sel_hbox.add_theme_constant_override("separation", 4)
	parent.add_child(sel_hbox)
	var pred_lbl = Label.new()
	pred_lbl.text = "Variations prédéfinies :"
	pred_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_hbox.add_child(pred_lbl)
	var select_all_btn = Button.new()
	select_all_btn.text = "Tout"
	select_all_btn.pressed.connect(func():
		for e in _variation_checkboxes:
			e["checkbox"].button_pressed = true
		_update_generate_button()
	)
	sel_hbox.add_child(select_all_btn)
	var deselect_all_btn = Button.new()
	deselect_all_btn.text = "Aucun"
	deselect_all_btn.pressed.connect(func():
		for e in _variation_checkboxes:
			e["checkbox"].button_pressed = false
		_update_generate_button()
	)
	sel_hbox.add_child(deselect_all_btn)

	# Variation list
	var pred_vbox = VBoxContainer.new()
	pred_vbox.add_theme_constant_override("separation", 2)
	parent.add_child(pred_vbox)

	for entry in predefined_variations:
		if entry.has("group"):
			var group_lbl = Label.new()
			group_lbl.text = entry["group"]
			group_lbl.add_theme_font_size_override("font_size", 10)
			group_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
			pred_vbox.add_child(group_lbl)
		else:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			pred_vbox.add_child(row)

			var cb = CheckBox.new()
			cb.text = entry["label"]
			cb.button_pressed = false
			cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cb.toggled.connect(func(_p): _update_generate_button())
			row.add_child(cb)

			# Auto-detected base badge
			var base_key = LoraTrainingQueueService.detect_base(entry["value"])
			var badge = Label.new()
			badge.text = BADGE_LABELS.get(base_key, base_key)
			badge.add_theme_font_size_override("font_size", 8)
			badge.add_theme_color_override("font_color", BADGE_COLORS.get(base_key, Color.WHITE))
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(badge)

			_variation_checkboxes.append({"checkbox": cb, "value": entry["value"]})

	parent.add_child(HSeparator.new())

	# Custom variations
	var custom_lbl = Label.new()
	custom_lbl.text = "Variations personnalisées :"
	parent.add_child(custom_lbl)
	_custom_variations_list = VBoxContainer.new()
	_custom_variations_list.add_theme_constant_override("separation", 4)
	parent.add_child(_custom_variations_list)
	var custom_add_hbox = HBoxContainer.new()
	custom_add_hbox.add_theme_constant_override("separation", 4)
	parent.add_child(custom_add_hbox)
	_custom_add_input = LineEdit.new()
	_custom_add_input.placeholder_text = "Ajouter..."
	_custom_add_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_add_hbox.add_child(_custom_add_input)
	var custom_add_btn = Button.new()
	custom_add_btn.text = "+"
	custom_add_btn.pressed.connect(_on_add_custom_variation)
	custom_add_hbox.add_child(custom_add_btn)

	parent.add_child(HSeparator.new())

	# Phase 2 sliders
	_build_slider_row(parent, "Denoise", 0.0, 1.0, 0.05, 0.65,
		func(v: float): _denoise_value_label.text = str(snapped(v, 0.05)),
		func() -> HSlider: return _denoise_slider
	)
	_denoise_slider = _last_slider(parent)
	_denoise_value_label = _last_value_label(parent)

	_build_slider_row(parent, "Steps", 1, 50, 1, 20,
		func(v: float): _steps_value_label.text = str(int(v)),
		func() -> HSlider: return _steps_slider
	)
	_steps_slider = _last_slider(parent)
	_steps_value_label = _last_value_label(parent)

	_build_slider_row(parent, "CFG", 1.0, 10.0, 0.1, 3.5,
		func(v: float): _cfg_value_label.text = str(snapped(v, 0.1)),
		func() -> HSlider: return _cfg_slider
	)
	_cfg_slider = _last_slider(parent)
	_cfg_value_label = _last_value_label(parent)

	# Generate button
	_generate_btn = Button.new()
	_generate_btn.text = "GÉNÉRER"
	_generate_btn.disabled = true
	_generate_btn.pressed.connect(func(): generate_pressed.emit(get_selected_variations()))
	parent.add_child(_generate_btn)

	_update_generate_button()


func get_selected_variations() -> Array:
	var result: Array = []
	for entry in _variation_checkboxes:
		if entry["checkbox"].button_pressed:
			result.append(entry["value"])
	for child in _custom_variations_list.get_children():
		if child is HBoxContainer:
			var le = child.get_child(0)
			if le is LineEdit and le.text.strip_edges() != "":
				result.append(le.text.strip_edges())
	return result


func get_denoise() -> float:
	return _denoise_slider.value if _denoise_slider != null else 0.65


func get_steps() -> int:
	return int(_steps_slider.value) if _steps_slider != null else 20


func get_cfg() -> float:
	return _cfg_slider.value if _cfg_slider != null else 3.5


func set_generating(is_generating: bool) -> void:
	if _generate_btn != null:
		_generate_btn.disabled = is_generating
	if not is_generating:
		_update_generate_button()

# ── Private ──────────────────────────────────────────────────────

func _update_generate_button() -> void:
	if _generate_btn == null:
		return
	var has_variations = not get_selected_variations().is_empty()
	_generate_btn.disabled = not has_variations
	if has_variations:
		_generate_btn.text = "GÉNÉRER (%d variations)" % get_selected_variations().size()
	else:
		_generate_btn.text = "GÉNÉRER"


func _on_add_custom_variation() -> void:
	var text = _custom_add_input.text.strip_edges()
	if text == "":
		return
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	var le = LineEdit.new()
	le.text = text
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(_t): _update_generate_button())
	hbox.add_child(le)
	var del_btn = Button.new()
	del_btn.text = "×"
	del_btn.custom_minimum_size = Vector2(28, 0)
	del_btn.pressed.connect(func():
		hbox.queue_free()
		_update_generate_button()
	)
	hbox.add_child(del_btn)
	_custom_variations_list.add_child(hbox)
	_custom_add_input.text = ""
	_update_generate_button()


# Helpers to build slider rows — returns the HBoxContainer added to parent.
func _build_slider_row(parent: VBoxContainer, label_text: String,
		min_v: float, max_v: float, step: float, default_v: float,
		_on_change: Callable, _getter: Callable) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 55
	hbox.add_child(lbl)
	var slider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = default_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)
	var val_lbl = Label.new()
	val_lbl.text = str(snapped(default_v, step))
	val_lbl.custom_minimum_size.x = 36
	hbox.add_child(val_lbl)
	slider.value_changed.connect(func(v: float): val_lbl.text = str(snapped(v, step)))


func _last_slider(parent: VBoxContainer) -> HSlider:
	var hbox = parent.get_child(parent.get_child_count() - 1) as HBoxContainer
	return hbox.get_child(1) as HSlider


func _last_value_label(parent: VBoxContainer) -> Label:
	var hbox = parent.get_child(parent.get_child_count() - 1) as HBoxContainer
	return hbox.get_child(2) as Label
```

- [ ] **Step 4.2: Verify the file parses**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 10 $GODOT --headless --path . --check-only \
  res://plugins/ai_studio/lora_variations_panel.gd 2>&1
```

Expected: no errors.

- [ ] **Step 4.3: Commit**

```bash
git add plugins/ai_studio/lora_variations_panel.gd
git commit -m "feat(lora): add lora_variations_panel.gd — Phase 2 UI with base badges"
```

---

## Task 5: Rewrite `ai_studio_lora_generator_tab.gd` as Orchestrator

Replaces the current monolithic file. The tab now owns: layout, the shared results grid (6 base cards + variation cards), and both generation workflows (base img2img + variation img2img).

**Files:**
- Modify: `plugins/ai_studio/ai_studio_lora_generator_tab.gd`

- [ ] **Step 5.1: Replace the file content entirely**

```gdscript
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Tab "LORA Generator" — orchestrateur deux phases.
##
## Phase 1 (lora_bases_panel) : génère/importe 6 images de base canoniques.
## Phase 2 (lora_variations_panel) : génère 100 variations en utilisant les bases comme sources.

const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
const LoraTrainingQueueService = preload("res://src/services/lora_training_queue_service.gd")
const LoraBasesPanel = preload("res://plugins/ai_studio/lora_bases_panel.gd")
const LoraVariationsPanel = preload("res://plugins/ai_studio/lora_variations_panel.gd")

## Dataset de 100 variations prédéfinies (voir PREDEFINED_VARIATIONS au bas du fichier).

# ── Shared refs ─────────────────────────────────────────────────

var _parent_window: Window
var _get_config_fn: Callable
var _neg_input: TextEdit
var _show_preview_fn: Callable
var _open_gallery_fn: Callable
var _save_config_fn: Callable
var _resolve_path_fn: Callable

# ── Sub-panels ───────────────────────────────────────────────────

var _bases_panel: RefCounted = null
var _variations_panel: RefCounted = null

# ── Right panel UI ───────────────────────────────────────────────

var _status_label: Label
var _save_all_btn: Button
var _grid_container: GridContainer
## slot_key → {thumbnail, status_label} in the results grid
var _base_grid_cards: Dictionary = {}
var _variation_card_widgets: Array = []  # [{thumbnail, status_label, regen_btn, delete_btn, caption_edit}]

# ── Generation state ─────────────────────────────────────────────

var _client: Node = null
var _generating_bases: bool = false
var _generating_variations: bool = false
## Queue of slot keys to generate in Phase 1 (populated on "generate all")
var _base_generation_queue: Array[String] = []
var _current_base_slot: String = ""
## Phase 2 variation queue
var _queue: RefCounted = null
var _current_item_index: int = -1

# ── Public API ───────────────────────────────────────────────────

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
	var hbox_root = HSplitContainer.new()
	hbox_root.name = "LORA Generator"
	hbox_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(hbox_root)

	# ── Left panel ──────────────────────────────────────────────
	var left_scroll = ScrollContainer.new()
	left_scroll.custom_minimum_size.x = 220
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox_root.add_child(left_scroll)

	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left_vbox)

	# Phase 1 — bases panel
	_bases_panel = LoraBasesPanel.new()
	_bases_panel.initialize(_parent_window, _show_preview_fn)
	_bases_panel.build(left_vbox)
	_bases_panel.generate_all_pressed.connect(_on_generate_all_bases_pressed)
	_bases_panel.generate_slot_pressed.connect(_on_generate_slot_pressed)

	left_vbox.add_child(HSeparator.new())

	# Phase 2 — variations panel
	_variations_panel = LoraVariationsPanel.new()
	_variations_panel.initialize(_parent_window)
	_variations_panel.build(left_vbox, PREDEFINED_VARIATIONS)
	_variations_panel.generate_pressed.connect(_on_generate_variations_pressed)

	# ── Right panel ─────────────────────────────────────────────
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 6)
	hbox_root.add_child(right_vbox)
	hbox_root.split_offset = 280

	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	right_vbox.add_child(top_bar)

	_status_label = Label.new()
	_status_label.text = "0 / 0 générées"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(_status_label)

	var load_btn = Button.new()
	load_btn.text = "Charger dossier"
	load_btn.pressed.connect(_on_load_folder_pressed)
	top_bar.add_child(load_btn)

	_save_all_btn = Button.new()
	_save_all_btn.text = "Sauvegarder tout"
	_save_all_btn.disabled = true
	_save_all_btn.pressed.connect(_on_save_all_pressed)
	top_bar.add_child(_save_all_btn)

	var grid_scroll = ScrollContainer.new()
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(grid_scroll)

	_grid_container = GridContainer.new()
	_grid_container.columns = 4
	_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_container.add_theme_constant_override("h_separation", 8)
	_grid_container.add_theme_constant_override("v_separation", 8)
	grid_scroll.add_child(_grid_container)

	_build_base_grid_cards()


func setup(_story_base_path: String, _has_story: bool) -> void:
	pass


func update_generate_button() -> void:
	pass


func update_cfg_hint(_has_negative: bool) -> void:
	pass


func cancel_generation() -> void:
	if _client != null:
		_client.cancel()
		_client.queue_free()
		_client = null
	if _queue != null:
		_queue.cancel()
	_generating_bases = false
	_generating_variations = false
	_base_generation_queue.clear()
	_current_base_slot = ""
	_current_item_index = -1
	if _variations_panel != null:
		_variations_panel.set_generating(false)

# ── Phase 1 — base generation ────────────────────────────────────

func _on_generate_all_bases_pressed() -> void:
	if _generating_bases or _generating_variations:
		return
	var source_path = _bases_panel.get_first_source_path()
	if source_path == "":
		_status_label.text = "Ajoutez au moins une image source"
		return
	# Queue all 6 slots
	_base_generation_queue.clear()
	for slot in LoraBasesPanel.BASE_SLOTS:
		_base_generation_queue.append(slot["key"])
	_generating_bases = true
	_process_next_base()


func _on_generate_slot_pressed(slot_key: String, _prompt: String) -> void:
	if _generating_bases or _generating_variations:
		return
	var source_path = _bases_panel.get_first_source_path()
	if source_path == "":
		_status_label.text = "Ajoutez au moins une image source"
		return
	_base_generation_queue = [slot_key]
	_generating_bases = true
	_process_next_base()


func _process_next_base() -> void:
	if _base_generation_queue.is_empty():
		_generating_bases = false
		_status_label.text = "Bases générées"
		return

	_current_base_slot = _base_generation_queue.pop_front()
	_bases_panel.set_slot_generating(_current_base_slot)
	_update_base_grid_card_status(_current_base_slot, "⏳", Color(1.0, 0.7, 0.2))
	_status_label.text = "Génération base : %s" % _current_base_slot

	_start_client()
	var config = _get_config_fn.call()
	var source_path = _bases_panel.get_first_source_path()
	var prompt = "%s, %s" % [_bases_panel.get_keyword(), _bases_panel.get_slot_prompt(_current_base_slot)]
	_client.generation_completed.connect(_on_base_completed)
	_client.generation_failed.connect(_on_base_failed)
	_client.generate(
		config, source_path, prompt, false,
		_bases_panel.get_cfg(), _bases_panel.get_steps(),
		ComfyUIClient.WorkflowType.CREATION,
		_bases_panel.get_denoise(), "", 80, 1.0
	)


func _on_base_completed(image: Image) -> void:
	var temp_path = "user://lora_base_%s.png" % _current_base_slot
	image.save_png(ProjectSettings.globalize_path(temp_path))
	_bases_panel.set_slot_completed(_current_base_slot, image, ProjectSettings.globalize_path(temp_path))
	_update_base_grid_card(_current_base_slot, image)
	_cleanup_client()
	_process_next_base()


func _on_base_failed(_error: String) -> void:
	_bases_panel.set_slot_failed(_current_base_slot)
	_update_base_grid_card_status(_current_base_slot, "✗", Color(0.9, 0.3, 0.3))
	_cleanup_client()
	_process_next_base()

# ── Phase 2 — variation generation ───────────────────────────────

func _on_generate_variations_pressed(selected_variations: Array) -> void:
	if _generating_bases or _generating_variations:
		return
	var keyword = _bases_panel.get_keyword()
	if keyword == "":
		_status_label.text = "Saisissez un keyword"
		return
	var bases = _bases_panel.get_bases()
	_queue = LoraTrainingQueueService.new()
	_queue.build_queue(bases, keyword, selected_variations)
	_generating_variations = true
	_current_item_index = -1
	_variations_panel.set_generating(true)
	_save_all_btn.disabled = true
	_rebuild_variation_grid()
	_update_variation_status()
	_process_next_variation()


func _process_next_variation() -> void:
	if _queue == null or _queue.is_cancelled():
		_on_variation_batch_finished()
		return
	var idx = _queue.get_next_pending_index()
	if idx == -1:
		_on_variation_batch_finished()
		return

	_queue.mark_generating(idx)
	_current_item_index = idx
	_update_variation_card_status(idx)
	_update_variation_status()

	_start_client()
	var config = _get_config_fn.call()
	var item = _queue.get_all_items()[idx]
	_client.generation_completed.connect(_on_variation_completed)
	_client.generation_failed.connect(_on_variation_failed)
	_client.generation_progress.connect(_on_variation_progress)
	_client.generate(
		config, item["source_image_path"], item["caption"], false,
		_variations_panel.get_cfg(), _variations_panel.get_steps(),
		ComfyUIClient.WorkflowType.CREATION,
		_variations_panel.get_denoise(), "", 80, 1.0
	)


func _on_variation_completed(image: Image) -> void:
	_queue.mark_completed(_current_item_index, image)
	_update_variation_card_image(_current_item_index, image)
	_update_variation_card_status(_current_item_index)
	_update_variation_status()
	_cleanup_client()
	_process_next_variation()


func _on_variation_failed(_error: String) -> void:
	_queue.mark_failed(_current_item_index)
	_update_variation_card_status(_current_item_index)
	_update_variation_status()
	_cleanup_client()
	_process_next_variation()


func _on_variation_progress(status: String) -> void:
	if _queue != null:
		_status_label.text = "%d / %d — %s" % [
			_queue.get_completed_count(), _queue.get_total(), status]


func _on_variation_batch_finished() -> void:
	_generating_variations = false
	_variations_panel.set_generating(false)
	if _queue != null and _queue.get_completed_count() > 0:
		_save_all_btn.disabled = false
		_status_label.text = "%d / %d générées" % [_queue.get_completed_count(), _queue.get_total()]
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		_status_label.text = "Génération terminée (aucun résultat)"

# ── Grid — base cards ─────────────────────────────────────────────

func _build_base_grid_cards() -> void:
	for slot in LoraBasesPanel.BASE_SLOTS:
		var card = _create_base_card(slot["key"], slot["label"])
		_grid_container.add_child(card["root"])
		_base_grid_cards[slot["key"]] = card


func _create_base_card(slot_key: String, slot_label: String) -> Dictionary:
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	root.custom_minimum_size = Vector2(120, 0)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 120)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)

	var panel_vbox = VBoxContainer.new()
	panel_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_vbox.add_theme_constant_override("separation", 0)
	panel.add_child(panel_vbox)

	var thumb = TextureRect.new()
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_vbox.add_child(thumb)

	var bottom_bar = HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 2)
	panel_vbox.add_child(bottom_bar)

	var badge = Label.new()
	badge.text = "BASE %s" % slot_label
	badge.add_theme_font_size_override("font_size", 8)
	badge.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_child(badge)

	var status_lbl = Label.new()
	status_lbl.add_theme_font_size_override("font_size", 8)
	status_lbl.text = "—"
	status_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status_lbl)

	return {"root": root, "thumbnail": thumb, "status_label": status_lbl}


func _update_base_grid_card(slot_key: String, image: Image) -> void:
	var card = _base_grid_cards.get(slot_key)
	if card == null:
		return
	card["thumbnail"].texture = ImageTexture.create_from_image(image)
	_update_base_grid_card_status(slot_key, "✓", Color(0.4, 0.9, 0.4))


func _update_base_grid_card_status(slot_key: String, text: String, color: Color) -> void:
	var card = _base_grid_cards.get(slot_key)
	if card == null:
		return
	card["status_label"].text = text
	card["status_label"].add_theme_color_override("font_color", color)

# ── Grid — variation cards ────────────────────────────────────────

func _rebuild_variation_grid() -> void:
	for w in _variation_card_widgets:
		w["root"].queue_free()
	_variation_card_widgets.clear()
	if _queue == null:
		return
	var items = _queue.get_all_items()
	for i in range(items.size()):
		var card_data = _create_variation_card(i, items[i])
		_grid_container.add_child(card_data["root"])
		_variation_card_widgets.append(card_data)


func _create_variation_card(card_idx: int, item: Dictionary) -> Dictionary:
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	root.custom_minimum_size = Vector2(120, 0)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 120)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)

	var panel_vbox = VBoxContainer.new()
	panel_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_vbox.add_theme_constant_override("separation", 0)
	panel.add_child(panel_vbox)

	var thumb = TextureRect.new()
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_vbox.add_child(thumb)

	var bottom_bar = HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 2)
	panel_vbox.add_child(bottom_bar)

	var status_lbl = Label.new()
	status_lbl.add_theme_font_size_override("font_size", 10)
	status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_child(status_lbl)

	var regen_btn = Button.new()
	regen_btn.text = "↺"
	regen_btn.custom_minimum_size = Vector2(24, 24)
	bottom_bar.add_child(regen_btn)

	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.custom_minimum_size = Vector2(24, 24)
	bottom_bar.add_child(delete_btn)

	var caption_edit = TextEdit.new()
	caption_edit.custom_minimum_size = Vector2(0, 50)
	caption_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	caption_edit.text = item["caption"]
	root.add_child(caption_edit)

	caption_edit.text_changed.connect(func():
		if _queue == null or card_idx >= _queue.get_total():
			return
		_queue.get_all_items()[card_idx]["caption"] = caption_edit.text
	)

	regen_btn.pressed.connect(func():
		if _queue == null or card_idx >= _queue.get_total():
			return
		_queue.reset_item(card_idx)
		_update_variation_card_status(card_idx)
		if not _generating_variations:
			_generating_variations = true
			_variations_panel.set_generating(true)
			_save_all_btn.disabled = true
			_process_next_variation()
	)

	delete_btn.pressed.connect(func():
		if _generating_variations or _queue == null or card_idx >= _queue.get_total():
			return
		_queue.remove_item(card_idx)
		_rebuild_variation_grid()
		_update_variation_status()
		if _queue.get_total() == 0:
			_save_all_btn.disabled = true
	)

	var card_data = {
		"root": root, "thumbnail": thumb, "status_label": status_lbl,
		"regen_btn": regen_btn, "delete_btn": delete_btn, "caption_edit": caption_edit,
	}
	_apply_variation_card_status(card_data, item)
	return card_data


func _update_variation_card_status(idx: int) -> void:
	if idx < 0 or idx >= _variation_card_widgets.size() or _queue == null:
		return
	if idx >= _queue.get_total():
		return
	_apply_variation_card_status(_variation_card_widgets[idx], _queue.get_all_items()[idx])


func _apply_variation_card_status(card_data: Dictionary, item: Dictionary) -> void:
	var lbl: Label = card_data["status_label"]
	match item["status"]:
		LoraTrainingQueueService.ItemStatus.COMPLETED:
			lbl.text = "✓"
			lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		LoraTrainingQueueService.ItemStatus.GENERATING:
			lbl.text = "⏳"
			lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
		LoraTrainingQueueService.ItemStatus.FAILED:
			lbl.text = "✗"
			lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		_:
			lbl.text = "…"
			lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))


func _update_variation_card_image(idx: int, image: Image) -> void:
	if idx < 0 or idx >= _variation_card_widgets.size():
		return
	_variation_card_widgets[idx]["thumbnail"].texture = ImageTexture.create_from_image(image)


func _update_variation_status() -> void:
	if _queue == null:
		return
	_status_label.text = "%d / %d générées" % [_queue.get_completed_count(), _queue.get_total()]
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

# ── Save / Load ───────────────────────────────────────────────────

func _on_save_all_pressed() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.title = "Choisir le dossier de destination"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.dir_selected.connect(func(path: String):
		_do_save_all(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	_parent_window.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))


func _do_save_all(dir_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir_path)
	var items = _queue.get_all_items()
	var saved_count = 0
	for item in items:
		if item["status"] != LoraTrainingQueueService.ItemStatus.COMPLETED:
			continue
		var img: Image = item["image"]
		if img == null:
			continue
		saved_count += 1
		var base = "%03d" % saved_count
		img.save_png(dir_path + "/" + base + ".png")
		var f = FileAccess.open(dir_path + "/" + base + ".txt", FileAccess.WRITE)
		if f:
			f.store_string(item["caption"])
			f.close()
	_status_label.text = "%d fichiers sauvegardés dans %s" % [saved_count, dir_path.get_file()]


func _on_load_folder_pressed() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.title = "Charger un dataset existant"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.dir_selected.connect(func(path: String):
		_load_folder(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	_parent_window.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))


func _load_folder(dir_path: String) -> void:
	cancel_generation()
	_queue = LoraTrainingQueueService.new()

	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	var image_files: Array[String] = []
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var ext = fname.get_extension().to_lower()
			if ext in ["png", "jpg", "webp"]:
				image_files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	image_files.sort()

	for img_file in image_files:
		var img_path = dir_path + "/" + img_file
		var txt_path = dir_path + "/" + img_file.get_basename() + ".txt"
		var caption = ""
		if FileAccess.file_exists(txt_path):
			var f = FileAccess.open(txt_path, FileAccess.READ)
			if f:
				caption = f.get_as_text().strip_edges()
				f.close()
		var img = Image.new()
		var ok = img.load(img_path)
		_queue.get_all_items().append({
			"source_image_path": img_path,
			"keyword": "",
			"variation_prompt": img_file.get_basename(),
			"status": LoraTrainingQueueService.ItemStatus.COMPLETED,
			"image": img if ok == OK else null,
			"caption": caption,
		})

	_rebuild_variation_grid()
	_update_variation_status()
	if _queue.get_completed_count() > 0:
		_save_all_btn.disabled = false

# ── ComfyUI client helper ─────────────────────────────────────────

func _start_client() -> void:
	if _client != null:
		_client.cancel()
		_client.queue_free()
	_client = Node.new()
	_client.set_script(ComfyUIClient)
	_parent_window.add_child(_client)


func _cleanup_client() -> void:
	if _client != null:
		_client.queue_free()
		_client = null


# ── PREDEFINED_VARIATIONS ─────────────────────────────────────────
## (identical to the const defined before the rewrite — keep in sync)
const PREDEFINED_VARIATIONS = [
	{"group": "Portraits neutres"},
	{"label": "001 portrait front neutral 01", "value": "portrait, front view, looking at viewer, neutral expression, simple background, soft light"},
	{"label": "002 portrait front neutral 02", "value": "portrait, front view, looking at viewer, neutral expression, white background, studio light"},
	{"label": "003 portrait front neutral 03", "value": "portrait, front view, looking at viewer, neutral expression, soft gradient background, daylight"},
	{"label": "004 portrait closeup neutral 04", "value": "close-up, front view, looking at viewer, neutral expression, simple background, warm light"},
	{"label": "005 portrait closeup neutral 05", "value": "close-up, front view, looking at viewer, neutral expression, outdoor background, natural light"},
	{"label": "006 portrait slight up neutral 06", "value": "portrait, slight up angle, looking at viewer, neutral expression, simple background, soft light"},
	{"label": "007 portrait slight down neutral 07", "value": "portrait, slight down angle, looking at viewer, neutral expression, simple background, cinematic light"},
	{"label": "008 portrait front lookaway 08", "value": "portrait, front view, looking away, neutral expression, simple background, soft light"},
	{"label": "009 portrait front eyesclosed 09", "value": "portrait, front view, eyes closed, relaxed expression, simple background, soft light"},
	{"label": "010 portrait front rimlight 10", "value": "portrait, front view, looking at viewer, neutral expression, dark background, rim light"},
	{"label": "011 portrait closeup amateurlight 11", "value": "close-up, front view, looking at viewer, neutral expression, blur background, amateur light"},
	{"label": "012 portrait front highcontrast 12", "value": "portrait, front view, looking at viewer, neutral expression, simple background, high contrast light"},
	{"group": "Expressions"},
	{"label": "013 smile 01", "value": "portrait, front view, looking at viewer, smiling, simple background, soft light"},
	{"label": "014 laughing 02", "value": "portrait, front view, looking at viewer, laughing, open mouth, simple background, warm light"},
	{"label": "015 happy 03", "value": "portrait, front view, looking at viewer, happy expression, simple background, daylight"},
	{"label": "016 angry 04", "value": "portrait, front view, looking at viewer, angry expression, simple background, dramatic light"},
	{"label": "017 sad 05", "value": "portrait, front view, looking at viewer, sad expression, simple background, soft light"},
	{"label": "018 surprised 06", "value": "portrait, front view, looking at viewer, surprised expression, open mouth, simple background"},
	{"label": "019 shy 07", "value": "portrait, front view, looking at viewer, shy expression, blushing, simple background, soft light"},
	{"label": "020 determined 08", "value": "portrait, front view, looking at viewer, determined expression, simple background, cinematic light"},
	{"label": "021 confused 09", "value": "portrait, front view, looking at viewer, confused expression, simple background, soft light"},
	{"label": "022 serious 10", "value": "portrait, front view, looking at viewer, serious expression, simple background, rim light"},
	{"label": "023 smirk 11", "value": "portrait, front view, looking at viewer, teasing expression, smirk, simple background"},
	{"label": "024 crying 12", "value": "portrait, front view, looking at viewer, crying expression, tears, simple background"},
	{"label": "025 winking 13", "value": "portrait, front view, winking, smiling, simple background, soft light"},
	{"label": "026 sleepy 14", "value": "portrait, front view, looking at viewer, sleepy expression, eyes half closed, simple background"},
	{"group": "Angles"},
	{"label": "027 3/4 left 01", "value": "portrait, three-quarter left view, looking at viewer, neutral expression, simple background, soft light"},
	{"label": "028 3/4 right 02", "value": "portrait, three-quarter right view, looking at viewer, neutral expression, simple background, soft light"},
	{"label": "029 3/4 left smile 03", "value": "portrait, three-quarter left view, looking away, smiling, simple background, daylight"},
	{"label": "030 3/4 right lookaway 04", "value": "portrait, three-quarter right view, looking away, neutral expression, outdoor, natural light"},
	{"label": "031 slight up smile 05", "value": "portrait, slight up angle, looking at viewer, smiling, simple background, soft light"},
	{"label": "032 slight down serious 06", "value": "portrait, slight down angle, looking at viewer, serious expression, simple background, cinematic light"},
	{"label": "033 3/4 left surprised 07", "value": "portrait, three-quarter left view, looking at viewer, surprised expression, simple background"},
	{"label": "034 3/4 right smile 08", "value": "portrait, three-quarter right view, smiling, looking at viewer, warm indoor background, soft light"},
	{"label": "035 closeup 3/4 left 09", "value": "close-up, three-quarter left view, looking away, neutral expression, blur background"},
	{"label": "036 over shoulder 10", "value": "portrait, looking over shoulder, neutral expression, simple background, rim light"},
	{"group": "Corps (buste)"},
	{"label": "037 upper body front 01", "value": "upper body, front view, standing, looking at viewer, neutral expression, simple background, soft light"},
	{"label": "038 upper body smile 02", "value": "upper body, front view, standing, looking at viewer, smiling, indoor background, warm light"},
	{"label": "039 upper body arms crossed 03", "value": "upper body, three-quarter view, standing, arms crossed, serious expression, simple background"},
	{"label": "040 upper body hand on hip 04", "value": "upper body, front view, standing, hand on hip, looking at viewer, outdoor, daylight"},
	{"label": "041 waist up sitting 05", "value": "waist up, front view, sitting, looking at viewer, neutral expression, bedroom background, soft light"},
	{"label": "042 waist up sitting lookaway 06", "value": "waist up, three-quarter view, sitting, looking away, relaxed expression, indoor background"},
	{"label": "043 upper body leaning 07", "value": "upper body, front view, leaning forward, smiling, looking at viewer, simple background"},
	{"label": "044 upper body shy 08", "value": "upper body, front view, standing, looking at viewer, shy expression, blushing, soft background"},
	{"label": "045 upper body determined 09", "value": "upper body, slight up angle, looking at viewer, determined expression, outdoor, natural light"},
	{"label": "046 waist up writing 10", "value": "waist up, front view, standing, writing, looking down, classroom background, ambient light"},
	{"label": "047 upper body lookback 11", "value": "upper body, three-quarter view, standing, looking over shoulder, smile, outdoor, daylight"},
	{"label": "048 waist up cafe 12", "value": "waist up, front view, sitting, arms on table, neutral expression, cafe background, warm light"},
	{"label": "049 upper body angry street 13", "value": "upper body, front view, standing, looking at viewer, angry expression, street background"},
	{"label": "050 waist up lying 14", "value": "waist up, front view, lying down, looking at viewer, relaxed expression, bedroom background"},
	{"group": "Corps entier"},
	{"label": "051 full body standing front 01", "value": "full body, front view, standing, looking at viewer, neutral expression, simple background, soft light"},
	{"label": "052 full body hand on hip 02", "value": "full body, front view, standing, hand on hip, smiling, looking at viewer, simple background"},
	{"label": "053 full body walking street 03", "value": "full body, front view, walking, looking at viewer, neutral expression, street background, daylight"},
	{"label": "054 full body sitting park 04", "value": "full body, front view, sitting, looking at viewer, relaxed expression, park background, natural light"},
	{"label": "055 full body arms crossed 05", "value": "full body, three-quarter view, standing, arms crossed, serious expression, indoor background"},
	{"label": "056 full body lookaway 06", "value": "full body, front view, standing, neutral expression, looking away, simple background, soft light"},
	{"label": "057 full body sitting floor 07", "value": "full body, front view, sitting on floor, looking at viewer, casual expression, bedroom background"},
	{"label": "058 full body happy outdoor 08", "value": "full body, front view, standing, looking at viewer, happy expression, outdoor background, daylight"},
	{"label": "059 full body walking lookback 09", "value": "full body, three-quarter view, walking, looking back over shoulder, smile, street background"},
	{"label": "060 full body shy 10", "value": "full body, front view, standing, shy expression, blushing, simple background, warm light"},
	{"label": "061 full body determined 11", "value": "full body, front view, standing, determined expression, arms at side, simple background"},
	{"label": "062 full body leaning wall 12", "value": "full body, front view, leaning against wall, relaxed expression, indoor background, soft light"},
	{"group": "Tenues"},
	{"label": "063 casual jeans t-shirt 01", "value": "upper body, front view, looking at viewer, casual outfit, jeans, t-shirt, simple background, daylight"},
	{"label": "064 formal dress shirt 02", "value": "upper body, front view, looking at viewer, formal outfit, dress shirt, simple background, studio light"},
	{"label": "065 sleepwear pajamas 03", "value": "upper body, front view, looking at viewer, sleepwear, pajamas, bedroom background, warm light"},
	{"label": "066 sportswear gym 04", "value": "upper body, front view, looking at viewer, sportswear, gym background, natural light"},
	{"label": "067 jacket street 05", "value": "upper body, front view, looking at viewer, jacket, casual outfit, street background, daylight"},
	{"label": "068 dress full body 06", "value": "full body, front view, standing, looking at viewer, dress, simple background, soft light"},
	{"label": "069 school uniform 07", "value": "upper body, front view, looking at viewer, school uniform, classroom background, ambient light"},
	{"label": "070 winter coat scarf 08", "value": "upper body, front view, looking at viewer, winter coat, scarf, outdoor background, cold light"},
	{"label": "071 swimwear beach 09", "value": "upper body, front view, looking at viewer, swimwear, beach background, sunlight"},
	{"label": "072 fantasy outfit 10", "value": "upper body, front view, looking at viewer, fantasy outfit, simple background, cinematic light"},
	{"label": "073 casual full body park 11", "value": "full body, front view, standing, looking at viewer, casual outfit, park background, natural light"},
	{"label": "074 hoodie indoor 12", "value": "upper body, front view, looking at viewer, hoodie, casual, indoor background, warm light"},
	{"label": "075 tank top summer 13", "value": "upper body, front view, looking at viewer, tank top, casual, summer outdoor background"},
	{"label": "076 blouse skirt office 14", "value": "upper body, front view, looking at viewer, blouse, skirt, office background, soft light"},
	{"label": "077 evening dress full body 15", "value": "full body, front view, standing, evening dress, smiling, indoor background, warm light"},
	{"label": "078 crop top outdoor 16", "value": "upper body, front view, looking at viewer, crop top, casual, outdoor background, daylight"},
	{"label": "079 cardigan cafe 17", "value": "upper body, front view, looking at viewer, cardigan, casual, cafe background, warm light"},
	{"label": "080 sportswear running park 18", "value": "full body, front view, standing, sportswear, running, park background, morning light"},
	{"label": "081 leather jacket night 19", "value": "upper body, front view, looking at viewer, leather jacket, street background, night light"},
	{"label": "082 oversized shirt bedroom 20", "value": "upper body, front view, looking at viewer, oversized shirt, relaxed, bedroom background, soft light"},
	{"group": "Contextes"},
	{"label": "083 bedroom warm light 01", "value": "portrait, front view, looking at viewer, neutral expression, bedroom background, warm light"},
	{"label": "084 ctx street night 02", "value": "upper body, front view, looking at viewer, neutral expression, street background, night light"},
	{"label": "085 ctx park golden hour 03", "value": "portrait, front view, looking at viewer, smiling, park background, golden hour light"},
	{"label": "086 ctx cafe warm 04", "value": "upper body, front view, looking at viewer, neutral expression, cafe background, warm light"},
	{"label": "087 ctx classroom ambient 05", "value": "portrait, front view, looking at viewer, neutral expression, classroom background, ambient light"},
	{"label": "088 ctx beach sun 06", "value": "upper body, front view, looking at viewer, neutral expression, beach background, sunlight"},
	{"label": "089 ctx nightclub neon 07", "value": "portrait, front view, looking at viewer, neutral expression, nightclub background, neon light"},
	{"label": "090 ctx bathroom soft 08", "value": "upper body, front view, looking at viewer, neutral expression, bathroom background, soft light"},
	{"label": "091 ctx outdoor day 09", "value": "portrait, front view, looking at viewer, smiling, outdoor background, daylight"},
	{"label": "092 ctx library soft 10", "value": "upper body, front view, looking at viewer, neutral expression, library background, soft light"},
	{"label": "093 ctx cinematic 11", "value": "portrait, front view, looking at viewer, neutral expression, simple background, cinematic light"},
	{"label": "094 ctx dramatic dark 12", "value": "portrait, front view, looking at viewer, neutral expression, dark background, dramatic light"},
	{"label": "095 ctx kitchen warm 13", "value": "upper body, front view, looking at viewer, neutral expression, kitchen background, warm light"},
	{"label": "096 ctx rain 14", "value": "portrait, front view, looking at viewer, neutral expression, outdoor, rainy day light"},
	{"label": "097 ctx rooftop sunset 15", "value": "upper body, front view, looking at viewer, neutral expression, rooftop background, sunset light"},
	{"label": "098 ctx high key 16", "value": "portrait, front view, looking at viewer, neutral expression, simple background, high key light"},
	{"label": "099 ctx low key 17", "value": "portrait, front view, looking at viewer, neutral expression, simple background, low key light"},
	{"label": "100 ctx forest dappled 18", "value": "upper body, front view, looking at viewer, neutral expression, forest background, dappled light"},
]
```

- [ ] **Step 5.2: Verify the file parses**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 10 $GODOT --headless --path . --check-only \
  res://plugins/ai_studio/ai_studio_lora_generator_tab.gd 2>&1
```

Expected: no errors.

- [ ] **Step 5.3: Verify sub-panel files also parse (no cascading errors)**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 10 $GODOT --headless --path . --check-only \
  res://plugins/ai_studio/lora_bases_panel.gd \
  res://plugins/ai_studio/lora_variations_panel.gd 2>&1
```

Expected: no errors.

- [ ] **Step 5.4: Run full test suite to confirm no regressions**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd 2>&1 | tail -20
```

Expected: all tests pass, including the updated service tests from Tasks 1–2.

- [ ] **Step 5.5: Commit**

```bash
git add plugins/ai_studio/ai_studio_lora_generator_tab.gd
git commit -m "feat(lora): rewrite tab as two-phase orchestrator (bases + variations)"
```

---

## Self-Review Checklist

- **Spec coverage:**
  - ✅ 6 fixed base slots (Close-up, Portrait, 3/4, Profil, Buste, Corps entier) — Task 3
  - ✅ Import per slot — Task 3 `_on_import_pressed`
  - ✅ Generate per slot + generate all — Task 3 signals + Task 5 `_on_generate_slot_pressed` / `_on_generate_all_bases_pressed`
  - ✅ Auto mapping with priority order — Task 1 `detect_base()`
  - ✅ Phase 1 / Phase 2 independent sliders — Task 3 & 4
  - ✅ Shared right-panel grid — Task 5 (6 base cards + variation cards)
  - ✅ Base badge on each variation row — Task 4
  - ✅ `show_preview_fn` on thumbnail click — Task 3
  - ✅ Save/load folder unchanged — Task 5
  - ✅ `detect_base()` static, accessible from both service and panel — Task 1

- **Type consistency:**
  - `detect_base(caption: String) -> String` — used consistently in Tasks 1, 4, 5
  - `build_queue(bases: Dictionary, keyword: String, variations: Array)` — consistent Tasks 2, 5
  - `_bases` dict structure `{"key": {"image": Image|null, "path": String}}` — consistent Tasks 3, 5
  - `BASE_SLOTS` const on `LoraBasesPanel` — accessed in Task 5 as `LoraBasesPanel.BASE_SLOTS` ✅

- **No placeholders:** All steps have concrete code, commands, and expected output.
