# WAN VACE — LORAs dynamiques + Export APNG Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter la sélection dynamique de LORAs et l'export APNG avec transparence à l'onglet WAN VACE.

**Architecture:** Deux parties indépendantes : (1) injection de `LoraLoaderModelOnly` dans les workflows ComfyUI (VACE et I2V), (2) service `ApngBuilder` + UI d'export dans le tab. Le paramètre `transparent_output` ajoute un nœud `BiRefNetRMBG` après le décodeur vidéo, distinct du `remove_background` existant qui traite les frames de sortie source.

**Tech Stack:** GDScript 4.6, GUT 9.3.0, ComfyUI workflow JSON, PNG/APNG binary format, HashingContext CRC32.

---

## File Map

| Fichier | Action |
|---------|--------|
| `src/services/comfyui_client.gd` | Modifier : `generate_sequence` + builders |
| `src/services/apng_builder.gd` | Créer |
| `plugins/ai_studio/ai_studio_wan_vace_tab.gd` | Modifier : UI LORAs + transparence + export panel |
| `specs/services/test_comfyui_client_wan_vace.gd` | Modifier : 7 nouveaux tests |
| `specs/services/test_apng_builder.gd` | Créer |

---

### Task 1: generate_sequence — nouveaux params + instance var

**Files:**
- Modify: `src/services/comfyui_client.gd:58-76` (instance vars), `1645-1676` (generate_sequence)
- Modify: `specs/services/test_comfyui_client_wan_vace.gd` (ajouter 1 test)

- [ ] **Step 1: Écrire le test (failing)**

Ajouter à la fin de `specs/services/test_comfyui_client_wan_vace.gd` :

```gdscript
func test_generate_sequence_stores_loras_and_transparent_output():
	var client = Node.new()
	client.set_script(ComfyUIClientScript)
	var config = load("res://src/services/comfyui_config.gd").new()
	var loras = [{"name": "my_lora.safetensors", "strength": 0.8}]
	# /nonexistent.png fails file open but AFTER params are stored
	client.generate_sequence(config, "/nonexistent.png", "", false, 7.0, 20,
		ComfyUIClientScript.WorkflowType.WAN_VACE, 0.85, "", 6, 3.0, "", 0.7, 8,
		loras, true)
	assert_eq(client._loras, loras)
	assert_true(client._transparent_output)
	client.free()
```

- [ ] **Step 2: Lancer le test — vérifier qu'il échoue**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd 2>&1 | tail -20
```

Attendu : FAIL — `_transparent_output` inexistant.

- [ ] **Step 3: Implémenter dans comfyui_client.gd**

Ajouter `_transparent_output` après `_fps` (ligne ~62) :

```gdscript
var _fps: int = 8
var _transparent_output: bool = false
var _is_sequence_mode: bool = false
```

Ajouter `loras` et `transparent_output` à la signature de `generate_sequence` (après `fps: int = 8`) :

```gdscript
func generate_sequence(
	config: RefCounted,
	source_image_path: String,
	prompt_text: String,
	remove_background: bool = true,
	cfg: float = 7.0,
	steps: int = 20,
	workflow_type: int = WorkflowType.WAN_VACE,
	denoise: float = 0.85,
	negative_prompt: String = "",
	frames_to_extract: int = 6,
	duration_sec: float = 3.0,
	second_image_path: String = "",
	controlnet_strength: float = 0.7,
	fps: int = 8,
	loras: Array = [],
	transparent_output: bool = false
) -> void:
```

Après `_fps = fps` (ligne ~1676), ajouter :

```gdscript
	_fps = fps
	_loras = loras
	_transparent_output = transparent_output
```

- [ ] **Step 4: Lancer le test — vérifier qu'il passe**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd 2>&1 | tail -20
```

Attendu : tous les tests passent.

- [ ] **Step 5: Commit**

```bash
cd plugins/ai_studio && git add ai_studio_wan_vace_tab.gd && cd ..
git add src/services/comfyui_client.gd specs/services/test_comfyui_client_wan_vace.gd
git commit -m "feat: generate_sequence accepts loras and transparent_output params"
```

---

### Task 2: _build_wan_vace_workflow — LORAs + transparent output

**Files:**
- Modify: `src/services/comfyui_client.gd:2300-2424` (_build_wan_vace_workflow), `2427-2486` (_build_wan_vace_pose_workflow)
- Modify: `specs/services/test_comfyui_client_wan_vace.gd`

- [ ] **Step 1: Écrire les 3 tests (failing)**

Ajouter à la fin de `specs/services/test_comfyui_client_wan_vace.gd` :

```gdscript
func test_build_wan_vace_workflow_with_loras():
	var client = ComfyUIClientScript.new()
	var loras = [
		{"name": "style.safetensors", "strength": 0.8},
		{"name": "char.safetensors", "strength": 1.2}
	]
	var wf = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0, 8, 832, 480, loras)
	assert_true(wf.has("wv:lora_0"), "wv:lora_0 doit exister")
	assert_eq(wf["wv:lora_0"]["class_type"], "LoraLoaderModelOnly")
	assert_eq(wf["wv:lora_0"]["inputs"]["lora_name"], "style.safetensors")
	assert_eq(wf["wv:lora_0"]["inputs"]["strength_model"], 0.8)
	assert_eq(wf["wv:lora_0"]["inputs"]["model"], ["wv:model", 0])
	assert_true(wf.has("wv:lora_1"), "wv:lora_1 doit exister")
	assert_eq(wf["wv:lora_1"]["inputs"]["model"], ["wv:lora_0", 0])
	assert_eq(wf["wv:sampler"]["inputs"]["model"], ["wv:lora_1", 0])

func test_build_wan_vace_workflow_no_loras_no_lora_nodes():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0)
	for key in wf.keys():
		assert_false(key.begins_with("wv:lora_"), "Nœud lora inattendu : " + key)
	assert_eq(wf["wv:sampler"]["inputs"]["model"], ["wv:model", 0])

func test_build_wan_vace_workflow_transparent_output():
	var client = ComfyUIClientScript.new()
	# remove_background=true ET transparent_output=true : les deux nœuds doivent coexister
	var wf = client._build_wan_vace_workflow("src.png", "p", 1, true, 7.0, 20, 0.85, "", 6, 3.0, 8, 832, 480, [], true)
	assert_true(wf.has("wv:birefnet_out"), "wv:birefnet_out doit exister")
	assert_eq(wf["wv:birefnet_out"]["class_type"], "BiRefNetRMBG")
	assert_eq(wf["wv:birefnet_out"]["inputs"]["image"], ["wv:decode", 0])
	assert_eq(wf["9"]["inputs"]["images"], ["wv:birefnet_out", 0])
	assert_true(wf.has("wv:birefnet"), "wv:birefnet (source) doit rester intact")
```

- [ ] **Step 2: Lancer les tests — vérifier qu'ils échouent**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd 2>&1 | tail -20
```

Attendu : 3 FAILs sur les nouveaux tests.

- [ ] **Step 3: Modifier _build_wan_vace_workflow**

Changer la signature (ajouter après `height: int = 480`) :

```gdscript
func _build_wan_vace_workflow(
	source_filename: String,
	prompt_text: String,
	seed: int,
	remove_background: bool,
	cfg: float,
	steps: int,
	denoise: float,
	negative_prompt: String,
	_frames_to_extract: int,
	duration_sec: float,
	fps: int = 8,
	width: int = 832,
	height: int = 480,
	loras: Array = [],
	transparent_output: bool = false
) -> Dictionary:
```

Remplacer `return wf` (fin de la fonction, ligne ~2424) par :

```gdscript
	# LORAs
	for i in loras.size():
		var lora = loras[i]
		wf["wv:lora_%d" % i] = {
			"class_type": "LoraLoaderModelOnly",
			"inputs": {
				"model": ["wv:model", 0] if i == 0 else ["wv:lora_%d" % (i - 1), 0],
				"lora_name": lora["name"],
				"strength_model": lora["strength"]
			}
		}
	if not loras.is_empty():
		wf["wv:sampler"]["inputs"]["model"] = ["wv:lora_%d" % (loras.size() - 1), 0]

	# Transparent output (distinct de wv:birefnet existant)
	if transparent_output:
		wf["wv:birefnet_out"] = {
			"class_type": "BiRefNetRMBG",
			"inputs": {
				"model": "BiRefNet-general",
				"mask_blur": 0,
				"mask_offset": 0,
				"invert_output": false,
				"refine_foreground": true,
				"background": "Alpha",
				"background_color": "#222222",
				"image": ["wv:decode", 0]
			}
		}
		wf["9"]["inputs"]["images"] = ["wv:birefnet_out", 0]

	return wf
```

- [ ] **Step 4: Modifier _build_wan_vace_pose_workflow**

Ajouter `loras: Array = [], transparent_output: bool = false` à la signature (après `height: int = 480`) :

```gdscript
func _build_wan_vace_pose_workflow(
	source_filename: String,
	pose_filename: String,
	prompt_text: String,
	seed: int,
	remove_background: bool,
	cfg: float,
	steps: int,
	denoise: float,
	negative_prompt: String,
	frames_to_extract: int,
	duration_sec: float,
	controlnet_strength: float,
	fps: int = 8,
	width: int = 832,
	height: int = 480,
	loras: Array = [],
	transparent_output: bool = false
) -> Dictionary:
	var wf = _build_wan_vace_workflow(source_filename, prompt_text, seed,
		remove_background, cfg, steps, denoise, negative_prompt,
		frames_to_extract, duration_sec, fps, width, height, loras, transparent_output)
```

(La ligne `var wf = _build_wan_vace_workflow(...)` est la seule ligne à modifier dans cette fonction.)

- [ ] **Step 5: Lancer les tests — vérifier qu'ils passent**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd 2>&1 | tail -20
```

Attendu : tous les tests passent.

- [ ] **Step 6: Commit**

```bash
git add src/services/comfyui_client.gd specs/services/test_comfyui_client_wan_vace.gd
git commit -m "feat: inject LoRA nodes and transparent output in WAN VACE workflow"
```

---

### Task 3: _build_wan_i2v_workflow — LORAs + transparent output

**Files:**
- Modify: `src/services/comfyui_client.gd:2493-2627` (_build_wan_i2v_workflow)
- Modify: `specs/services/test_comfyui_client_wan_vace.gd`

- [ ] **Step 1: Écrire les 3 tests (failing)**

Ajouter à la fin de `specs/services/test_comfyui_client_wan_vace.gd` :

```gdscript
func test_build_wan_i2v_workflow_with_loras():
	var client = ComfyUIClientScript.new()
	var loras = [{"name": "style.safetensors", "strength": 0.9}]
	var wf = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0, 8, 832, 480, loras)
	assert_true(wf.has("i2v:lora_high_0"), "i2v:lora_high_0 doit exister")
	assert_eq(wf["i2v:lora_high_0"]["class_type"], "LoraLoaderModelOnly")
	assert_eq(wf["i2v:lora_high_0"]["inputs"]["lora_name"], "style.safetensors")
	assert_eq(wf["i2v:lora_high_0"]["inputs"]["model"], ["i2v:unet_high", 0])
	assert_true(wf.has("i2v:lora_low_0"), "i2v:lora_low_0 doit exister")
	assert_eq(wf["i2v:lora_low_0"]["inputs"]["model"], ["i2v:unet_low", 0])
	assert_eq(wf["i2v:sampler1"]["inputs"]["model"], ["i2v:lora_high_0", 0])
	assert_eq(wf["i2v:sampler2"]["inputs"]["model"], ["i2v:lora_low_0", 0])

func test_build_wan_i2v_workflow_no_loras_no_lora_nodes():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0)
	for key in wf.keys():
		assert_false(key.contains("lora_"), "Nœud lora inattendu : " + key)
	assert_eq(wf["i2v:sampler1"]["inputs"]["model"], ["i2v:unet_high", 0])
	assert_eq(wf["i2v:sampler2"]["inputs"]["model"], ["i2v:unet_low", 0])

func test_build_wan_i2v_workflow_transparent_output():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0, 8, 832, 480, [], true)
	assert_true(wf.has("i2v:birefnet_out"), "i2v:birefnet_out doit exister")
	assert_eq(wf["i2v:birefnet_out"]["class_type"], "BiRefNetRMBG")
	assert_eq(wf["i2v:birefnet_out"]["inputs"]["image"], ["i2v:decode", 0])
	assert_eq(wf["9"]["inputs"]["images"], ["i2v:birefnet_out", 0])
```

- [ ] **Step 2: Lancer les tests — vérifier qu'ils échouent**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd 2>&1 | tail -20
```

- [ ] **Step 3: Modifier _build_wan_i2v_workflow**

Ajouter `loras: Array = [], transparent_output: bool = false` à la signature (après `height: int = 480`) :

```gdscript
func _build_wan_i2v_workflow(
	source_filename: String,
	prompt_text: String,
	seed: int,
	cfg: float,
	steps: int,
	negative_prompt: String,
	duration_sec: float,
	fps: int = 8,
	width: int = 832,
	height: int = 480,
	loras: Array = [],
	transparent_output: bool = false
) -> Dictionary:
```

Remplacer `return {` par `var wf: Dictionary = {` et ajouter après la fermeture du dict (ligne ~2627 `}`) :

```gdscript
	# LORAs — deux chaînes : high et low
	for i in loras.size():
		var lora = loras[i]
		wf["i2v:lora_high_%d" % i] = {
			"class_type": "LoraLoaderModelOnly",
			"inputs": {
				"model": ["i2v:unet_high", 0] if i == 0 else ["i2v:lora_high_%d" % (i - 1), 0],
				"lora_name": lora["name"],
				"strength_model": lora["strength"]
			}
		}
		wf["i2v:lora_low_%d" % i] = {
			"class_type": "LoraLoaderModelOnly",
			"inputs": {
				"model": ["i2v:unet_low", 0] if i == 0 else ["i2v:lora_low_%d" % (i - 1), 0],
				"lora_name": lora["name"],
				"strength_model": lora["strength"]
			}
		}
	if not loras.is_empty():
		wf["i2v:sampler1"]["inputs"]["model"] = ["i2v:lora_high_%d" % (loras.size() - 1), 0]
		wf["i2v:sampler2"]["inputs"]["model"] = ["i2v:lora_low_%d" % (loras.size() - 1), 0]

	# Transparent output
	if transparent_output:
		wf["i2v:birefnet_out"] = {
			"class_type": "BiRefNetRMBG",
			"inputs": {
				"model": "BiRefNet-general",
				"mask_blur": 0,
				"mask_offset": 0,
				"invert_output": false,
				"refine_foreground": true,
				"background": "Alpha",
				"background_color": "#222222",
				"image": ["i2v:decode", 0]
			}
		}
		wf["9"]["inputs"]["images"] = ["i2v:birefnet_out", 0]

	return wf
```

- [ ] **Step 4: Lancer les tests — vérifier qu'ils passent**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd 2>&1 | tail -20
```

- [ ] **Step 5: Commit**

```bash
git add src/services/comfyui_client.gd specs/services/test_comfyui_client_wan_vace.gd
git commit -m "feat: inject LoRA nodes and transparent output in WAN I2V workflow"
```

---

### Task 4: Câbler _do_prompt_sequence

**Files:**
- Modify: `src/services/comfyui_client.gd:1967-1984` (_do_prompt_sequence)

- [ ] **Step 1: Mettre à jour _do_prompt_sequence**

Remplacer les 3 appels de builders dans `_do_prompt_sequence` (ligne ~1970) :

```gdscript
func _do_prompt_sequence(filename: String, prompt_text: String) -> void:
	var seed = randi()
	var workflow: Dictionary
	if _workflow_type == WorkflowType.WAN_VACE_POSE:
		workflow = _build_wan_vace_pose_workflow(
			filename, _second_image_filename, prompt_text, seed,
			_remove_background, _cfg, _steps, _denoise, _negative_prompt,
			_frames_to_extract, _duration_sec, _controlnet_strength, _fps,
			_source_width, _source_height, _loras, _transparent_output)
	elif _workflow_type == WorkflowType.WAN_I2V:
		workflow = _build_wan_i2v_workflow(
			filename, prompt_text, seed, _cfg, _steps, _negative_prompt,
			_duration_sec, _fps, _source_width, _source_height, _loras, _transparent_output)
	else:
		workflow = _build_wan_vace_workflow(
			filename, prompt_text, seed,
			_remove_background, _cfg, _steps, _denoise, _negative_prompt,
			_frames_to_extract, _duration_sec, _fps, _source_width, _source_height,
			_loras, _transparent_output)
```

- [ ] **Step 2: Lancer tous les tests WAN VACE**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd 2>&1 | tail -20
```

Attendu : tous passent.

- [ ] **Step 3: Commit**

```bash
git add src/services/comfyui_client.gd
git commit -m "feat: wire loras and transparent_output through _do_prompt_sequence"
```

---

### Task 5: Service ApngBuilder

**Files:**
- Create: `src/services/apng_builder.gd`
- Create: `specs/services/test_apng_builder.gd`

- [ ] **Step 1: Écrire le fichier de test (failing)**

Créer `specs/services/test_apng_builder.gd` :

```gdscript
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends GutTest

const ApngBuilderScript = preload("res://src/services/apng_builder.gd")

func _make_frame(w: int = 8, h: int = 8, color: Color = Color.RED) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img

func test_build_returns_non_empty_bytes():
	var frames = [_make_frame(), _make_frame(8, 8, Color.BLUE)]
	var result = ApngBuilderScript.build(frames, 8)
	assert_gt(result.size(), 0)

func test_build_starts_with_png_signature():
	var result = ApngBuilderScript.build([_make_frame()], 8)
	assert_gte(result.size(), 8)
	assert_eq(result[0], 0x89)
	assert_eq(result[1], 0x50)  # P
	assert_eq(result[2], 0x4E)  # N
	assert_eq(result[3], 0x47)  # G
	assert_eq(result[4], 0x0D)
	assert_eq(result[5], 0x0A)
	assert_eq(result[6], 0x1A)
	assert_eq(result[7], 0x0A)

func test_build_contains_actl_chunk():
	var result = ApngBuilderScript.build([_make_frame(), _make_frame()], 8)
	var found = false
	for i in range(result.size() - 3):
		if result[i] == 0x61 and result[i+1] == 0x63 and result[i+2] == 0x54 and result[i+3] == 0x4C:
			found = true
			break
	assert_true(found, "acTL chunk non trouvé dans l'APNG")

func test_build_single_frame_produces_valid_png():
	var frame = _make_frame(16, 16, Color.GREEN)
	var result = ApngBuilderScript.build([frame], 24, 1)
	var img = Image.new()
	var err = img.load_png_from_buffer(result)
	assert_eq(err, OK, "L'APNG 1 frame doit être lisible comme PNG standard")
	assert_eq(img.get_width(), 16)
	assert_eq(img.get_height(), 16)

func test_build_empty_frames_returns_empty():
	var result = ApngBuilderScript.build([], 8)
	assert_eq(result.size(), 0)

func test_build_zero_fps_returns_empty():
	var result = ApngBuilderScript.build([_make_frame()], 0)
	assert_eq(result.size(), 0)
```

- [ ] **Step 2: Lancer le test — vérifier qu'il échoue**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_apng_builder.gd 2>&1 | tail -20
```

Attendu : erreur de preload (fichier inexistant).

- [ ] **Step 3: Créer src/services/apng_builder.gd**

```gdscript
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

class_name ApngBuilder

## Assemble frames RGBA en APNG. Retourne PackedByteArray (fichier APNG).
## frames: Array[Image], fps: int (>0), loops: int (0 = infini)
static func build(frames: Array, fps: int, loops: int = 0) -> PackedByteArray:
	if frames.is_empty() or fps <= 0:
		return PackedByteArray()

	var png_list: Array = []
	for frame in frames:
		var img: Image = frame as Image
		if img == null:
			return PackedByteArray()
		png_list.append(img.save_png_to_buffer())

	var parsed: Array = []
	for png_bytes in png_list:
		parsed.append(_parse_png_chunks(png_bytes))

	var num_frames: int = frames.size()
	var ihdr0: PackedByteArray = parsed[0]["ihdr_data"]
	var width: int = (ihdr0[0] << 24) | (ihdr0[1] << 16) | (ihdr0[2] << 8) | ihdr0[3]
	var height: int = (ihdr0[4] << 24) | (ihdr0[5] << 16) | (ihdr0[6] << 8) | ihdr0[7]

	var out := PackedByteArray()
	out.append_array(PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
	out.append_array(_make_chunk("IHDR", ihdr0))

	var actl := PackedByteArray()
	actl.append_array(_u32_be(num_frames))
	actl.append_array(_u32_be(loops))
	out.append_array(_make_chunk("acTL", actl))

	var seq_num: int = 0
	for i in range(num_frames):
		var fctl := PackedByteArray()
		fctl.append_array(_u32_be(seq_num)); seq_num += 1
		fctl.append_array(_u32_be(width))
		fctl.append_array(_u32_be(height))
		fctl.append_array(_u32_be(0))    # x_offset
		fctl.append_array(_u32_be(0))    # y_offset
		fctl.append_array(_u16_be(1))    # delay_num
		fctl.append_array(_u16_be(fps))  # delay_den
		fctl.append(0)  # dispose_op = APNG_DISPOSE_OP_NONE
		fctl.append(0)  # blend_op = APNG_BLEND_OP_SOURCE
		out.append_array(_make_chunk("fcTL", fctl))

		var idat_chunks: Array = parsed[i]["idat_chunks"]
		for idat in idat_chunks:
			if i == 0:
				out.append_array(_make_chunk("IDAT", idat))
			else:
				var fdat := PackedByteArray()
				fdat.append_array(_u32_be(seq_num)); seq_num += 1
				fdat.append_array(idat)
				out.append_array(_make_chunk("fdAT", fdat))

	out.append_array(_make_chunk("IEND", PackedByteArray()))
	return out


static func _parse_png_chunks(png_bytes: PackedByteArray) -> Dictionary:
	var result := {"ihdr_data": PackedByteArray(), "idat_chunks": []}
	var pos: int = 8  # skip 8-byte signature
	while pos + 8 <= png_bytes.size():
		var length: int = (png_bytes[pos] << 24) | (png_bytes[pos + 1] << 16) | \
			(png_bytes[pos + 2] << 8) | png_bytes[pos + 3]
		var type_str: String = png_bytes.slice(pos + 4, pos + 8).get_string_from_ascii()
		var data: PackedByteArray = png_bytes.slice(pos + 8, pos + 8 + length) \
			if length > 0 else PackedByteArray()
		if type_str == "IHDR":
			result["ihdr_data"] = data
		elif type_str == "IDAT":
			result["idat_chunks"].append(data)
		pos += 12 + length  # 4B len + 4B type + Nb data + 4B CRC
	return result


static func _make_chunk(type_str: String, data: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(_u32_be(data.size()))
	var type_bytes: PackedByteArray = type_str.to_ascii_buffer()
	out.append_array(type_bytes)
	out.append_array(data)
	out.append_array(_crc32_of(type_bytes, data))
	return out


static func _crc32_of(type_bytes: PackedByteArray, data: PackedByteArray) -> PackedByteArray:
	var combined := PackedByteArray()
	combined.append_array(type_bytes)
	combined.append_array(data)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_CRC32)
	ctx.update(combined)
	# HashingContext encode CRC32 en little-endian → decode_u32(0), puis re-encode BE pour PNG
	var crc_val: int = ctx.finish().decode_u32(0)
	return _u32_be(crc_val)


static func _u32_be(value: int) -> PackedByteArray:
	var b := PackedByteArray([0, 0, 0, 0])
	b[0] = (value >> 24) & 0xFF
	b[1] = (value >> 16) & 0xFF
	b[2] = (value >> 8) & 0xFF
	b[3] = value & 0xFF
	return b


static func _u16_be(value: int) -> PackedByteArray:
	var b := PackedByteArray([0, 0])
	b[0] = (value >> 8) & 0xFF
	b[1] = value & 0xFF
	return b
```

- [ ] **Step 4: Lancer les tests — vérifier qu'ils passent**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_apng_builder.gd 2>&1 | tail -20
```

Attendu : 6 tests passent. Si `test_build_single_frame_produces_valid_png` échoue à cause du CRC, vérifier que `_crc32_of` utilise bien `.decode_u32(0)` (LE) suivi de `_u32_be()`.

- [ ] **Step 5: Commit**

```bash
git add src/services/apng_builder.gd specs/services/test_apng_builder.gd
git commit -m "feat: add ApngBuilder service for RGBA frame animation export"
```

---

### Task 6: WAN VACE tab — UI LORAs

**Files:**
- Modify: `plugins/ai_studio/ai_studio_wan_vace_tab.gd`

- [ ] **Step 1: Ajouter les vars d'instance**

Après `var _fps_value_label: Label` (ligne ~56), ajouter :

```gdscript
var _fps_value_label: Label
# --- UI : LORAs ---
var _loras_vbox: VBoxContainer
var _lora_option: OptionButton
```

Après `var _selected_image_index: int = -1` (dans la section State), ajouter :

```gdscript
var _selected_loras: Array = []  # Array of {"name": String, "strength": float}
```

- [ ] **Step 2: Ajouter la section LORA dans build_tab**

Après le bloc FPS (qui se termine avec `fps_hbox.add_child(_fps_value_label)`, ligne ~354), et AVANT le bloc `# --- Frames à extraire ---`, insérer :

```gdscript
	# --- LORAs ---
	var loras_label = Label.new()
	loras_label.text = "LoRA :"
	vbox.add_child(loras_label)

	var loras_clip = Control.new()
	loras_clip.custom_minimum_size.y = 0
	loras_clip.clip_contents = true
	loras_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(loras_clip)

	_loras_vbox = VBoxContainer.new()
	_loras_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loras_vbox.add_theme_constant_override("separation", 4)
	_loras_vbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	loras_clip.add_child(_loras_vbox)

	var lora_hbox = HBoxContainer.new()
	lora_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(lora_hbox)

	_lora_option = OptionButton.new()
	_lora_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lora_option.add_item("Ajouter un LoRA…")
	_lora_option.item_selected.connect(func(index: int):
		if index > 0:
			var lora_name = _lora_option.get_item_text(index)
			_add_lora_row(lora_name, 1.0)
			_lora_option.select(0)
	)
	lora_hbox.add_child(_lora_option)

	var refresh_lora_btn = Button.new()
	refresh_lora_btn.text = "⟳"
	refresh_lora_btn.pressed.connect(_refresh_loras)
	lora_hbox.add_child(refresh_lora_btn)

	# Pré-remplir depuis le cache local
	var cached_loras = _load_loras_cache_wan()
	if not cached_loras.is_empty():
		_lora_option.clear()
		_lora_option.add_item("Ajouter un LoRA…")
		for l in cached_loras:
			_lora_option.add_item(l)
```

- [ ] **Step 3: Ajouter _set_inputs_enabled pour _lora_option**

Dans `_set_inputs_enabled` (ligne ~729), après `_fps_slider.editable = enabled`, ajouter :

```gdscript
	_fps_slider.editable = enabled
	if _lora_option != null:
		_lora_option.disabled = not enabled
```

- [ ] **Step 4: Ajouter les fonctions cache + refresh + add_row**

À la fin du fichier (après `_load_preview`), ajouter :

```gdscript
# ============================================================
# Private — LORAs
# ============================================================

const _WAN_CACHE_PATH := "user://comfyui_discovery_cache_wan.cfg"

func _url_hash_wan() -> String:
	return str(_get_config_fn.call().get_url().strip_edges().hash())

func _load_loras_cache_wan() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(_WAN_CACHE_PATH) != OK:
		return []
	var raw: String = cfg.get_value("loras", _url_hash_wan(), "")
	if raw.is_empty():
		return []
	return Array(raw.split(","))

func _save_loras_cache_wan(loras: Array) -> void:
	var cfg := ConfigFile.new()
	cfg.load(_WAN_CACHE_PATH)
	cfg.set_value("loras", _url_hash_wan(), ",".join(PackedStringArray(loras)))
	cfg.save(_WAN_CACHE_PATH)

func _refresh_loras() -> void:
	if _lora_option == null or _lora_option.disabled:
		return
	var config = _get_config_fn.call()
	if config.get_url().strip_edges() == "":
		return
	_lora_option.clear()
	_lora_option.add_item("Chargement…")
	_lora_option.disabled = true
	var tmp = Node.new()
	tmp.set_script(ComfyUIClient)
	_parent_window.add_child(tmp)
	tmp.get_available_loras(config, func(loras: Array):
		tmp.queue_free()
		_lora_option.clear()
		_lora_option.disabled = false
		_lora_option.add_item("Ajouter un LoRA…")
		for l in loras:
			_lora_option.add_item(l)
		if not loras.is_empty():
			_save_loras_cache_wan(loras)
	)

func _add_lora_row(lora_name: String, strength: float) -> void:
	var lora_entry = {"name": lora_name, "strength": strength}
	_selected_loras.append(lora_entry)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_label = Label.new()
	name_label.text = lora_name if lora_name.length() <= 25 else lora_name.left(22) + "..."
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 2.0
	slider.step = 0.1
	slider.value = strength
	slider.custom_minimum_size.x = 80
	row.add_child(slider)

	var val_label = Label.new()
	val_label.text = str(snapped(strength, 0.1))
	val_label.custom_minimum_size.x = 28
	row.add_child(val_label)

	slider.value_changed.connect(func(val: float):
		val_label.text = str(snapped(val, 0.1))
		lora_entry["strength"] = val
	)

	var remove_btn = Button.new()
	remove_btn.text = "×"
	remove_btn.custom_minimum_size = Vector2(24, 0)
	remove_btn.pressed.connect(func():
		_selected_loras.erase(lora_entry)
		row.queue_free()
	)
	row.add_child(remove_btn)
	_loras_vbox.add_child(row)
```

- [ ] **Step 5: Mettre à jour _on_generate_pressed pour passer les LORAs**

Dans `_on_generate_pressed`, remplacer l'appel `_client.generate_sequence(...)` (ligne ~589) par :

```gdscript
	_client.generate_sequence(
		config, _source_image_path, _prompt_input.text,
		_remove_bg_check.button_pressed,
		_cfg_slider.value, int(_steps_slider.value),
		workflow_type,
		_denoise_slider.value, neg,
		int(_frames_slider.value), float(_duration_slider.value),
		_pose_image_path if _pose_mode else "",
		_strength_slider.value,
		int(_fps_slider.value),
		_selected_loras.duplicate()
	)
```

- [ ] **Step 6: Lancer les tests du tab — vérifier pas de régression**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd 2>&1 | tail -20
```

Attendu : tous les tests passent (y compris `test_wan_vace_tab_builds_without_crash` et `test_wan_vace_tab_generate_button_disabled_without_url`).

- [ ] **Step 7: Commit (submodule)**

```bash
cd plugins/ai_studio
git add ai_studio_wan_vace_tab.gd
git commit -m "feat: add dynamic LORA selector to WAN VACE tab"
cd ..
git add plugins/ai_studio
git commit -m "chore: update ai_studio submodule (LORA UI in WAN VACE tab)"
```

---

### Task 7: WAN VACE tab — transparent output checkbox + export panel

**Files:**
- Modify: `plugins/ai_studio/ai_studio_wan_vace_tab.gd`

- [ ] **Step 1: Ajouter les vars d'instance**

Après `var _remove_bg_check: CheckBox` (ligne ~57), ajouter :

```gdscript
var _remove_bg_check: CheckBox
var _transparent_output_check: CheckBox
```

Après les vars génération, ajouter :

```gdscript
# --- UI : export panel ---
var _export_panel: VBoxContainer
var _range_start: SpinBox
var _range_end: SpinBox
```

- [ ] **Step 2: Ajouter la checkbox dans build_tab**

Après `vbox.add_child(_remove_bg_check)` (ligne ~376), ajouter :

```gdscript
	_transparent_output_check = CheckBox.new()
	_transparent_output_check.text = "Fond transparent (sortie)"
	_transparent_output_check.button_pressed = false
	vbox.add_child(_transparent_output_check)
```

- [ ] **Step 3: Ajouter l'export panel dans build_tab**

À la toute fin de `build_tab`, après `_selected_cell_vbox.add_child(_save_selected_btn)` (ligne ~461), ajouter :

```gdscript
	# --- Export panel ---
	_export_panel = VBoxContainer.new()
	_export_panel.visible = false
	_export_panel.add_theme_constant_override("separation", 6)
	vbox.add_child(_export_panel)

	_export_panel.add_child(HSeparator.new())

	var export_title = Label.new()
	export_title.text = "── Export ──"
	_export_panel.add_child(export_title)

	var range_hbox = HBoxContainer.new()
	range_hbox.add_theme_constant_override("separation", 8)
	_export_panel.add_child(range_hbox)

	var range_lbl = Label.new()
	range_lbl.text = "Frames :"
	range_hbox.add_child(range_lbl)

	_range_start = SpinBox.new()
	_range_start.min_value = 1
	_range_start.max_value = 1
	_range_start.value = 1
	range_hbox.add_child(_range_start)

	var arrow_lbl = Label.new()
	arrow_lbl.text = "→"
	range_hbox.add_child(arrow_lbl)

	_range_end = SpinBox.new()
	_range_end.min_value = 1
	_range_end.max_value = 1
	_range_end.value = 1
	range_hbox.add_child(_range_end)

	var export_btns = HBoxContainer.new()
	export_btns.add_theme_constant_override("separation", 8)
	_export_panel.add_child(export_btns)

	var export_frames_btn = Button.new()
	export_frames_btn.text = "Exporter frames"
	export_frames_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_frames_btn.pressed.connect(_on_export_frames)
	export_btns.add_child(export_frames_btn)

	var export_apng_btn = Button.new()
	export_apng_btn.text = "Exporter APNG"
	export_apng_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_apng_btn.pressed.connect(_on_export_apng)
	export_btns.add_child(export_apng_btn)
```

- [ ] **Step 4: Mettre à jour _on_sequence_completed**

Remplacer `_on_sequence_completed` par :

```gdscript
func _on_sequence_completed(images: Array) -> void:
	_generated_images = images
	_clear_result_grid()
	for i in images.size():
		_add_result_cell(images[i], i)
	_show_success("Séquence générée (%d frames)" % images.size())
	_generate_btn.disabled = false
	_cancel_btn.disabled = true
	_set_inputs_enabled(true)
	_client = null
	if not images.is_empty():
		_range_start.min_value = 1
		_range_start.max_value = images.size()
		_range_start.value = 1
		_range_end.min_value = 1
		_range_end.max_value = images.size()
		_range_end.value = images.size()
		_export_panel.visible = true
	else:
		_export_panel.visible = false
```

- [ ] **Step 5: Mettre à jour _on_generate_pressed pour passer transparent_output**

Dans `_on_generate_pressed`, mettre à jour l'appel `generate_sequence` (ajout du dernier arg) :

```gdscript
	_client.generate_sequence(
		config, _source_image_path, _prompt_input.text,
		_remove_bg_check.button_pressed,
		_cfg_slider.value, int(_steps_slider.value),
		workflow_type,
		_denoise_slider.value, neg,
		int(_frames_slider.value), float(_duration_slider.value),
		_pose_image_path if _pose_mode else "",
		_strength_slider.value,
		int(_fps_slider.value),
		_selected_loras.duplicate(),
		_transparent_output_check.button_pressed
	)
```

- [ ] **Step 6: Ajouter les fonctions d'export**

À la fin du fichier (après les fonctions LORAs), ajouter :

```gdscript
# ============================================================
# Private — Export
# ============================================================

const ApngBuilderClass = preload("res://src/services/apng_builder.gd")

func _on_export_frames() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.title = "Choisir le dossier d'export"
	dialog.dir_selected.connect(func(dir_path: String):
		var start: int = int(_range_start.value) - 1
		var end: int = int(_range_end.value) - 1
		var i = start
		while i <= end and i < _generated_images.size():
			(_generated_images[i] as Image).save_png(dir_path + "/frame_%04d.png" % (i + 1))
			i += 1
		_show_success("Frames exportées dans : " + dir_path.get_file())
		dialog.queue_free()
	)
	_parent_window.add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))

func _on_export_apng() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.title = "Exporter en APNG"
	dialog.filters = PackedStringArray(["*.apng ; APNG Animation"])
	dialog.file_selected.connect(func(file_path: String):
		var start: int = int(_range_start.value) - 1
		var end: int = int(_range_end.value) - 1
		var frames: Array = []
		var i = start
		while i <= end and i < _generated_images.size():
			frames.append(_generated_images[i])
			i += 1
		var apng_bytes = ApngBuilderClass.build(frames, int(_fps_slider.value))
		var f = FileAccess.open(file_path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(apng_bytes)
			f.close()
			_show_success("APNG exporté : " + file_path.get_file())
		else:
			_show_error("Impossible d'écrire le fichier : " + file_path)
		dialog.queue_free()
	)
	_parent_window.add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))
```

- [ ] **Step 7: Lancer les tests — vérifier pas de régression**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd 2>&1 | tail -20
```

- [ ] **Step 8: Lancer la suite complète + vérification globale**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd 2>&1 | tail -30
```

Attendu : tous les tests existants passent. Si `test_build_single_frame_produces_valid_png` échoue → vérifier l'implémentation CRC32 dans `ApngBuilder._crc32_of`.

- [ ] **Step 9: Commit final (submodule + parent)**

```bash
cd plugins/ai_studio
git add ai_studio_wan_vace_tab.gd
git commit -m "feat: add transparent output checkbox and APNG export panel to WAN VACE tab"
cd ..
git add plugins/ai_studio src/services/apng_builder.gd specs/services/test_apng_builder.gd
git commit -m "chore: update ai_studio submodule + ApngBuilder (transparent output + APNG export)"
```

---

## Self-Review

**Spec coverage :**
- [x] LORAs dynamiques (OptionButton + refresh + cache) → Task 6
- [x] `LoraLoaderModelOnly` chain VACE → Task 2
- [x] `LoraLoaderModelOnly` deux chaînes I2V → Task 3
- [x] `generate_sequence` params `loras` + `transparent_output` → Task 1
- [x] `_do_prompt_sequence` passe `_loras` + `_transparent_output` → Task 4
- [x] Checkbox "Fond transparent (sortie)" → Task 7
- [x] `wv:birefnet_out` / `i2v:birefnet_out` → Tasks 2 & 3
- [x] `ApngBuilder.build()` service → Task 5
- [x] Export panel (SpinBox range + 2 boutons) → Task 7

**Type consistency :**
- `_selected_loras: Array` → `_selected_loras.duplicate()` → `generate_sequence(loras: Array)` → `_loras: Array` → `_build_wan_*_workflow(loras: Array)` ✓
- `_transparent_output_check.button_pressed: bool` → `generate_sequence(transparent_output: bool)` → `_transparent_output: bool` → `_build_wan_*_workflow(transparent_output: bool)` ✓
- `ApngBuilderClass.build(frames: Array, fps: int, loops: int)` → `int(_fps_slider.value)` ✓

**No placeholders** : tous les steps ont du code complet. ✓
