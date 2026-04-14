# Wan VACE Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter un onglet "Wan VACE" dans l'AI Studio permettant de générer une séquence de N frames à partir d'une image de référence et d'un prompt textuel, avec option DWPose ControlNet.

**Architecture:** Trois nouveaux `WorkflowType` dans `comfyui_client.gd` (WAN_VACE, WAN_VACE_POSE, WAN_VACE_DWPOSE_PREVIEW). Nouvelle méthode `generate_sequence()` sur le client (signal `sequence_completed(images: Array)`) qui réutilise la chaîne upload existante via un helper `_dispatch_prompt()`. Le tab GDScript suit le pattern identique aux onglets existants (ex: `ai_studio_zimage_decliner_tab.gd`).

**Tech Stack:** GDScript / Godot 4.6.1, GUT pour les tests, ComfyUI API (local uniquement pour `generate_sequence`), custom nodes ComfyUI-WanVideo, comfyui_controlnet_aux.

**Spec de référence:** `docs/superpowers/specs/2026-04-14-wan-vace-tab-design.md`

---

## File Map

| Fichier | Action | Responsabilité |
|---------|--------|---------------|
| `src/services/comfyui_client.gd` | Modifier | +3 WorkflowTypes, +signal, +vars, +3 builders publics, +`generate_sequence()`, +`parse_history_response_all()`, +`_do_download_sequence()`, +`_dispatch_prompt()` |
| `specs/services/test_comfyui_client_wan_vace.gd` | Créer | Tests GUT pour tous les nouveaux builders et `parse_history_response_all` |
| `plugins/ai_studio/ai_studio_wan_vace_tab.gd` | Créer | UI + logique de l'onglet Wan VACE |
| `plugins/ai_studio/ai_studio_dialog.gd` | Modifier | Enregistrer WanVaceTab dans la dialog |
| `docs/comfyui/wan_vace_no_pose.json` | Créer | Workflow ComfyUI standalone (sans pose) |
| `docs/comfyui/wan_vace_with_pose.json` | Créer | Workflow ComfyUI standalone (avec pose) |

---

## Task 1 — WorkflowType enum + signal + vars dans comfyui_client.gd

**Files:**
- Modify: `src/services/comfyui_client.gd:10-55`
- Create: `specs/services/test_comfyui_client_wan_vace.gd`

- [ ] **Step 1 : Écrire le test failing**

Créer `specs/services/test_comfyui_client_wan_vace.gd` :

```gdscript
extends GutTest

var ComfyUIClientScript

func before_each():
    ComfyUIClientScript = load("res://src/services/comfyui_client.gd")

func test_workflow_type_wan_vace_exists():
    assert_eq(ComfyUIClientScript.WorkflowType.WAN_VACE, 12)

func test_workflow_type_wan_vace_pose_exists():
    assert_eq(ComfyUIClientScript.WorkflowType.WAN_VACE_POSE, 13)

func test_workflow_type_wan_vace_dwpose_preview_exists():
    assert_eq(ComfyUIClientScript.WorkflowType.WAN_VACE_DWPOSE_PREVIEW, 14)

func test_sequence_completed_signal_exists():
    var client = Node.new()
    client.set_script(ComfyUIClientScript)
    assert_true(client.has_signal("sequence_completed"))
    client.free()
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

Attendu : FAIL « WAN_VACE is not a valid member » ou similaire.

- [ ] **Step 3 : Modifier `comfyui_client.gd` — enum + signal + vars**

Ligne 10 de `src/services/comfyui_client.gd`, remplacer :
```gdscript
signal generation_completed(image: Image)
signal generation_failed(error: String)
signal generation_progress(status: String)
```
par :
```gdscript
signal generation_completed(image: Image)
signal generation_failed(error: String)
signal generation_progress(status: String)
signal sequence_completed(images: Array)
```

Ligne 19, remplacer :
```gdscript
enum WorkflowType { CREATION = 0, EXPRESSION = 1, OUTPAINT = 2, UPSCALE = 3, ENHANCE = 4, UPSCALE_ENHANCE = 5, BLINK = 6, INPAINT = 7, LORA_CREATE_FLUX = 8, ILLUSTRIOUS = 9, ASSEMBLER = 10, ZIMAGE_DECLINER = 11 }
```
par :
```gdscript
enum WorkflowType { CREATION = 0, EXPRESSION = 1, OUTPAINT = 2, UPSCALE = 3, ENHANCE = 4, UPSCALE_ENHANCE = 5, BLINK = 6, INPAINT = 7, LORA_CREATE_FLUX = 8, ILLUSTRIOUS = 9, ASSEMBLER = 10, ZIMAGE_DECLINER = 11, WAN_VACE = 12, WAN_VACE_POSE = 13, WAN_VACE_DWPOSE_PREVIEW = 14 }
```

Après la ligne `var _mask_bytes_data: PackedByteArray = PackedByteArray()` (ligne ~54), ajouter :
```gdscript
# --- Wan VACE sequence state ---
var _frames_to_extract: int = 6
var _duration_sec: float = 3.0
var _controlnet_strength: float = 0.7
var _is_sequence_mode: bool = false
```

- [ ] **Step 4 : Lancer le test pour vérifier qu'il passe**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

Attendu : PASS (4 tests).

- [ ] **Step 5 : Commit**

```bash
git add src/services/comfyui_client.gd specs/services/test_comfyui_client_wan_vace.gd
git commit -m "feat: add WAN_VACE WorkflowTypes + sequence_completed signal + vars"
```

---

## Task 2 — `parse_history_response_all()` + `_do_download_sequence()` + `_dispatch_prompt()`

**Files:**
- Modify: `src/services/comfyui_client.gd` (après `parse_history_response`, et `_do_upload`)
- Modify: `specs/services/test_comfyui_client_wan_vace.gd`

- [ ] **Step 1 : Écrire les tests failing**

Ajouter à `specs/services/test_comfyui_client_wan_vace.gd` :

```gdscript
func test_parse_history_response_all_returns_all_filenames():
    var client = ComfyUIClientScript.new()
    var json = '{"id1": {"outputs": {"9": {"images": [{"filename": "frame_00001.png", "type": "output"}, {"filename": "frame_00002.png", "type": "output"}, {"filename": "frame_00003.png", "type": "output"}]}}, "status": {"completed": true}}}'
    var parsed = client.parse_history_response_all(json, "id1")
    assert_eq(parsed["status"], "completed")
    assert_eq(parsed["filenames"].size(), 3)
    assert_eq(parsed["filenames"][0], "frame_00001.png")
    assert_eq(parsed["filenames"][2], "frame_00003.png")

func test_parse_history_response_all_pending():
    var client = ComfyUIClientScript.new()
    var json = '{"id1": {"status": {"completed": false}}}'
    var parsed = client.parse_history_response_all(json, "id1")
    assert_eq(parsed["status"], "pending")

func test_parse_history_response_all_no_output_node():
    var client = ComfyUIClientScript.new()
    var json = '{"id1": {"outputs": {}, "status": {"completed": true}}}'
    var parsed = client.parse_history_response_all(json, "id1")
    assert_eq(parsed["status"], "error")

func test_select_frames_evenly():
    var client = ComfyUIClientScript.new()
    var all = ["f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8"]
    var selected = client.select_frames(all, 4)
    assert_eq(selected.size(), 4)
    assert_eq(selected[0], "f1")
    assert_eq(selected[3], "f8")

func test_select_frames_fewer_than_requested():
    var client = ComfyUIClientScript.new()
    var all = ["f1", "f2"]
    var selected = client.select_frames(all, 6)
    assert_eq(selected.size(), 2)
```

- [ ] **Step 2 : Lancer pour vérifier qu'ils échouent**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

Attendu : FAIL sur les 5 nouveaux tests.

- [ ] **Step 3 : Implémenter dans `comfyui_client.gd`**

Ajouter juste après `parse_history_response` (vers ligne 1388) :

```gdscript
## Retourne TOUTES les images du nœud SaveImage (pour les workflows vidéo multi-frame).
func parse_history_response_all(json_str: String, prompt_id: String) -> Dictionary:
    var json = JSON.new()
    var err = json.parse(json_str)
    if err != OK:
        return {"status": "error", "error": "Réponse JSON invalide"}
    var data = json.data
    if not data is Dictionary or not data.has(prompt_id):
        return {"status": "pending"}
    var entry = data[prompt_id]
    if not entry is Dictionary:
        return {"status": "error", "error": "Entrée invalide dans l'historique"}
    if entry.has("status"):
        var status_info = entry["status"]
        if status_info is Dictionary and not status_info.get("completed", false):
            return {"status": "pending"}
    if not entry.has("outputs"):
        return {"status": "error", "error": "Pas de sorties dans l'historique"}
    var outputs = entry["outputs"]
    var all_filenames: Array = []
    for node_id in outputs:
        var node_output = outputs[node_id]
        if node_output is Dictionary and node_output.has("images"):
            var images = node_output["images"]
            if images is Array:
                for img in images:
                    if img is Dictionary and img.get("type", "output") == "output":
                        all_filenames.append(img.get("filename", ""))
    all_filenames = all_filenames.filter(func(f): return f != "")
    all_filenames.sort()
    if all_filenames.is_empty():
        return {"status": "error", "error": "Aucune image dans les sorties"}
    return {"status": "completed", "filenames": all_filenames}


## Sélectionne `count` frames régulièrement espacées dans `all_filenames`.
func select_frames(all_filenames: Array, count: int) -> Array:
    var total = all_filenames.size()
    if total == 0 or count == 0:
        return []
    if count >= total:
        return all_filenames.duplicate()
    var result: Array = []
    for i in range(count):
        var index = roundi(float(i) * (total - 1) / (count - 1))
        result.append(all_filenames[index])
    return result
```

Ajouter juste après `_do_download` (vers ligne 1963), avant la section "Create tab" :

```gdscript
## Télécharge une séquence de frames et émet sequence_completed.
func _do_download_sequence(filenames: Array) -> void:
    var selected = select_frames(filenames, _frames_to_extract)
    _download_next_frame(selected, 0, [])


func _download_next_frame(filenames: Array, index: int, acc: Array) -> void:
    if index >= filenames.size():
        _generating = false
        _is_sequence_mode = false
        sequence_completed.emit(acc)
        return
    generation_progress.emit("Téléchargement frame %d / %d..." % [index + 1, filenames.size()])
    var http = HTTPRequest.new()
    add_child(http)
    var filename = filenames[index]
    var url = _config.get_full_url("/view?filename=" + filename.uri_encode() + "&type=output")
    var headers: Array = []
    for h in _config.get_auth_headers():
        headers.append(h)
    http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
        http.queue_free()
        if _cancelled:
            _generating = false
            _is_sequence_mode = false
            return
        if result != HTTPRequest.RESULT_SUCCESS or code != 200:
            _generating = false
            _is_sequence_mode = false
            _fail("Erreur téléchargement frame %d (code %d)" % [index + 1, code])
            return
        var image = Image.new()
        var decode_err = image.load_png_from_buffer(body)
        if decode_err != OK:
            decode_err = image.load_jpg_from_buffer(body)
        if decode_err != OK:
            _generating = false
            _is_sequence_mode = false
            _fail("Impossible de décoder la frame %d" % [index + 1])
            return
        acc.append(image)
        _download_next_frame(filenames, index + 1, acc)
    )
    http.request(url, PackedStringArray(headers))
```

Ajouter un helper `_dispatch_prompt` (avant `_do_prompt`, vers ligne 1808) :

```gdscript
## Redirige vers _do_prompt (génération simple) ou _do_prompt_sequence (mode séquence).
func _dispatch_prompt(filename: String, prompt_text: String) -> void:
    if _is_sequence_mode:
        _do_prompt_sequence(filename, prompt_text)
    else:
        _do_prompt(filename, prompt_text)
```

Dans `_do_upload` (ligne ~1741), remplacer :
```gdscript
_do_prompt(filename, prompt_text)
```
par :
```gdscript
_dispatch_prompt(filename, prompt_text)
```

Dans `_do_upload_second` (ligne ~1773), remplacer :
```gdscript
_do_prompt(_source_filename, prompt_text)
```
par :
```gdscript
_dispatch_prompt(_source_filename, prompt_text)
```

Dans `_do_upload_mask` (ligne ~1802), remplacer :
```gdscript
_do_prompt(_source_filename, prompt_text)
```
par :
```gdscript
_dispatch_prompt(_source_filename, prompt_text)
```

Dans `_poll_history` (ligne ~1912), remplacer :
```gdscript
if parsed["status"] == "completed":
    _stop_polling()
    generation_progress.emit("Téléchargement du résultat...")
    _do_download(parsed["filename"])
```
par :
```gdscript
if parsed["status"] == "completed":
    _stop_polling()
    generation_progress.emit("Téléchargement du résultat...")
    if _is_sequence_mode:
        var parsed_all = parse_history_response_all(response_str, _prompt_id)
        if parsed_all["status"] == "completed":
            _do_download_sequence(parsed_all["filenames"])
        else:
            _generating = false
            _is_sequence_mode = false
            _fail("Impossible de récupérer les frames : %s" % parsed_all.get("error", "inconnu"))
    else:
        _do_download(parsed["filename"])
```

- [ ] **Step 4 : Lancer les tests**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

Attendu : PASS (tous les tests).

- [ ] **Step 5 : Commit**

```bash
git add src/services/comfyui_client.gd specs/services/test_comfyui_client_wan_vace.gd
git commit -m "feat: add parse_history_response_all + _do_download_sequence + _dispatch_prompt"
```

---

## Task 3 — `build_wan_vace_dwpose_preview_workflow()`

**Files:**
- Modify: `src/services/comfyui_client.gd` (après `_apply_negative_prompt`)
- Modify: `specs/services/test_comfyui_client_wan_vace.gd`

- [ ] **Step 1 : Écrire le test failing**

Ajouter à `specs/services/test_comfyui_client_wan_vace.gd` :

```gdscript
func test_build_wan_vace_dwpose_preview_has_load_image():
    var client = ComfyUIClientScript.new()
    var wf = client.build_wan_vace_dwpose_preview_workflow("pose.png")
    assert_eq(wf["wv:pose_src"]["inputs"]["image"], "pose.png")

func test_build_wan_vace_dwpose_preview_has_dwpose():
    var client = ComfyUIClientScript.new()
    var wf = client.build_wan_vace_dwpose_preview_workflow("pose.png")
    assert_true(wf.has("wv:dwpose"))
    assert_eq(wf["wv:dwpose"]["class_type"], "DWPreprocess")

func test_build_wan_vace_dwpose_preview_output_is_dwpose():
    var client = ComfyUIClientScript.new()
    var wf = client.build_wan_vace_dwpose_preview_workflow("pose.png")
    assert_eq(wf["9"]["inputs"]["images"][0], "wv:dwpose")

func test_build_workflow_dispatches_dwpose_preview():
    var client = ComfyUIClientScript.new()
    client._source_filename = "pose.png"
    var wf = client.build_workflow("pose.png", "", 0, false, 1.0, 1,
        ComfyUIClientScript.WorkflowType.WAN_VACE_DWPOSE_PREVIEW)
    assert_true(wf.has("wv:dwpose"))
```

- [ ] **Step 2 : Lancer pour vérifier qu'ils échouent**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

Attendu : FAIL sur les 4 nouveaux tests.

- [ ] **Step 3 : Implémenter dans `comfyui_client.gd`**

Ajouter après la constante `LORA_CREATE_FLUX_WORKFLOW_TEMPLATE` (vers ligne 1964), avant la section "Create tab" :

```gdscript
# ===== Wan VACE : séquence de poses multi-personnages =====
#
# Dépendances ComfyUI-Manager :
#   - ComfyUI-WanVideo (ou ComfyUI-WanVideoWrapper) → WanVideoModelLoader, WanVideoVACEEncode,
#     WanVideoSampler, WanVideoEmptyLatent
#   - comfyui_controlnet_aux → DWPreprocess
#   - ComfyUI-WanFunControlNet → ControlNetLoader (wan_fun_control.safetensors)
#   - ComfyUI-BiRefNet-Hugo → BiRefNetRMBG (déjà présent)
#
# Modèles requis :
#   models/wan/wan2.1-vace-14b.safetensors  (ou variante GGUF Q4)
#   models/clip/umt5-xxl-enc-bf16.safetensors
#   models/controlnet/wan_fun_control.safetensors
#   models/onnx/yolox_l.onnx + dw-ll_ucoco_384.onnx  (pour DWPose)


## Workflow minimal : estime la pose DWPose et retourne l'image squelette.
func build_wan_vace_dwpose_preview_workflow(pose_filename: String) -> Dictionary:
    return {
        "wv:pose_src": {
            "class_type": "LoadImage",
            "inputs": {"image": pose_filename}
        },
        "wv:dwpose": {
            "class_type": "DWPreprocess",
            "inputs": {
                "image": ["wv:pose_src", 0],
                "detect_hand": "enable",
                "detect_body": "enable",
                "detect_face": "enable",
                "resolution": 512,
                "bbox_detector": "yolox_l.onnx",
                "pose_estimator": "dw-ll_ucoco_384.onnx"
            }
        },
        "9": {
            "class_type": "SaveImage",
            "inputs": {
                "filename_prefix": "wan_vace_pose_preview",
                "images": ["wv:dwpose", 0]
            }
        }
    }
```

Dans `build_workflow()`, ajouter AVANT le bloc `var wf = WORKFLOW_TEMPLATE.duplicate(true)` (ligne ~910) :

```gdscript
if workflow_type == WorkflowType.WAN_VACE_DWPOSE_PREVIEW:
    return build_wan_vace_dwpose_preview_workflow(filename)
```

- [ ] **Step 4 : Lancer les tests**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

Attendu : PASS.

- [ ] **Step 5 : Commit**

```bash
git add src/services/comfyui_client.gd specs/services/test_comfyui_client_wan_vace.gd
git commit -m "feat: add build_wan_vace_dwpose_preview_workflow"
```

---

## Task 4 — `build_wan_vace_workflow()` (sans pose)

**Files:**
- Modify: `src/services/comfyui_client.gd`
- Modify: `specs/services/test_comfyui_client_wan_vace.gd`

- [ ] **Step 1 : Écrire les tests failing**

Ajouter à `specs/services/test_comfyui_client_wan_vace.gd` :

```gdscript
func test_build_wan_vace_workflow_sets_source_image():
    var client = ComfyUIClientScript.new()
    var wf = client.build_wan_vace_workflow("src.png", "two characters kissing", 42,
        false, 7.0, 20, 0.85, "", 6, 3.0)
    assert_eq(wf["wv:src"]["inputs"]["image"], "src.png")

func test_build_wan_vace_workflow_sets_prompt():
    var client = ComfyUIClientScript.new()
    var wf = client.build_wan_vace_workflow("src.png", "two characters kissing", 42,
        false, 7.0, 20, 0.85, "", 6, 3.0)
    assert_eq(wf["wv:pos"]["inputs"]["text"], "two characters kissing")

func test_build_wan_vace_workflow_sets_seed_steps_cfg():
    var client = ComfyUIClientScript.new()
    var wf = client.build_wan_vace_workflow("src.png", "prompt", 99,
        false, 5.0, 15, 0.9, "", 6, 3.0)
    assert_eq(wf["wv:sampler"]["inputs"]["seed"], 99)
    assert_eq(wf["wv:sampler"]["inputs"]["steps"], 15)
    assert_eq(wf["wv:sampler"]["inputs"]["cfg"], 5.0)
    assert_eq(wf["wv:sampler"]["inputs"]["denoise"], 0.9)

func test_build_wan_vace_workflow_computes_num_frames():
    var client = ComfyUIClientScript.new()
    # 3 sec * 16 fps = 48, rounded to multiple of 8 = 48
    var wf = client.build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0)
    assert_eq(wf["wv:vace"]["inputs"]["num_frames"], 48)
    assert_eq(wf["wv:empty_latent"]["inputs"]["num_frames"], 48)

func test_build_wan_vace_workflow_with_remove_bg():
    var client = ComfyUIClientScript.new()
    var wf = client.build_wan_vace_workflow("src.png", "p", 1, true, 7.0, 20, 0.85, "", 6, 3.0)
    assert_true(wf.has("wv:birefnet"))
    assert_eq(wf["9"]["inputs"]["images"][0], "wv:birefnet")

func test_build_wan_vace_workflow_no_birefnet_when_no_bg():
    var client = ComfyUIClientScript.new()
    var wf = client.build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0)
    assert_false(wf.has("wv:birefnet"))
    assert_eq(wf["9"]["inputs"]["images"][0], "wv:decode")
```

- [ ] **Step 2 : Lancer pour vérifier qu'ils échouent**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

- [ ] **Step 3 : Implémenter dans `comfyui_client.gd`**

Ajouter après `build_wan_vace_dwpose_preview_workflow` :

```gdscript
## Workflow Wan VACE séquence sans pose ControlNet.
## num_frames = round(duration_sec * 16 / 8) * 8, clamped [16, 128].
func build_wan_vace_workflow(
    source_filename: String,
    prompt_text: String,
    seed: int,
    remove_background: bool,
    cfg: float,
    steps: int,
    denoise: float,
    negative_prompt: String,
    frames_to_extract: int,
    duration_sec: float
) -> Dictionary:
    var total_frames = clampi(roundi(duration_sec * 16.0 / 8.0) * 8, 16, 128)
    var wf: Dictionary = {
        "wv:model": {
            "class_type": "WanVideoModelLoader",
            "inputs": {
                "model": "wan2.1-vace-14b.safetensors",
                "quantization": "disabled",
                "load_device": "main_device",
                "enable_sequential_cpu_offload": false
            }
        },
        "wv:clip": {
            "class_type": "CLIPLoader",
            "inputs": {
                "clip_name": "umt5-xxl-enc-bf16.safetensors",
                "type": "wan",
                "device": "default"
            }
        },
        "wv:pos": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "text": prompt_text,
                "clip": ["wv:clip", 0]
            }
        },
        "wv:neg": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "text": negative_prompt,
                "clip": ["wv:clip", 0]
            }
        },
        "wv:src": {
            "class_type": "LoadImage",
            "inputs": {"image": source_filename}
        },
        "wv:vace": {
            "class_type": "WanVideoVACEEncode",
            "inputs": {
                "vae": ["wv:model", 2],
                "image": ["wv:src", 0],
                "strength": 1.0,
                "num_frames": total_frames
            }
        },
        "wv:empty_latent": {
            "class_type": "WanVideoEmptyLatent",
            "inputs": {
                "width": 832,
                "height": 480,
                "batch_size": 1,
                "num_frames": total_frames
            }
        },
        "wv:sampler": {
            "class_type": "WanVideoSampler",
            "inputs": {
                "model": ["wv:model", 0],
                "positive": ["wv:pos", 0],
                "negative": ["wv:neg", 0],
                "latents": ["wv:empty_latent", 0],
                "vace_embeds": ["wv:vace", 0],
                "steps": steps,
                "cfg": cfg,
                "seed": seed,
                "scheduler": "unipc",
                "denoise": denoise
            }
        },
        "wv:decode": {
            "class_type": "VAEDecode",
            "inputs": {
                "samples": ["wv:sampler", 0],
                "vae": ["wv:model", 2]
            }
        },
        "9": {
            "class_type": "SaveImage",
            "inputs": {
                "filename_prefix": "wan_vace_frame",
                "images": ["wv:decode", 0]
            }
        }
    }
    if remove_background:
        wf["wv:birefnet"] = {
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
        wf["9"]["inputs"]["images"] = ["wv:birefnet", 0]
    return wf
```

- [ ] **Step 4 : Lancer les tests**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

Attendu : PASS.

- [ ] **Step 5 : Commit**

```bash
git add src/services/comfyui_client.gd specs/services/test_comfyui_client_wan_vace.gd
git commit -m "feat: add build_wan_vace_workflow (sans pose)"
```

---

## Task 5 — `build_wan_vace_pose_workflow()` (avec DWPose + ControlNet)

**Files:**
- Modify: `src/services/comfyui_client.gd`
- Modify: `specs/services/test_comfyui_client_wan_vace.gd`

- [ ] **Step 1 : Écrire les tests failing**

Ajouter à `specs/services/test_comfyui_client_wan_vace.gd` :

```gdscript
func test_build_wan_vace_pose_workflow_has_dwpose():
    var client = ComfyUIClientScript.new()
    var wf = client.build_wan_vace_pose_workflow(
        "src.png", "pose.png", "two characters kissing", 42,
        false, 7.0, 20, 0.85, "", 6, 3.0, 0.7)
    assert_true(wf.has("wv:dwpose"))
    assert_eq(wf["wv:dwpose"]["class_type"], "DWPreprocess")
    assert_eq(wf["wv:pose_img"]["inputs"]["image"], "pose.png")

func test_build_wan_vace_pose_workflow_has_controlnet():
    var client = ComfyUIClientScript.new()
    var wf = client.build_wan_vace_pose_workflow(
        "src.png", "pose.png", "prompt", 1,
        false, 7.0, 20, 0.85, "", 6, 3.0, 0.6)
    assert_true(wf.has("wv:ctrl_apply"))
    assert_eq(wf["wv:ctrl_apply"]["inputs"]["strength"], 0.6)

func test_build_wan_vace_pose_workflow_sampler_uses_controlnet_positive():
    var client = ComfyUIClientScript.new()
    var wf = client.build_wan_vace_pose_workflow(
        "src.png", "pose.png", "prompt", 1,
        false, 7.0, 20, 0.85, "", 6, 3.0, 0.7)
    # Le sampler doit utiliser ctrl_apply comme conditioning positif
    assert_eq(wf["wv:sampler"]["inputs"]["positive"][0], "wv:ctrl_apply")
```

- [ ] **Step 2 : Lancer pour vérifier qu'ils échouent**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

- [ ] **Step 3 : Implémenter dans `comfyui_client.gd`**

Ajouter après `build_wan_vace_workflow` :

```gdscript
## Workflow Wan VACE séquence avec DWPose ControlNet.
func build_wan_vace_pose_workflow(
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
    controlnet_strength: float
) -> Dictionary:
    # Construire la base sans pose, puis injecter les nœuds ControlNet
    var wf = build_wan_vace_workflow(source_filename, prompt_text, seed,
        remove_background, cfg, steps, denoise, negative_prompt,
        frames_to_extract, duration_sec)

    # Nœuds DWPose + ControlNet
    wf["wv:pose_img"] = {
        "class_type": "LoadImage",
        "inputs": {"image": pose_filename}
    }
    wf["wv:dwpose"] = {
        "class_type": "DWPreprocess",
        "inputs": {
            "image": ["wv:pose_img", 0],
            "detect_hand": "enable",
            "detect_body": "enable",
            "detect_face": "enable",
            "resolution": 512,
            "bbox_detector": "yolox_l.onnx",
            "pose_estimator": "dw-ll_ucoco_384.onnx"
        }
    }
    wf["wv:ctrl_loader"] = {
        "class_type": "ControlNetLoader",
        "inputs": {"control_net_name": "wan_fun_control.safetensors"}
    }
    wf["wv:ctrl_apply"] = {
        "class_type": "ControlNetApply",
        "inputs": {
            "conditioning": ["wv:pos", 0],
            "control_net": ["wv:ctrl_loader", 0],
            "image": ["wv:dwpose", 0],
            "strength": controlnet_strength
        }
    }
    # Le sampler utilise ctrl_apply au lieu de pos pour le conditioning positif
    wf["wv:sampler"]["inputs"]["positive"] = ["wv:ctrl_apply", 0]
    return wf
```

- [ ] **Step 4 : Lancer les tests**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

Attendu : PASS.

- [ ] **Step 5 : Commit**

```bash
git add src/services/comfyui_client.gd specs/services/test_comfyui_client_wan_vace.gd
git commit -m "feat: add build_wan_vace_pose_workflow (DWPose + ControlNet)"
```

---

## Task 6 — `generate_sequence()` + `_do_prompt_sequence()`

**Files:**
- Modify: `src/services/comfyui_client.gd`
- Modify: `specs/services/test_comfyui_client_wan_vace.gd`

- [ ] **Step 1 : Écrire le test failing**

Ajouter à `specs/services/test_comfyui_client_wan_vace.gd` :

```gdscript
func test_generate_sequence_fails_when_already_generating():
    var client = Node.new()
    client.set_script(ComfyUIClientScript)
    client._generating = true
    var error_received = ""
    client.generation_failed.connect(func(e): error_received = e)
    var config = load("res://src/services/comfyui_config.gd").new()
    client.generate_sequence(config, "", "", false, 7.0, 20,
        ComfyUIClientScript.WorkflowType.WAN_VACE, 0.85, "", 6, 3.0)
    assert_eq(error_received, "Une génération est déjà en cours")
    client.free()

func test_generate_sequence_fails_if_source_missing():
    var client = Node.new()
    client.set_script(ComfyUIClientScript)
    var error_received = ""
    client.generation_failed.connect(func(e): error_received = e)
    var config = load("res://src/services/comfyui_config.gd").new()
    client.generate_sequence(config, "/nonexistent/path.png", "prompt", false, 7.0, 20,
        ComfyUIClientScript.WorkflowType.WAN_VACE, 0.85, "", 6, 3.0)
    assert_string_contains(error_received, "Impossible d'ouvrir l'image")
    client.free()
```

- [ ] **Step 2 : Lancer pour vérifier qu'ils échouent**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

- [ ] **Step 3 : Implémenter `generate_sequence()` et `_do_prompt_sequence()`**

Ajouter après `generate()` (vers ligne 1570) :

```gdscript
## Génère une séquence de frames Wan VACE et émet sequence_completed(images: Array).
## Supporte uniquement ComfyUI local (pas RunPod).
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
    controlnet_strength: float = 0.7
) -> void:
    if _generating:
        _fail("Une génération est déjà en cours")
        return
    _generating = true
    _cancelled = false
    _config = config
    _remove_background = remove_background
    _cfg = cfg
    _steps = steps
    _denoise = denoise
    _workflow_type = workflow_type
    _negative_prompt = negative_prompt
    _frames_to_extract = frames_to_extract
    _duration_sec = duration_sec
    _controlnet_strength = controlnet_strength
    _is_sequence_mode = true
    _second_image_filename = ""
    _second_image_bytes = PackedByteArray()

    generation_progress.emit("Chargement de l'image source...")

    var file = FileAccess.open(source_image_path, FileAccess.READ)
    if file == null:
        _generating = false
        _is_sequence_mode = false
        _fail("Impossible d'ouvrir l'image : " + source_image_path)
        return
    var file_bytes = file.get_buffer(file.get_length())
    file.close()
    _source_filename = source_image_path.get_file()

    if second_image_path != "":
        var file2 = FileAccess.open(second_image_path, FileAccess.READ)
        if file2 != null:
            _second_image_bytes = file2.get_buffer(file2.get_length())
            file2.close()
            _second_image_filename = second_image_path.get_file()

    if config.is_runpod():
        _generating = false
        _is_sequence_mode = false
        _fail("generate_sequence() ne supporte pas RunPod (utiliser ComfyUI local)")
        return

    generation_progress.emit("Upload de l'image source vers ComfyUI...")
    _do_upload(_source_filename, file_bytes, prompt_text)
```

Ajouter `_do_prompt_sequence()` juste avant `_do_runpod_run()` (vers ligne 1571) :

```gdscript
func _do_prompt_sequence(filename: String, prompt_text: String) -> void:
    var seed = randi()
    var workflow: Dictionary
    if _workflow_type == WorkflowType.WAN_VACE_POSE:
        workflow = build_wan_vace_pose_workflow(
            filename, _second_image_filename, prompt_text, seed,
            _remove_background, _cfg, _steps, _denoise, _negative_prompt,
            _frames_to_extract, _duration_sec, _controlnet_strength)
    else:
        workflow = build_wan_vace_workflow(
            filename, prompt_text, seed,
            _remove_background, _cfg, _steps, _denoise, _negative_prompt,
            _frames_to_extract, _duration_sec)

    var payload = JSON.stringify({"prompt": workflow})
    var http = HTTPRequest.new()
    add_child(http)
    var url = _config.get_full_url("/prompt")
    var headers = PackedStringArray(["Content-Type: application/json"])
    for h in _config.get_auth_headers():
        headers.append(h)
    http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
        http.queue_free()
        if _cancelled:
            _generating = false
            _is_sequence_mode = false
            return
        if result != HTTPRequest.RESULT_SUCCESS or code != 200:
            _generating = false
            _is_sequence_mode = false
            _fail("Erreur /prompt (code %d)" % code)
            return
        _prompt_id = parse_prompt_response(body.get_string_from_utf8())
        if _prompt_id == "":
            _generating = false
            _is_sequence_mode = false
            _fail("Pas de prompt_id dans la réponse ComfyUI")
            return
        generation_progress.emit("Workflow soumis. Génération en cours...")
        _start_polling()
    )
    http.request(url, headers, HTTPClient.METHOD_POST, payload)
```

- [ ] **Step 4 : Lancer les tests**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

Attendu : PASS.

- [ ] **Step 5 : Lancer la suite complète pour vérifier pas de régression**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client.gd
```

Attendu : PASS (tous les tests existants).

- [ ] **Step 6 : Commit**

```bash
git add src/services/comfyui_client.gd specs/services/test_comfyui_client_wan_vace.gd
git commit -m "feat: add generate_sequence + _do_prompt_sequence for Wan VACE"
```

---

## Task 7 — `ai_studio_wan_vace_tab.gd` : construction de l'UI

**Files:**
- Create: `plugins/ai_studio/ai_studio_wan_vace_tab.gd`
- Modify: `specs/services/test_comfyui_client_wan_vace.gd`

- [ ] **Step 1 : Écrire le test failing**

Ajouter à `specs/services/test_comfyui_client_wan_vace.gd` :

```gdscript
func test_wan_vace_tab_builds_without_crash():
    var WanVaceTab = load("res://plugins/ai_studio/ai_studio_wan_vace_tab.gd")
    assert_not_null(WanVaceTab)
    var tab = WanVaceTab.new()
    assert_not_null(tab)
```

- [ ] **Step 2 : Lancer pour vérifier qu'il échoue**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

- [ ] **Step 3 : Créer `plugins/ai_studio/ai_studio_wan_vace_tab.gd`**

```gdscript
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")
const ImageFileDialog = preload("res://src/ui/shared/image_file_dialog.gd")
const ImageRenameService = preload("res://src/services/image_rename_service.gd")
const GalleryCacheService = preload("res://src/services/gallery_cache_service.gd")

# Shared refs (set via initialize)
var _parent_window: Window
var _get_config_fn: Callable
var _neg_input: TextEdit
var _show_preview_fn: Callable
var _open_gallery_fn: Callable
var _save_config_fn: Callable
var _resolve_path_fn: Callable
var _story_base_path: String = ""

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
var _frames_slider: HSlider
var _frames_value_label: Label
var _remove_bg_check: CheckBox

# --- UI : génération ---
var _generate_btn: Button
var _cancel_btn: Button
var _status_label: Label
var _progress_bar: ProgressBar

# --- UI : grille résultats ---
var _result_grid: HFlowContainer
var _selected_cell_vbox: VBoxContainer
var _selected_preview: TextureRect
var _name_input: LineEdit
var _save_selected_btn: Button

# State
var _client: Node = null
var _source_image_path: String = ""
var _pose_image_path: String = ""
var _pose_estimated: bool = false
var _pose_mode: bool = false
var _generated_images: Array = []
var _selected_image: Image = null
var _selected_image_index: int = -1


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
    scroll.name = "Wan VACE"
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tab_container.add_child(scroll)

    var vbox = VBoxContainer.new()
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_theme_constant_override("separation", 8)
    scroll.add_child(vbox)

    # --- Image source ---
    var src_label = Label.new()
    src_label.text = "Image source (personnages assemblés) :"
    vbox.add_child(src_label)

    var src_hbox = HBoxContainer.new()
    vbox.add_child(src_hbox)

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
    src_hbox.add_child(_source_preview)

    _source_path_label = Label.new()
    _source_path_label.text = "Aucune image sélectionnée"
    _source_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    src_hbox.add_child(_source_path_label)

    _choose_source_btn = Button.new()
    _choose_source_btn.text = "Parcourir..."
    _choose_source_btn.pressed.connect(_on_choose_source)
    src_hbox.add_child(_choose_source_btn)

    _choose_gallery_btn = Button.new()
    _choose_gallery_btn.text = "Galerie..."
    _choose_gallery_btn.pressed.connect(_on_choose_from_gallery)
    src_hbox.add_child(_choose_gallery_btn)

    vbox.add_child(HSeparator.new())

    # --- Mode toggle ---
    var mode_label = Label.new()
    mode_label.text = "Mode :"
    vbox.add_child(mode_label)

    var mode_hbox = HBoxContainer.new()
    vbox.add_child(mode_hbox)

    _mode_no_pose_btn = Button.new()
    _mode_no_pose_btn.text = "Sans pose"
    _mode_no_pose_btn.toggle_mode = true
    _mode_no_pose_btn.button_pressed = true
    _mode_no_pose_btn.pressed.connect(func():
        _pose_mode = false
        _mode_no_pose_btn.button_pressed = true
        _mode_pose_btn.button_pressed = false
        _pose_panel.visible = false
        _update_generate_button()
    )
    mode_hbox.add_child(_mode_no_pose_btn)

    _mode_pose_btn = Button.new()
    _mode_pose_btn.text = "Avec pose (DWPose)"
    _mode_pose_btn.toggle_mode = true
    _mode_pose_btn.button_pressed = false
    _mode_pose_btn.pressed.connect(func():
        _pose_mode = true
        _mode_no_pose_btn.button_pressed = false
        _mode_pose_btn.button_pressed = true
        _pose_panel.visible = true
        _update_generate_button()
    )
    mode_hbox.add_child(_mode_pose_btn)

    # --- Panneau pose (masqué par défaut) ---
    _pose_panel = VBoxContainer.new()
    _pose_panel.visible = false
    _pose_panel.add_theme_constant_override("separation", 6)
    vbox.add_child(_pose_panel)

    var pose_src_label = Label.new()
    pose_src_label.text = "Image de pose de référence :"
    _pose_panel.add_child(pose_src_label)

    var pose_hbox = HBoxContainer.new()
    _pose_panel.add_child(pose_hbox)

    _pose_preview = TextureRect.new()
    _pose_preview.custom_minimum_size = Vector2(64, 64)
    _pose_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    _pose_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    pose_hbox.add_child(_pose_preview)

    _pose_path_label = Label.new()
    _pose_path_label.text = "Aucune image sélectionnée"
    _pose_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    pose_hbox.add_child(_pose_path_label)

    _choose_pose_btn = Button.new()
    _choose_pose_btn.text = "Parcourir..."
    _choose_pose_btn.pressed.connect(_on_choose_pose)
    pose_hbox.add_child(_choose_pose_btn)

    _estimate_pose_btn = Button.new()
    _estimate_pose_btn.text = "Estimer la pose"
    _estimate_pose_btn.disabled = true
    _estimate_pose_btn.pressed.connect(_on_estimate_pose)
    _pose_panel.add_child(_estimate_pose_btn)

    var skeleton_label = Label.new()
    skeleton_label.text = "Squelette détecté :"
    _pose_panel.add_child(skeleton_label)

    _skeleton_preview = TextureRect.new()
    _skeleton_preview.custom_minimum_size = Vector2(120, 120)
    _skeleton_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    _skeleton_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _pose_panel.add_child(_skeleton_preview)

    var strength_hbox = HBoxContainer.new()
    strength_hbox.add_theme_constant_override("separation", 8)
    _pose_panel.add_child(strength_hbox)

    var strength_label = Label.new()
    strength_label.text = "ControlNet strength :"
    strength_hbox.add_child(strength_label)

    _strength_slider = HSlider.new()
    _strength_slider.min_value = 0.3
    _strength_slider.max_value = 1.0
    _strength_slider.step = 0.05
    _strength_slider.value = 0.7
    _strength_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _strength_slider.value_changed.connect(func(val: float):
        _strength_value_label.text = str(snapped(val, 0.05))
    )
    strength_hbox.add_child(_strength_slider)

    _strength_value_label = Label.new()
    _strength_value_label.text = "0.7"
    _strength_value_label.custom_minimum_size.x = 32
    strength_hbox.add_child(_strength_value_label)

    vbox.add_child(HSeparator.new())

    # --- Prompt ---
    var prompt_label = Label.new()
    prompt_label.text = "Prompt :"
    vbox.add_child(prompt_label)

    _prompt_input = TextEdit.new()
    _prompt_input.custom_minimum_size.y = 60
    _prompt_input.placeholder_text = "Décrivez l'interaction souhaitée..."
    _prompt_input.text_changed.connect(func(): _update_generate_button())
    vbox.add_child(_prompt_input)

    # --- Steps ---
    var steps_hbox = HBoxContainer.new()
    steps_hbox.add_theme_constant_override("separation", 8)
    vbox.add_child(steps_hbox)
    var steps_lbl = Label.new(); steps_lbl.text = "Steps :"
    steps_hbox.add_child(steps_lbl)
    _steps_slider = HSlider.new()
    _steps_slider.min_value = 1; _steps_slider.max_value = 50
    _steps_slider.step = 1; _steps_slider.value = 20
    _steps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _steps_slider.value_changed.connect(func(val: float): _steps_value_label.text = str(int(val)))
    steps_hbox.add_child(_steps_slider)
    _steps_value_label = Label.new(); _steps_value_label.text = "20"
    _steps_value_label.custom_minimum_size.x = 32
    steps_hbox.add_child(_steps_value_label)

    # --- CFG ---
    var cfg_hbox = HBoxContainer.new()
    cfg_hbox.add_theme_constant_override("separation", 8)
    vbox.add_child(cfg_hbox)
    var cfg_lbl = Label.new(); cfg_lbl.text = "CFG :"
    cfg_hbox.add_child(cfg_lbl)
    _cfg_slider = HSlider.new()
    _cfg_slider.min_value = 1.0; _cfg_slider.max_value = 10.0
    _cfg_slider.step = 0.5; _cfg_slider.value = 7.0
    _cfg_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _cfg_slider.value_changed.connect(func(val: float):
        _cfg_value_label.text = str(snapped(val, 0.5))
        update_cfg_hint(_neg_input.text.strip_edges() != "")
    )
    cfg_hbox.add_child(_cfg_slider)
    _cfg_value_label = Label.new(); _cfg_value_label.text = "7.0"
    _cfg_value_label.custom_minimum_size.x = 32
    cfg_hbox.add_child(_cfg_value_label)

    _cfg_hint = Label.new()
    _cfg_hint.text = "CFG >= 3 requis pour le negative prompt"
    _cfg_hint.add_theme_font_size_override("font_size", 11)
    _cfg_hint.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
    _cfg_hint.visible = false
    vbox.add_child(_cfg_hint)

    # --- Denoise ---
    var denoise_hbox = HBoxContainer.new()
    denoise_hbox.add_theme_constant_override("separation", 8)
    vbox.add_child(denoise_hbox)
    var denoise_lbl = Label.new(); denoise_lbl.text = "Denoise :"
    denoise_hbox.add_child(denoise_lbl)
    _denoise_slider = HSlider.new()
    _denoise_slider.min_value = 0.5; _denoise_slider.max_value = 1.0
    _denoise_slider.step = 0.05; _denoise_slider.value = 0.85
    _denoise_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _denoise_slider.value_changed.connect(func(val: float): _denoise_value_label.text = str(snapped(val, 0.05)))
    denoise_hbox.add_child(_denoise_slider)
    _denoise_value_label = Label.new(); _denoise_value_label.text = "0.85"
    _denoise_value_label.custom_minimum_size.x = 40
    denoise_hbox.add_child(_denoise_value_label)

    # --- Durée ---
    var dur_hbox = HBoxContainer.new()
    dur_hbox.add_theme_constant_override("separation", 8)
    vbox.add_child(dur_hbox)
    var dur_lbl = Label.new(); dur_lbl.text = "Durée (sec) :"
    dur_hbox.add_child(dur_lbl)
    _duration_slider = HSlider.new()
    _duration_slider.min_value = 1; _duration_slider.max_value = 8
    _duration_slider.step = 1; _duration_slider.value = 3
    _duration_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _duration_slider.value_changed.connect(func(val: float): _duration_value_label.text = str(int(val)))
    dur_hbox.add_child(_duration_slider)
    _duration_value_label = Label.new(); _duration_value_label.text = "3"
    _duration_value_label.custom_minimum_size.x = 24
    dur_hbox.add_child(_duration_value_label)

    # --- Frames à extraire ---
    var frames_hbox = HBoxContainer.new()
    frames_hbox.add_theme_constant_override("separation", 8)
    vbox.add_child(frames_hbox)
    var frames_lbl = Label.new(); frames_lbl.text = "Frames à extraire :"
    frames_hbox.add_child(frames_lbl)
    _frames_slider = HSlider.new()
    _frames_slider.min_value = 4; _frames_slider.max_value = 12
    _frames_slider.step = 1; _frames_slider.value = 6
    _frames_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _frames_slider.value_changed.connect(func(val: float): _frames_value_label.text = str(int(val)))
    frames_hbox.add_child(_frames_slider)
    _frames_value_label = Label.new(); _frames_value_label.text = "6"
    _frames_value_label.custom_minimum_size.x = 24
    frames_hbox.add_child(_frames_value_label)

    # --- Fond transparent ---
    _remove_bg_check = CheckBox.new()
    _remove_bg_check.text = "Fond transparent (BiRefNet)"
    _remove_bg_check.button_pressed = true
    vbox.add_child(_remove_bg_check)

    vbox.add_child(HSeparator.new())

    # --- Boutons génération ---
    var gen_hbox = HBoxContainer.new()
    gen_hbox.add_theme_constant_override("separation", 8)
    vbox.add_child(gen_hbox)

    _generate_btn = Button.new()
    _generate_btn.text = "Générer"
    _generate_btn.disabled = true
    _generate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _generate_btn.pressed.connect(_on_generate_pressed)
    gen_hbox.add_child(_generate_btn)

    _cancel_btn = Button.new()
    _cancel_btn.text = "Annuler"
    _cancel_btn.disabled = true
    _cancel_btn.pressed.connect(_on_cancel_pressed)
    gen_hbox.add_child(_cancel_btn)

    _status_label = Label.new()
    _status_label.text = ""
    vbox.add_child(_status_label)

    _progress_bar = ProgressBar.new()
    _progress_bar.visible = false
    _progress_bar.custom_minimum_size.y = 8
    _progress_bar.indeterminate = true
    vbox.add_child(_progress_bar)

    vbox.add_child(HSeparator.new())

    # --- Grille résultats ---
    var results_label = Label.new()
    results_label.text = "Frames générées :"
    vbox.add_child(results_label)

    var grid_scroll = ScrollContainer.new()
    grid_scroll.custom_minimum_size.y = 200
    grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(grid_scroll)

    _result_grid = HFlowContainer.new()
    _result_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _result_grid.add_theme_constant_override("h_separation", 8)
    _result_grid.add_theme_constant_override("v_separation", 8)
    grid_scroll.add_child(_result_grid)

    # --- Panneau sélection frame ---
    _selected_cell_vbox = VBoxContainer.new()
    _selected_cell_vbox.visible = false
    _selected_cell_vbox.add_theme_constant_override("separation", 6)
    vbox.add_child(_selected_cell_vbox)

    var sel_lbl = Label.new()
    sel_lbl.text = "Frame sélectionnée :"
    _selected_cell_vbox.add_child(sel_lbl)

    _selected_preview = TextureRect.new()
    _selected_preview.custom_minimum_size = Vector2(200, 200)
    _selected_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    _selected_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _selected_preview.mouse_filter = Control.MOUSE_FILTER_STOP
    _selected_preview.gui_input.connect(func(event: InputEvent):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            if _selected_preview.texture:
                _show_preview_fn.call(_selected_preview.texture, "Frame VACE")
    )
    _selected_cell_vbox.add_child(_selected_preview)

    var name_lbl = Label.new()
    name_lbl.text = "Nom de l'image :"
    _selected_cell_vbox.add_child(name_lbl)

    _name_input = LineEdit.new()
    _name_input.placeholder_text = "Nom du fichier (sans extension)"
    _name_input.editable = false
    _selected_cell_vbox.add_child(_name_input)

    _save_selected_btn = Button.new()
    _save_selected_btn.text = "Sauvegarder cette frame"
    _save_selected_btn.disabled = true
    _save_selected_btn.pressed.connect(_on_save_selected)
    _selected_cell_vbox.add_child(_save_selected_btn)


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

- [ ] **Step 4 : Lancer le test**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

Attendu : PASS.

- [ ] **Step 5 : Commit**

```bash
git add plugins/ai_studio/ai_studio_wan_vace_tab.gd specs/services/test_comfyui_client_wan_vace.gd
git commit -m "feat: add ai_studio_wan_vace_tab.gd (UI build)"
```

---

## Task 8 — `ai_studio_wan_vace_tab.gd` : logique de génération

**Files:**
- Modify: `plugins/ai_studio/ai_studio_wan_vace_tab.gd`
- Modify: `specs/services/test_comfyui_client_wan_vace.gd`

- [ ] **Step 1 : Écrire les tests failing**

Ajouter à `specs/services/test_comfyui_client_wan_vace.gd` :

```gdscript
func test_wan_vace_tab_generate_button_disabled_without_url():
    var WanVaceTab = load("res://plugins/ai_studio/ai_studio_wan_vace_tab.gd")
    var tab = WanVaceTab.new()
    var container = TabContainer.new()
    var neg = TextEdit.new()
    var window = Window.new()
    window.add_child(container)
    window.add_child(neg)
    var config_script = load("res://src/services/comfyui_config.gd")
    tab.initialize(window,
        func(): return config_script.new(),   # URL vide par défaut
        neg,
        func(_t, _n): pass,
        func(_c): pass,
        func(): pass,
        func(p): return p
    )
    tab.build_tab(container)
    tab.update_generate_button()
    assert_true(tab._generate_btn.disabled)
    window.queue_free()
```

- [ ] **Step 2 : Lancer pour vérifier qu'il échoue**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

Attendu : FAIL car `_update_generate_button` n'existe pas encore.

- [ ] **Step 3 : Ajouter la logique dans `ai_studio_wan_vace_tab.gd`**

Ajouter à la fin du fichier (après `cancel_generation`) :

```gdscript
# ========================================================
# Private logic
# ========================================================


func _update_generate_button() -> void:
    if _generate_btn == null:
        return
    var has_url = _get_config_fn.call().get_url() != ""
    var has_prompt = _prompt_input.text.strip_edges() != ""
    var has_source = _source_image_path != ""
    var pose_ready = not _pose_mode or _pose_estimated
    _generate_btn.disabled = not (has_url and has_prompt and has_source and pose_ready)


func _on_choose_source() -> void:
    var dialog = ImageFileDialog.new()
    dialog.file_selected.connect(func(path: String):
        _source_image_path = path
        _source_path_label.text = path.get_file()
        _load_preview(_source_preview, path)
        _update_generate_button()
    )
    _parent_window.add_child(dialog)
    dialog.popup_centered(Vector2i(900, 600))


func _on_choose_from_gallery() -> void:
    _open_gallery_fn.call(func(path: String):
        _source_image_path = path
        _source_path_label.text = path.get_file()
        _load_preview(_source_preview, path)
        _update_generate_button()
    )


func _on_choose_pose() -> void:
    var dialog = ImageFileDialog.new()
    dialog.file_selected.connect(func(path: String):
        _pose_image_path = path
        _pose_path_label.text = path.get_file()
        _load_preview(_pose_preview, path)
        _pose_estimated = false
        _skeleton_preview.texture = null
        _estimate_pose_btn.disabled = false
        _update_generate_button()
    )
    _parent_window.add_child(dialog)
    dialog.popup_centered(Vector2i(900, 600))


func _on_estimate_pose() -> void:
    _save_config_fn.call()
    if _client != null:
        _client.cancel()
        _client.queue_free()
    _client = Node.new()
    _client.set_script(ComfyUIClient)
    _parent_window.add_child(_client)
    _client.generation_completed.connect(_on_pose_estimation_completed)
    _client.generation_failed.connect(_on_generation_failed)
    _client.generation_progress.connect(_on_generation_progress)
    _estimate_pose_btn.disabled = true
    _set_inputs_enabled(false)
    _show_status("Estimation de la pose...")
    var config = _get_config_fn.call()
    var neg = _neg_input.text.strip_edges()
    _client.generate(config, _pose_image_path, "", false, 1.0, 1,
        ComfyUIClient.WorkflowType.WAN_VACE_DWPOSE_PREVIEW,
        1.0, neg, 80, 1.0, [])


func _on_pose_estimation_completed(skeleton_image: Image) -> void:
    _skeleton_preview.texture = ImageTexture.create_from_image(skeleton_image)
    _pose_estimated = true
    _estimate_pose_btn.disabled = false
    _set_inputs_enabled(true)
    _show_success("Pose détectée !")
    _update_generate_button()
    _client = null


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
    _generate_btn.disabled = true
    _cancel_btn.disabled = false
    _generated_images.clear()
    _clear_result_grid()
    _selected_cell_vbox.visible = false
    _set_inputs_enabled(false)
    _show_status("Lancement...")
    var config = _get_config_fn.call()
    var neg = _neg_input.text.strip_edges()
    var workflow_type = ComfyUIClient.WorkflowType.WAN_VACE_POSE if _pose_mode \
        else ComfyUIClient.WorkflowType.WAN_VACE
    _client.generate_sequence(
        config, _source_image_path, _prompt_input.text,
        _remove_bg_check.button_pressed,
        _cfg_slider.value, int(_steps_slider.value),
        workflow_type,
        _denoise_slider.value, neg,
        int(_frames_slider.value), float(_duration_slider.value),
        _pose_image_path if _pose_mode else "",
        _strength_slider.value
    )


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


func _on_generation_failed(error: String) -> void:
    _show_error("Erreur : " + error)
    _generate_btn.disabled = false
    _cancel_btn.disabled = true
    _estimate_pose_btn.disabled = _pose_image_path == ""
    _set_inputs_enabled(true)
    _update_generate_button()
    _client = null


func _on_generation_progress(status: String) -> void:
    _show_status(status)


func _on_cancel_pressed() -> void:
    if _client != null:
        _client.cancel()
    _cancel_btn.disabled = true


func _add_result_cell(image: Image, index: int) -> void:
    var cell = VBoxContainer.new()
    cell.add_theme_constant_override("separation", 4)
    _result_grid.add_child(cell)

    var tex_rect = TextureRect.new()
    tex_rect.custom_minimum_size = Vector2(150, 150)
    tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    tex_rect.texture = ImageTexture.create_from_image(image)
    tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
    tex_rect.gui_input.connect(func(event: InputEvent):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _select_frame(image, index)
    )
    cell.add_child(tex_rect)

    var save_btn = Button.new()
    save_btn.text = "Sauvegarder"
    save_btn.pressed.connect(func(): _select_frame(image, index))
    cell.add_child(save_btn)


func _select_frame(image: Image, index: int) -> void:
    _selected_image = image
    _selected_image_index = index
    _selected_preview.texture = ImageTexture.create_from_image(image)
    var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
    _name_input.text = "wan_vace_%d_%s" % [index + 1, timestamp]
    _name_input.editable = true
    _save_selected_btn.disabled = false
    _selected_cell_vbox.visible = true


func _on_save_selected() -> void:
    if _selected_image == null:
        return
    var img_name = _name_input.text.strip_edges()
    if img_name == "":
        var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
        img_name = "wan_vace_%d_%s" % [_selected_image_index + 1, timestamp]
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
            _do_save_selected(file_path, dir_path)
            dialog.queue_free()
        )
        dialog.canceled.connect(dialog.queue_free)
        dialog.popup_centered()
        return
    _do_save_selected(file_path, dir_path)


func _do_save_selected(file_path: String, dir_path: String) -> void:
    _selected_image.save_png(file_path)
    GalleryCacheService.clear_dir(dir_path)
    _show_success("Image sauvegardée : " + file_path.get_file())
    _save_selected_btn.disabled = true
    _name_input.editable = false


func _clear_result_grid() -> void:
    for child in _result_grid.get_children():
        child.queue_free()


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
    _choose_gallery_btn.disabled = not enabled or _story_base_path == ""
    _choose_pose_btn.disabled = not enabled
    _mode_no_pose_btn.disabled = not enabled
    _mode_pose_btn.disabled = not enabled
    _steps_slider.editable = enabled
    _cfg_slider.editable = enabled
    _denoise_slider.editable = enabled
    _duration_slider.editable = enabled
    _frames_slider.editable = enabled


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

- [ ] **Step 4 : Lancer les tests**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd
```

Attendu : PASS.

- [ ] **Step 5 : Commit**

```bash
git add plugins/ai_studio/ai_studio_wan_vace_tab.gd specs/services/test_comfyui_client_wan_vace.gd
git commit -m "feat: add ai_studio_wan_vace_tab.gd (logique génération)"
```

---

## Task 9 — Enregistrer WanVaceTab dans `ai_studio_dialog.gd`

**Files:**
- Modify: `plugins/ai_studio/ai_studio_dialog.gd`

- [ ] **Step 1 : Ajouter la const de preload (ligne ~24)**

Après `const CreateTab = preload(...)` :

```gdscript
const WanVaceTab = preload("res://plugins/ai_studio/ai_studio_wan_vace_tab.gd")
```

- [ ] **Step 2 : Ajouter la variable membre (ligne ~67)**

Après `var _create_tab: RefCounted = null` :

```gdscript
var _wan_vace_tab: RefCounted = null
```

- [ ] **Step 3 : Mettre à jour le commentaire du docstring (ligne 4)**

Remplacer :
```gdscript
## Studio IA : dialogue avancé de génération d'images par IA.
## Onze onglets : Décliner, Décliner - Zimage, Expressions, Blink, Outpainting, Inpaint, Upscale, Enhance, Upscale + Enhance, LORA Generator, Create.
```
par :
```gdscript
## Studio IA : dialogue avancé de génération d'images par IA.
## Douze onglets : Décliner, Décliner - Zimage, Expressions, Blink, Outpainting, Inpaint, Upscale, Enhance, Upscale + Enhance, LORA Generator, Create, Wan VACE.
```

- [ ] **Step 4 : Instancier + initialiser + build_tab (ligne ~189)**

Dans `_build_ui()`, après `_create_tab = CreateTab.new()` (ligne 189), ajouter :
```gdscript
_wan_vace_tab = WanVaceTab.new()
```

À la ligne 191, le `for tab in [...]` initialise et buildTab tous les onglets. Remplacer :
```gdscript
for tab in [_decl_tab, _zimage_decl_tab, _expr_tab, _blink_tab, _outpaint_tab, _inpaint_tab, _upscale_tab, _enhance_tab, _upscale_enhance_tab, _lora_gen_tab, _create_tab]:
```
par :
```gdscript
for tab in [_decl_tab, _zimage_decl_tab, _expr_tab, _blink_tab, _outpaint_tab, _inpaint_tab, _upscale_tab, _enhance_tab, _upscale_enhance_tab, _lora_gen_tab, _create_tab, _wan_vace_tab]:
```

- [ ] **Step 5 : Ajouter dans `setup()` (ligne ~96)**

Après `_create_tab.setup(story_base_path, has_story)` :
```gdscript
_wan_vace_tab.setup(story_base_path, has_story)
```

- [ ] **Step 6 : Ajouter dans `_on_close()` (ligne ~110)**

Après `_create_tab.cancel_generation()` :
```gdscript
_wan_vace_tab.cancel_generation()
```

- [ ] **Step 7 : Ajouter dans `_update_all_generate_buttons()` (ligne ~289)**

Après `_create_tab.update_generate_button()` :
```gdscript
_wan_vace_tab.update_generate_button()
```

- [ ] **Step 8 : Ajouter dans `_update_cfg_hints()` (ligne ~294)**

Remplacer :
```gdscript
for tab in [_decl_tab, _zimage_decl_tab, _expr_tab, _blink_tab, _outpaint_tab, _inpaint_tab, _upscale_tab, _enhance_tab, _upscale_enhance_tab, _lora_gen_tab, _create_tab]:
```
par :
```gdscript
for tab in [_decl_tab, _zimage_decl_tab, _expr_tab, _blink_tab, _outpaint_tab, _inpaint_tab, _upscale_tab, _enhance_tab, _upscale_enhance_tab, _lora_gen_tab, _create_tab, _wan_vace_tab]:
```

- [ ] **Step 9 : Lancer la suite complète des tests**

```bash
GODOT=${GODOT_PATH:-/Applications/Godot-4.6.1.app/Contents/MacOS/Godot}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd
```

Attendu : PASS (tous les tests).

- [ ] **Step 10 : Commit**

```bash
git add plugins/ai_studio/ai_studio_dialog.gd
git commit -m "feat: register WanVaceTab in ai_studio_dialog"
```

---

## Task 10 — Fichiers JSON standalone (référence ComfyUI UI)

**Files:**
- Create: `docs/comfyui/wan_vace_no_pose.json`
- Create: `docs/comfyui/wan_vace_with_pose.json`

Ces fichiers sont le format "workflow" de l'UI ComfyUI (pas l'API JSON). Ils permettent de tester les workflows directement dans l'interface ComfyUI avant de les utiliser via le plugin.

- [ ] **Step 1 : Générer `docs/comfyui/wan_vace_no_pose.json`**

```json
{
  "wv:model": {
    "class_type": "WanVideoModelLoader",
    "inputs": {
      "model": "wan2.1-vace-14b.safetensors",
      "quantization": "disabled",
      "load_device": "main_device",
      "enable_sequential_cpu_offload": false
    }
  },
  "wv:clip": {
    "class_type": "CLIPLoader",
    "inputs": {
      "clip_name": "umt5-xxl-enc-bf16.safetensors",
      "type": "wan",
      "device": "default"
    }
  },
  "wv:pos": {
    "class_type": "CLIPTextEncode",
    "inputs": {
      "text": "two characters kissing passionately, cinematic",
      "clip": ["wv:clip", 0]
    }
  },
  "wv:neg": {
    "class_type": "CLIPTextEncode",
    "inputs": {
      "text": "low quality, blurry",
      "clip": ["wv:clip", 0]
    }
  },
  "wv:src": {
    "class_type": "LoadImage",
    "inputs": {"image": "your_reference_image.png"}
  },
  "wv:vace": {
    "class_type": "WanVideoVACEEncode",
    "inputs": {
      "vae": ["wv:model", 2],
      "image": ["wv:src", 0],
      "strength": 1.0,
      "num_frames": 48
    }
  },
  "wv:empty_latent": {
    "class_type": "WanVideoEmptyLatent",
    "inputs": {
      "width": 832,
      "height": 480,
      "batch_size": 1,
      "num_frames": 48
    }
  },
  "wv:sampler": {
    "class_type": "WanVideoSampler",
    "inputs": {
      "model": ["wv:model", 0],
      "positive": ["wv:pos", 0],
      "negative": ["wv:neg", 0],
      "latents": ["wv:empty_latent", 0],
      "vace_embeds": ["wv:vace", 0],
      "steps": 20,
      "cfg": 7.0,
      "seed": 42,
      "scheduler": "unipc",
      "denoise": 0.85
    }
  },
  "wv:decode": {
    "class_type": "VAEDecode",
    "inputs": {
      "samples": ["wv:sampler", 0],
      "vae": ["wv:model", 2]
    }
  },
  "wv:birefnet": {
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
  },
  "9": {
    "class_type": "SaveImage",
    "inputs": {
      "filename_prefix": "wan_vace_frame",
      "images": ["wv:birefnet", 0]
    }
  }
}
```

- [ ] **Step 2 : Générer `docs/comfyui/wan_vace_with_pose.json`**

Même base que `wan_vace_no_pose.json` avec ajout des nœuds DWPose + ControlNet :

```json
{
  "wv:model": { "class_type": "WanVideoModelLoader", "inputs": { "model": "wan2.1-vace-14b.safetensors", "quantization": "disabled", "load_device": "main_device", "enable_sequential_cpu_offload": false } },
  "wv:clip": { "class_type": "CLIPLoader", "inputs": { "clip_name": "umt5-xxl-enc-bf16.safetensors", "type": "wan", "device": "default" } },
  "wv:pos": { "class_type": "CLIPTextEncode", "inputs": { "text": "two characters kissing passionately, cinematic", "clip": ["wv:clip", 0] } },
  "wv:neg": { "class_type": "CLIPTextEncode", "inputs": { "text": "low quality, blurry", "clip": ["wv:clip", 0] } },
  "wv:src": { "class_type": "LoadImage", "inputs": { "image": "your_reference_image.png" } },
  "wv:vace": { "class_type": "WanVideoVACEEncode", "inputs": { "vae": ["wv:model", 2], "image": ["wv:src", 0], "strength": 1.0, "num_frames": 48 } },
  "wv:empty_latent": { "class_type": "WanVideoEmptyLatent", "inputs": { "width": 832, "height": 480, "batch_size": 1, "num_frames": 48 } },
  "wv:pose_img": { "class_type": "LoadImage", "inputs": { "image": "your_pose_image.png" } },
  "wv:dwpose": { "class_type": "DWPreprocess", "inputs": { "image": ["wv:pose_img", 0], "detect_hand": "enable", "detect_body": "enable", "detect_face": "enable", "resolution": 512, "bbox_detector": "yolox_l.onnx", "pose_estimator": "dw-ll_ucoco_384.onnx" } },
  "wv:ctrl_loader": { "class_type": "ControlNetLoader", "inputs": { "control_net_name": "wan_fun_control.safetensors" } },
  "wv:ctrl_apply": { "class_type": "ControlNetApply", "inputs": { "conditioning": ["wv:pos", 0], "control_net": ["wv:ctrl_loader", 0], "image": ["wv:dwpose", 0], "strength": 0.7 } },
  "wv:sampler": { "class_type": "WanVideoSampler", "inputs": { "model": ["wv:model", 0], "positive": ["wv:ctrl_apply", 0], "negative": ["wv:neg", 0], "latents": ["wv:empty_latent", 0], "vace_embeds": ["wv:vace", 0], "steps": 20, "cfg": 7.0, "seed": 42, "scheduler": "unipc", "denoise": 0.85 } },
  "wv:decode": { "class_type": "VAEDecode", "inputs": { "samples": ["wv:sampler", 0], "vae": ["wv:model", 2] } },
  "wv:birefnet": { "class_type": "BiRefNetRMBG", "inputs": { "model": "BiRefNet-general", "mask_blur": 0, "mask_offset": 0, "invert_output": false, "refine_foreground": true, "background": "Alpha", "background_color": "#222222", "image": ["wv:decode", 0] } },
  "9": { "class_type": "SaveImage", "inputs": { "filename_prefix": "wan_vace_pose_frame", "images": ["wv:birefnet", 0] } }
}
```

- [ ] **Step 3 : Commit**

```bash
git add docs/comfyui/wan_vace_no_pose.json docs/comfyui/wan_vace_with_pose.json
git commit -m "docs: add standalone ComfyUI workflow JSON files for Wan VACE"
```

---

## Self-Review

**Couverture de la spec :**

| Exigence spec | Tâche qui l'implémente |
|--------------|----------------------|
| WorkflowType WAN_VACE/WAN_VACE_POSE/DWPOSE_PREVIEW | Task 1 |
| parse_history_response_all + select_frames | Task 2 |
| _do_download_sequence + _dispatch_prompt | Task 2 |
| build_wan_vace_dwpose_preview_workflow | Task 3 |
| build_wan_vace_workflow | Task 4 |
| build_wan_vace_pose_workflow | Task 5 |
| generate_sequence + _do_prompt_sequence | Task 6 |
| Tab UI (source, toggle, pose panel, sliders, grid) | Task 7 |
| Logique génération (generate, sequence_completed, save) | Task 8 |
| Enregistrement dialog | Task 9 |
| JSON standalone | Task 10 |

**Consistance des types :**
- `sequence_completed(images: Array)` émis dans `_do_download_sequence` → reçu dans `_on_sequence_completed(images: Array)` ✓
- `build_wan_vace_pose_workflow` appelle `build_wan_vace_workflow` en interne → les node IDs sont cohérents ✓
- `_select_frames(all_filenames, count)` public → testé → appelé dans `_do_download_sequence` ✓
- `_dispatch_prompt` appelle `_do_prompt_sequence` qui existe dans Task 6 ✓

**Placeholders :** aucun TBD/TODO dans le plan.

**Note opérationnelle :** Les noms de classes ComfyUI (`WanVideoModelLoader`, `WanVideoVACEEncode`, `WanVideoSampler`, `WanVideoEmptyLatent`) dépendent de la version du custom node ComfyUI-WanVideo installé. Si les nodes ont des noms différents, ajuster uniquement les valeurs `class_type` dans les builders GDScript — la structure du workflow reste identique.
