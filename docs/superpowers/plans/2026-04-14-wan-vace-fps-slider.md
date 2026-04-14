# WAN VACE — Slider FPS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exposer un slider FPS (4/8/12/16, défaut 8) dans l'onglet WAN VACE pour contrôler le nombre de frames générées.

**Architecture:** Ajout du paramètre `fps: int = 8` dans `generate_sequence`, propagé à `_build_wan_vace_workflow`, `_build_wan_vace_pose_workflow` et `_build_wan_i2v_workflow`. Slider UI dans le tab. Les tests existants sont mis à jour pour passer fps=16 explicitement (résultat inchangé), et de nouveaux tests couvrent fps=8.

**Tech Stack:** GDScript 4, GUT 9.3, Godot 4.6.1.

---

### Task 1 : Paramètre fps dans comfyui_client + tests

**Files:**
- Modify: `src/services/comfyui_client.gd:58-64` (instance var `_fps`)
- Modify: `src/services/comfyui_client.gd:1644-1673` (signature `generate_sequence`)
- Modify: `src/services/comfyui_client.gd:1964-1981` (`_do_prompt_sequence`)
- Modify: `src/services/comfyui_client.gd:2297-2311` (`_build_wan_vace_workflow` signature + calcul)
- Modify: `src/services/comfyui_client.gd:2425-2443` (`_build_wan_vace_pose_workflow` signature + appel interne)
- Modify: `src/services/comfyui_client.gd:2488-2501` (`_build_wan_i2v_workflow` signature + calcul)
- Test: `specs/services/test_comfyui_client_wan_vace.gd`

#### Contexte

Les tests appellent actuellement les builders sans fps — il faut passer fps=16 explicitement pour garder les résultats attendus inchangés (48 frames @ 3s).

**Signature actuelle `_build_wan_vace_workflow` :**
```gdscript
func _build_wan_vace_workflow(
    source_filename: String, prompt_text: String, seed: int,
    remove_background: bool, cfg: float, steps: int, denoise: float,
    negative_prompt: String, _frames_to_extract: int, duration_sec: float,
    width: int = 832, height: int = 480
) -> Dictionary:
    var total_frames = clampi(roundi(duration_sec * 16.0 / 8.0) * 8, 16, 128)
```

**Signature actuelle `_build_wan_i2v_workflow` :**
```gdscript
func _build_wan_i2v_workflow(
    source_filename: String, prompt_text: String, seed: int,
    cfg: float, steps: int, negative_prompt: String, duration_sec: float,
    width: int = 832, height: int = 480
) -> Dictionary:
    var fps := 16
    var num_frames: int = clamp(int(round(duration_sec * fps / 4.0)) * 4, 16, 200)
```

**Signature actuelle `_build_wan_vace_pose_workflow` :**
```gdscript
func _build_wan_vace_pose_workflow(
    source_filename: String, pose_filename: String, prompt_text: String, seed: int,
    remove_background: bool, cfg: float, steps: int, denoise: float,
    negative_prompt: String, frames_to_extract: int, duration_sec: float,
    controlnet_strength: float, width: int = 832, height: int = 480
) -> Dictionary:
    var wf = _build_wan_vace_workflow(source_filename, prompt_text, seed,
        remove_background, cfg, steps, denoise, negative_prompt,
        frames_to_extract, duration_sec, width, height)
```

**Instance vars actuelles (ligne 58-61) :**
```gdscript
var _frames_to_extract: int = 6
var _duration_sec: float = 3.0
var _controlnet_strength: float = 0.7
var _is_sequence_mode: bool = false
```

**`generate_sequence` actuelle (ligne 1644-1673) :**
```gdscript
func generate_sequence(
    config: RefCounted, source_image_path: String, prompt_text: String,
    remove_background: bool = true, cfg: float = 7.0, steps: int = 20,
    workflow_type: int = WorkflowType.WAN_VACE, denoise: float = 0.85,
    negative_prompt: String = "", frames_to_extract: int = 6,
    duration_sec: float = 3.0, second_image_path: String = "",
    controlnet_strength: float = 0.7
) -> void:
    ...
    _controlnet_strength = controlnet_strength
```

**`_do_prompt_sequence` actuelle (ligne 1964-1981) :**
```gdscript
func _do_prompt_sequence(filename: String, prompt_text: String) -> void:
    var seed = randi()
    var workflow: Dictionary
    if _workflow_type == WorkflowType.WAN_VACE_POSE:
        workflow = _build_wan_vace_pose_workflow(
            filename, _second_image_filename, prompt_text, seed,
            _remove_background, _cfg, _steps, _denoise, _negative_prompt,
            _frames_to_extract, _duration_sec, _controlnet_strength,
            _source_width, _source_height)
    elif _workflow_type == WorkflowType.WAN_I2V:
        workflow = _build_wan_i2v_workflow(
            filename, prompt_text, seed, _cfg, _steps, _negative_prompt,
            _duration_sec, _source_width, _source_height)
    else:
        workflow = _build_wan_vace_workflow(
            filename, prompt_text, seed,
            _remove_background, _cfg, _steps, _denoise, _negative_prompt,
            _frames_to_extract, _duration_sec, _source_width, _source_height)
```

---

- [ ] **Step 1 : Mettre à jour les tests existants et en ajouter de nouveaux**

Dans `specs/services/test_comfyui_client_wan_vace.gd`, trouver et modifier :

```gdscript
# Ligne ~162 — test_build_wan_vace_workflow_computes_num_frames
# AVANT :
func test_build_wan_vace_workflow_computes_num_frames():
    var client = ComfyUIClientScript.new()
    # 3 sec * 16 fps = 48, rounded to multiple of 8 = 48
    var wf = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0)
    assert_eq(wf["wv:vace"]["inputs"]["num_frames"], 48)
    # Lower bound: 0.5 sec → roundi(0.5*16/8)*8 = roundi(1)*8 = 8, clamped to 16
    var wf_short = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 0.5)
    assert_eq(wf_short["wv:vace"]["inputs"]["num_frames"], 16)
    # Upper bound: 9 sec → roundi(9*16/8)*8 = roundi(18)*8 = 144, clamped to 128
    var wf_long = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 9.0)
    assert_eq(wf_long["wv:vace"]["inputs"]["num_frames"], 128)

# APRÈS :
func test_build_wan_vace_workflow_computes_num_frames():
    var client = ComfyUIClientScript.new()
    # 3 sec * 16 fps = 48, rounded to multiple of 8 = 48
    var wf = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0, 16)
    assert_eq(wf["wv:vace"]["inputs"]["num_frames"], 48)
    # Lower bound: 0.5 sec @ 16fps → roundi(0.5*16/8)*8 = 8, clamped to 16
    var wf_short = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 0.5, 16)
    assert_eq(wf_short["wv:vace"]["inputs"]["num_frames"], 16)
    # Upper bound: 9 sec @ 16fps → roundi(18)*8 = 144, clamped to 128
    var wf_long = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 9.0, 16)
    assert_eq(wf_long["wv:vace"]["inputs"]["num_frames"], 128)
    # 3 sec @ 8fps → roundi(3*8/8)*8 = 24
    var wf_8 = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0, 8)
    assert_eq(wf_8["wv:vace"]["inputs"]["num_frames"], 24)
    # 3 sec @ 4fps → roundi(3*4/8)*8 = roundi(1.5)*8 = 16 (minimum)
    var wf_4 = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0, 4)
    assert_eq(wf_4["wv:vace"]["inputs"]["num_frames"], 16)
```

Trouver et modifier `test_build_wan_i2v_workflow_num_frames_3s` :

```gdscript
# AVANT :
func test_build_wan_i2v_workflow_num_frames_3s():
    var client = ComfyUIClientScript.new()
    # 3s × 16fps = 48, multiple of 4 = 48
    var wf = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0)
    assert_eq(wf["i2v:encode"]["inputs"]["length"], 48)

# APRÈS :
func test_build_wan_i2v_workflow_num_frames_3s():
    var client = ComfyUIClientScript.new()
    # 3s × 16fps = 48, multiple of 4 = 48
    var wf = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0, 16)
    assert_eq(wf["i2v:encode"]["inputs"]["length"], 48)
    # 3s × 8fps = 24, multiple of 4 = 24
    var wf_8 = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0, 8)
    assert_eq(wf_8["i2v:encode"]["inputs"]["length"], 24)
    # 3s × 4fps = 12, clamped to minimum 16
    var wf_4 = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0, 4)
    assert_eq(wf_4["i2v:encode"]["inputs"]["length"], 16)
```

- [ ] **Step 2 : Vérifier que les tests échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd 2>&1 | grep -E "42/42|FAILED|failed"
```

Expected: échecs sur `test_build_wan_vace_workflow_computes_num_frames` et `test_build_wan_i2v_workflow_num_frames_3s` (trop d'arguments).

- [ ] **Step 3 : Ajouter l'instance var `_fps`**

Dans `src/services/comfyui_client.gd`, ajouter après `_controlnet_strength` (ligne ~61) :

```gdscript
# --- Wan VACE sequence state ---
var _frames_to_extract: int = 6
var _duration_sec: float = 3.0
var _controlnet_strength: float = 0.7
var _fps: int = 8
var _is_sequence_mode: bool = false
```

- [ ] **Step 4 : Mettre à jour `generate_sequence`**

Ajouter `fps: int = 8` comme dernier paramètre et stocker dans `_fps` :

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
    fps: int = 8
) -> void:
    ...
    _controlnet_strength = controlnet_strength
    _fps = fps
```

- [ ] **Step 5 : Mettre à jour `_build_wan_vace_workflow`**

Ajouter `fps: int = 8` avant `width` et l'utiliser dans le calcul :

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
    height: int = 480
) -> Dictionary:
    var total_frames = clampi(roundi(duration_sec * float(fps) / 8.0) * 8, 16, 128)
```

- [ ] **Step 6 : Mettre à jour `_build_wan_vace_pose_workflow`**

Ajouter `fps: int = 8` avant `width` et le passer à `_build_wan_vace_workflow` :

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
    height: int = 480
) -> Dictionary:
    var wf = _build_wan_vace_workflow(source_filename, prompt_text, seed,
        remove_background, cfg, steps, denoise, negative_prompt,
        frames_to_extract, duration_sec, fps, width, height)
```

- [ ] **Step 7 : Mettre à jour `_build_wan_i2v_workflow`**

Remplacer le fps hardcodé par un paramètre :

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
    height: int = 480
) -> Dictionary:
    # multiple de 4 (contrainte WanImageToVideo length step=4)
    var num_frames: int = clamp(int(round(duration_sec * float(fps) / 4.0)) * 4, 16, 200)
```

- [ ] **Step 8 : Mettre à jour `_do_prompt_sequence`**

Passer `_fps` aux trois workflows :

```gdscript
func _do_prompt_sequence(filename: String, prompt_text: String) -> void:
    var seed = randi()
    var workflow: Dictionary
    if _workflow_type == WorkflowType.WAN_VACE_POSE:
        workflow = _build_wan_vace_pose_workflow(
            filename, _second_image_filename, prompt_text, seed,
            _remove_background, _cfg, _steps, _denoise, _negative_prompt,
            _frames_to_extract, _duration_sec, _controlnet_strength, _fps,
            _source_width, _source_height)
    elif _workflow_type == WorkflowType.WAN_I2V:
        workflow = _build_wan_i2v_workflow(
            filename, prompt_text, seed, _cfg, _steps, _negative_prompt,
            _duration_sec, _fps, _source_width, _source_height)
    else:
        workflow = _build_wan_vace_workflow(
            filename, prompt_text, seed,
            _remove_background, _cfg, _steps, _denoise, _negative_prompt,
            _frames_to_extract, _duration_sec, _fps, _source_width, _source_height)
```

- [ ] **Step 9 : Vérifier la compilation**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . --check-only 2>&1 | grep -E "ERROR|Parse Error"
```

Expected: aucune sortie.

- [ ] **Step 10 : Lancer les tests**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd 2>&1 | grep -E "42/42|passed|failed"
```

Expected: `42/42 passed` (ou plus si les nouveaux tests ajoutent des cas).

- [ ] **Step 11 : Commit**

```bash
git add src/services/comfyui_client.gd specs/services/test_comfyui_client_wan_vace.gd
git commit -m "feat: paramètre fps dans generate_sequence + builders WAN VACE/I2V"
```

---

### Task 2 : Slider FPS dans l'UI du tab

**Files:**
- Modify: `plugins/ai_studio/ai_studio_wan_vace_tab.gd:51-54` (déclaration var)
- Modify: `plugins/ai_studio/ai_studio_wan_vace_tab.gd:327-335` (section durée — ajouter slider fps juste après)
- Modify: `plugins/ai_studio/ai_studio_wan_vace_tab.gd:570-578` (appel generate_sequence)
- Modify: `plugins/ai_studio/ai_studio_wan_vace_tab.gd:718-721` (set_inputs_enabled)

#### Contexte

Le slider durée est construit autour de la ligne 327. Le slider fps sera placé juste en dessous, dans la même section "paramètres". L'appel `generate_sequence` est à la ligne 570.

**Déclarations UI actuelles (ligne 51-54) :**
```gdscript
var _duration_slider: HSlider
var _duration_value_label: Label
var _frames_slider: HSlider
var _frames_value_label: Label
```

**Section durée actuelle (ligne 327-335) :**
```gdscript
_duration_slider = HSlider.new()
_duration_slider.min_value = 1; _duration_slider.max_value = 8
_duration_slider.step = 1; _duration_slider.value = 3
_duration_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
_duration_slider.value_changed.connect(func(val: float): _duration_value_label.text = str(int(val)))
dur_hbox.add_child(_duration_slider)
_duration_value_label = Label.new(); _duration_value_label.text = "3"
_duration_value_label.custom_minimum_size.x = 24
dur_hbox.add_child(_duration_value_label)
```

**Appel generate_sequence actuel (ligne 570-578) :**
```gdscript
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
```

**`_set_inputs_enabled` actuel (ligne 718-721) :**
```gdscript
_duration_slider.editable = enabled
_frames_slider.editable = enabled
```

---

- [ ] **Step 1 : Ajouter les déclarations de variables**

Dans la section `# --- UI : paramètres ---` (ligne ~51), ajouter après `_frames_value_label` :

```gdscript
var _duration_slider: HSlider
var _duration_value_label: Label
var _frames_slider: HSlider
var _frames_value_label: Label
var _fps_slider: HSlider
var _fps_value_label: Label
```

- [ ] **Step 2 : Ajouter le slider FPS dans `build_tab`**

Juste après le bloc qui construit `_duration_slider` (après `dur_hbox.add_child(_duration_value_label)`), ajouter :

```gdscript
# --- FPS ---
var fps_hbox = HBoxContainer.new()
vbox.add_child(fps_hbox)
var fps_lbl = Label.new(); fps_lbl.text = "FPS :"
fps_lbl.custom_minimum_size.x = 80
fps_hbox.add_child(fps_lbl)
_fps_slider = HSlider.new()
_fps_slider.min_value = 4; _fps_slider.max_value = 16
_fps_slider.step = 4; _fps_slider.value = 8
_fps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
_fps_slider.value_changed.connect(func(val: float): _fps_value_label.text = str(int(val)) + " fps")
fps_hbox.add_child(_fps_slider)
_fps_value_label = Label.new(); _fps_value_label.text = "8 fps"
_fps_value_label.custom_minimum_size.x = 40
fps_hbox.add_child(_fps_value_label)
```

- [ ] **Step 3 : Passer le fps à `generate_sequence`**

Modifier l'appel à `generate_sequence` (ligne ~570) :

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
    int(_fps_slider.value)
)
```

- [ ] **Step 4 : Ajouter `_fps_slider` à `_set_inputs_enabled`**

```gdscript
_duration_slider.editable = enabled
_frames_slider.editable = enabled
_fps_slider.editable = enabled
```

- [ ] **Step 5 : Vérifier la compilation**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . --check-only 2>&1 | grep -E "ERROR|Parse Error"
```

Expected: aucune sortie.

- [ ] **Step 6 : Lancer les tests**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd 2>&1 | grep -E "passed|failed"
```

Expected: tous les tests passent.

- [ ] **Step 7 : Commit submodule + parent**

```bash
# Dans plugins/ai_studio/
git add ai_studio_wan_vace_tab.gd
git commit -m "feat: slider FPS (4/8/12/16) dans l'onglet WAN VACE"
git push origin main

# Dans le repo parent
cd /chemin/vers/visual-builder
git add plugins/ai_studio src/services/comfyui_client.gd specs/services/test_comfyui_client_wan_vace.gd
git commit -m "feat: slider FPS WAN VACE (défaut 8fps, range 4-16)"
git push
```
