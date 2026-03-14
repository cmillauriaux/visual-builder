# Propagation des modifications de foreground — Plan d'implémentation

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Quand un foreground est modifié, proposer de propager la modification aux foregrounds à position similaire dans les dialogues suivants.

**Architecture:** Logique de recherche/propagation dans `sequence_editor.gd`. Orchestration (snapshot, détection, confirmation) dans `sequence_ui_controller.gd`. Signal `foreground_modified` ajouté au visual editor, connecté via `main.gd`.

**Tech Stack:** GDScript (Godot 4.6.1), GUT test framework

**Spec:** `docs/superpowers/specs/2026-03-14-propagate-foreground-changes-design.md`

---

## Chunk 1 : Logique de données (sequence_editor.gd)

### Task 1: `find_similar_foregrounds` — tests

**Files:**
- Modify: `specs/ui/sequence/test_sequence_editor.gd` (ajouter après ligne 576)

- [ ] **Step 1: Écrire les tests pour `find_similar_foregrounds`**

Ajouter les tests suivants à la fin du fichier (avant le helper `_add_dialogue`) :

```gdscript
# --- Propagation: find_similar_foregrounds ---

func test_find_similar_foregrounds_returns_matches_in_following_dialogues():
	var dlg0 = _add_dialogue("A", "Texte 0")
	var fg0 = Foreground.new()
	fg0.anchor_bg = Vector2(0.50, 0.60)
	dlg0.foregrounds.append(fg0)

	var dlg1 = _add_dialogue("B", "Texte 1")
	var fg1 = Foreground.new()
	fg1.anchor_bg = Vector2(0.505, 0.605)  # within 0.01
	dlg1.foregrounds.append(fg1)

	_editor.load_sequence(_sequence)
	var matches = _editor.find_similar_foregrounds(Vector2(0.50, 0.60), 0)
	assert_eq(matches.size(), 1)
	assert_eq(matches[0]["dialogue_index"], 1)
	assert_eq(matches[0]["foreground"], fg1)


func test_find_similar_foregrounds_ignores_previous_dialogues():
	var dlg0 = _add_dialogue("A", "Texte 0")
	var fg0 = Foreground.new()
	fg0.anchor_bg = Vector2(0.50, 0.60)
	dlg0.foregrounds.append(fg0)

	var dlg1 = _add_dialogue("B", "Texte 1")
	var fg1 = Foreground.new()
	fg1.anchor_bg = Vector2(0.50, 0.60)
	dlg1.foregrounds.append(fg1)

	_editor.load_sequence(_sequence)
	# Search from dialogue 1 — dialogue 0 should not be included
	var matches = _editor.find_similar_foregrounds(Vector2(0.50, 0.60), 1)
	assert_eq(matches.size(), 0)


func test_find_similar_foregrounds_ignores_inherited_dialogues():
	var dlg0 = _add_dialogue("A", "Texte 0")
	var fg0 = Foreground.new()
	fg0.anchor_bg = Vector2(0.50, 0.60)
	dlg0.foregrounds.append(fg0)

	# dlg1 has no own foregrounds (inherits)
	var dlg1 = _add_dialogue("B", "Texte 1")

	var dlg2 = _add_dialogue("C", "Texte 2")
	var fg2 = Foreground.new()
	fg2.anchor_bg = Vector2(0.50, 0.60)
	dlg2.foregrounds.append(fg2)

	_editor.load_sequence(_sequence)
	var matches = _editor.find_similar_foregrounds(Vector2(0.50, 0.60), 0)
	# Only dlg2 has own foregrounds, dlg1 is inherited → ignored
	assert_eq(matches.size(), 1)
	assert_eq(matches[0]["dialogue_index"], 2)


func test_find_similar_foregrounds_no_match_beyond_threshold():
	var dlg0 = _add_dialogue("A", "Texte 0")
	var fg0 = Foreground.new()
	fg0.anchor_bg = Vector2(0.50, 0.60)
	dlg0.foregrounds.append(fg0)

	var dlg1 = _add_dialogue("B", "Texte 1")
	var fg1 = Foreground.new()
	fg1.anchor_bg = Vector2(0.52, 0.60)  # 0.02 > 0.01 threshold
	dlg1.foregrounds.append(fg1)

	_editor.load_sequence(_sequence)
	var matches = _editor.find_similar_foregrounds(Vector2(0.50, 0.60), 0)
	assert_eq(matches.size(), 0)


func test_find_similar_foregrounds_multiple_matches_in_same_dialogue():
	var dlg0 = _add_dialogue("A", "Texte 0")
	var fg0 = Foreground.new()
	fg0.anchor_bg = Vector2(0.50, 0.60)
	dlg0.foregrounds.append(fg0)

	var dlg1 = _add_dialogue("B", "Texte 1")
	var fg1a = Foreground.new()
	fg1a.anchor_bg = Vector2(0.505, 0.605)
	dlg1.foregrounds.append(fg1a)
	var fg1b = Foreground.new()
	fg1b.anchor_bg = Vector2(0.498, 0.598)
	dlg1.foregrounds.append(fg1b)

	_editor.load_sequence(_sequence)
	var matches = _editor.find_similar_foregrounds(Vector2(0.50, 0.60), 0)
	assert_eq(matches.size(), 2)


func test_find_similar_foregrounds_no_sequence_returns_empty():
	_editor.load_sequence(null)
	var matches = _editor.find_similar_foregrounds(Vector2(0.50, 0.60), 0)
	assert_eq(matches.size(), 0)


func test_find_similar_foregrounds_empty_dialogues_returns_empty():
	_editor.load_sequence(_sequence)
	var matches = _editor.find_similar_foregrounds(Vector2(0.50, 0.60), 0)
	assert_eq(matches.size(), 0)
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/sequence/test_sequence_editor.gd -gfilter=test_find_similar
```

Expected: FAIL — `find_similar_foregrounds` n'existe pas encore.

---

### Task 2: `find_similar_foregrounds` — implémentation

**Files:**
- Modify: `src/ui/sequence/sequence_editor.gd` (ajouter entre ligne 201 et ligne 202 `# --- CRUD Dialogues ---`)

- [ ] **Step 3: Implémenter `find_similar_foregrounds`**

Ajouter entre la ligne 201 (ligne vide après `_align_foreground_positions`) et la ligne 202 (`# --- CRUD Dialogues ---`) :

```gdscript
# --- Propagation foregrounds ---

const PROPAGATION_THRESHOLD := 0.01

func find_similar_foregrounds(anchor_bg: Vector2, from_dialogue_index: int, threshold: float = PROPAGATION_THRESHOLD) -> Array:
	if _sequence == null:
		return []
	var matches := []
	for i in range(from_dialogue_index + 1, _sequence.dialogues.size()):
		var dlg = _sequence.dialogues[i]
		if dlg.foregrounds.size() == 0:
			continue
		for fg in dlg.foregrounds:
			if absf(fg.anchor_bg.x - anchor_bg.x) <= threshold and absf(fg.anchor_bg.y - anchor_bg.y) <= threshold:
				matches.append({"dialogue_index": i, "foreground": fg})
	return matches
```

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/sequence/test_sequence_editor.gd -gfilter=test_find_similar
```

Expected: tous PASS.

- [ ] **Step 5: Commit**

```bash
git add specs/ui/sequence/test_sequence_editor.gd src/ui/sequence/sequence_editor.gd
git commit -m "feat(sequence-editor): add find_similar_foregrounds for propagation detection"
```

---

### Task 3: `propagate_fg_changes` — tests

**Files:**
- Modify: `specs/ui/sequence/test_sequence_editor.gd`

- [ ] **Step 6: Écrire les tests pour `propagate_fg_changes`**

Ajouter après les tests `find_similar` (avant le helper `_add_dialogue`) :

```gdscript
# --- Propagation: propagate_fg_changes ---

func test_propagate_fg_changes_applies_delta_for_anchor_bg():
	var dlg0 = _add_dialogue("A", "Texte 0")
	var fg0 = Foreground.new()
	fg0.anchor_bg = Vector2(0.50, 0.60)
	dlg0.foregrounds.append(fg0)

	var dlg1 = _add_dialogue("B", "Texte 1")
	var fg1 = Foreground.new()
	fg1.anchor_bg = Vector2(0.505, 0.605)
	dlg1.foregrounds.append(fg1)

	_editor.load_sequence(_sequence)
	var matches = [{"dialogue_index": 1, "foreground": fg1}]
	# Moved from (0.50, 0.60) to (0.60, 0.70) → delta = (0.10, 0.10)
	var changes = {"anchor_bg": Vector2(0.60, 0.70)}
	_editor.propagate_fg_changes(matches, changes, Vector2(0.50, 0.60))
	# fg1 was at (0.505, 0.605) + delta (0.10, 0.10) = (0.605, 0.705)
	assert_almost_eq(fg1.anchor_bg.x, 0.605, 0.001)
	assert_almost_eq(fg1.anchor_bg.y, 0.705, 0.001)


func test_propagate_fg_changes_applies_absolute_for_scale():
	var dlg0 = _add_dialogue("A", "Texte 0")
	var fg0 = Foreground.new()
	fg0.anchor_bg = Vector2(0.50, 0.60)
	fg0.scale = 1.0
	dlg0.foregrounds.append(fg0)

	var dlg1 = _add_dialogue("B", "Texte 1")
	var fg1 = Foreground.new()
	fg1.anchor_bg = Vector2(0.50, 0.60)
	fg1.scale = 0.8
	dlg1.foregrounds.append(fg1)

	_editor.load_sequence(_sequence)
	var matches = [{"dialogue_index": 1, "foreground": fg1}]
	var changes = {"scale": 1.5}
	_editor.propagate_fg_changes(matches, changes, Vector2(0.50, 0.60))
	assert_almost_eq(fg1.scale, 1.5, 0.001)


func test_propagate_fg_changes_applies_absolute_for_flip():
	var dlg0 = _add_dialogue("A", "Texte 0")
	var fg0 = Foreground.new()
	fg0.anchor_bg = Vector2(0.50, 0.60)
	dlg0.foregrounds.append(fg0)

	var dlg1 = _add_dialogue("B", "Texte 1")
	var fg1 = Foreground.new()
	fg1.anchor_bg = Vector2(0.50, 0.60)
	fg1.flip_h = false
	dlg1.foregrounds.append(fg1)

	_editor.load_sequence(_sequence)
	var matches = [{"dialogue_index": 1, "foreground": fg1}]
	var changes = {"flip_h": true}
	_editor.propagate_fg_changes(matches, changes, Vector2(0.50, 0.60))
	assert_true(fg1.flip_h)


func test_propagate_fg_changes_applies_absolute_for_z_order():
	var dlg0 = _add_dialogue("A", "Texte 0")
	var fg0 = Foreground.new()
	fg0.anchor_bg = Vector2(0.50, 0.60)
	dlg0.foregrounds.append(fg0)

	var dlg1 = _add_dialogue("B", "Texte 1")
	var fg1 = Foreground.new()
	fg1.anchor_bg = Vector2(0.50, 0.60)
	fg1.z_order = 0
	dlg1.foregrounds.append(fg1)

	_editor.load_sequence(_sequence)
	var matches = [{"dialogue_index": 1, "foreground": fg1}]
	var changes = {"z_order": 5}
	_editor.propagate_fg_changes(matches, changes, Vector2(0.50, 0.60))
	assert_eq(fg1.z_order, 5)


func test_propagate_fg_changes_applies_absolute_for_opacity():
	var dlg0 = _add_dialogue("A", "Texte 0")
	var fg0 = Foreground.new()
	fg0.anchor_bg = Vector2(0.50, 0.60)
	dlg0.foregrounds.append(fg0)

	var dlg1 = _add_dialogue("B", "Texte 1")
	var fg1 = Foreground.new()
	fg1.anchor_bg = Vector2(0.50, 0.60)
	fg1.opacity = 1.0
	dlg1.foregrounds.append(fg1)

	_editor.load_sequence(_sequence)
	var matches = [{"dialogue_index": 1, "foreground": fg1}]
	var changes = {"opacity": 0.5}
	_editor.propagate_fg_changes(matches, changes, Vector2(0.50, 0.60))
	assert_almost_eq(fg1.opacity, 0.5, 0.001)


func test_propagate_fg_changes_mixed_delta_and_absolute():
	var dlg0 = _add_dialogue("A", "Texte 0")
	var fg0 = Foreground.new()
	fg0.anchor_bg = Vector2(0.50, 0.60)
	dlg0.foregrounds.append(fg0)

	var dlg1 = _add_dialogue("B", "Texte 1")
	var fg1 = Foreground.new()
	fg1.anchor_bg = Vector2(0.505, 0.605)
	fg1.scale = 0.8
	fg1.flip_h = false
	dlg1.foregrounds.append(fg1)

	_editor.load_sequence(_sequence)
	var matches = [{"dialogue_index": 1, "foreground": fg1}]
	var changes = {"anchor_bg": Vector2(0.60, 0.70), "scale": 2.0, "flip_h": true}
	_editor.propagate_fg_changes(matches, changes, Vector2(0.50, 0.60))
	# anchor_bg: delta (0.10, 0.10) applied → (0.605, 0.705)
	assert_almost_eq(fg1.anchor_bg.x, 0.605, 0.001)
	assert_almost_eq(fg1.anchor_bg.y, 0.705, 0.001)
	# scale: absolute
	assert_almost_eq(fg1.scale, 2.0, 0.001)
	# flip_h: absolute
	assert_true(fg1.flip_h)
```

- [ ] **Step 7: Lancer les tests pour vérifier qu'ils échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/sequence/test_sequence_editor.gd -gfilter=test_propagate_fg
```

Expected: FAIL — `propagate_fg_changes` n'existe pas encore.

---

### Task 4: `propagate_fg_changes` — implémentation

**Files:**
- Modify: `src/ui/sequence/sequence_editor.gd` (ajouter après `find_similar_foregrounds`)

- [ ] **Step 8: Implémenter `propagate_fg_changes`**

Ajouter juste après `find_similar_foregrounds` :

```gdscript
func propagate_fg_changes(matches: Array, changes: Dictionary, initial_anchor_bg: Vector2) -> void:
	for match_entry in matches:
		var fg = match_entry["foreground"]
		for prop in changes.keys():
			if prop == "anchor_bg":
				var delta = changes["anchor_bg"] - initial_anchor_bg
				fg.anchor_bg += delta
			else:
				fg.set(prop, changes[prop])
```

- [ ] **Step 9: Lancer les tests pour vérifier qu'ils passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/sequence/test_sequence_editor.gd -gfilter=test_propagate_fg
```

Expected: tous PASS.

- [ ] **Step 10: Lancer TOUS les tests du fichier pour vérifier qu'il n'y a pas de régression**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/sequence/test_sequence_editor.gd
```

Expected: tous PASS.

- [ ] **Step 11: Commit**

```bash
git add specs/ui/sequence/test_sequence_editor.gd src/ui/sequence/sequence_editor.gd
git commit -m "feat(sequence-editor): add propagate_fg_changes with delta/absolute semantics"
```

---

## Chunk 2 : Signal `foreground_modified` (visual editor)

### Task 5: Signal `foreground_modified` dans le visual editor

**Files:**
- Modify: `src/ui/sequence/sequence_visual_editor.gd`

- [ ] **Step 12: Déclarer le signal `foreground_modified`**

Ajouter le signal après les signaux existants (après ligne 71, `signal inherited_foreground_edit_confirmed()`):

```gdscript
signal foreground_modified(uuid: String)
```

- [ ] **Step 13: Émettre le signal au mouse-up du drag**

Dans `_on_fg_gui_input`, après le bloc mouse-up (lignes 567-571), modifier pour émettre le signal :

Le code actuel (lignes 567-571) :
```gdscript
			else:
				if _dragging_fg:
					_apply_snap_to_foreground(uuid)
					_update_foreground_visuals()
				_dragging_fg = false
```

Remplacer par :
```gdscript
			else:
				if _dragging_fg:
					_apply_snap_to_foreground(uuid)
					_update_foreground_visuals()
					foreground_modified.emit(uuid)
				_dragging_fg = false
```

- [ ] **Step 14: Émettre le signal au mouse-up du resize**

Dans `_on_resize_handle_input`, le mouse-up (lignes 599-600) :

Le code actuel :
```gdscript
			else:
				_resizing_fg = false
```

Remplacer par :
```gdscript
			else:
				if _resizing_fg:
					foreground_modified.emit(uuid)
				_resizing_fg = false
```

- [ ] **Step 15: Commit**

```bash
git add src/ui/sequence/sequence_visual_editor.gd
git commit -m "feat(visual-editor): emit foreground_modified signal on drag/resize end"
```

---

## Chunk 3 : Orchestration (sequence_ui_controller.gd + main.gd)

### Task 6: Tests d'intégration pour la propagation

**Files:**
- Create: `specs/ui/sequence/test_foreground_propagation.gd`

- [ ] **Step 16: Écrire les tests d'intégration**

```gdscript
extends GutTest

## Tests d'intégration pour la propagation des modifications de foreground.
## Teste le snapshot, la détection de changements et l'orchestration.

var SequenceUIControllerScript = load("res://src/controllers/sequence_ui_controller.gd")
var SequenceEditor = load("res://src/ui/sequence/sequence_editor.gd")
var Sequence = load("res://src/models/sequence.gd")
var Dialogue = load("res://src/models/dialogue.gd")
var Foreground = load("res://src/models/foreground.gd")

var _ctrl: Node = null
var _seq_editor: Control = null
var _sequence = null


func before_each():
	_ctrl = Node.new()
	_ctrl.set_script(SequenceUIControllerScript)
	add_child_autofree(_ctrl)

	_seq_editor = Control.new()
	_seq_editor.set_script(SequenceEditor)
	add_child_autofree(_seq_editor)

	_sequence = Sequence.new()
	_sequence.seq_name = "Test"


# --- Snapshot ---

func test_capture_fg_snapshot_captures_all_tracked_properties():
	var fg = Foreground.new()
	fg.anchor_bg = Vector2(0.3, 0.7)
	fg.scale = 1.5
	fg.z_order = 2
	fg.flip_h = true
	fg.flip_v = false
	fg.opacity = 0.8
	fg.transition_type = "fade"
	fg.transition_duration = 1.0

	var snapshot = _ctrl._capture_fg_snapshot(fg)
	assert_eq(snapshot["anchor_bg"], Vector2(0.3, 0.7))
	assert_almost_eq(snapshot["scale"], 1.5, 0.001)
	assert_eq(snapshot["z_order"], 2)
	assert_true(snapshot["flip_h"])
	assert_false(snapshot["flip_v"])
	assert_almost_eq(snapshot["opacity"], 0.8, 0.001)
	assert_eq(snapshot["transition_type"], "fade")
	assert_almost_eq(snapshot["transition_duration"], 1.0, 0.001)


func test_capture_fg_snapshot_excludes_anchor_fg():
	var fg = Foreground.new()
	var snapshot = _ctrl._capture_fg_snapshot(fg)
	assert_false(snapshot.has("anchor_fg"))


# --- Compute changes ---

func test_compute_fg_changes_detects_position_change():
	var fg = Foreground.new()
	fg.anchor_bg = Vector2(0.3, 0.7)
	var snapshot = _ctrl._capture_fg_snapshot(fg)
	fg.anchor_bg = Vector2(0.5, 0.8)
	var changes = _ctrl._compute_fg_changes(fg, snapshot)
	assert_true(changes.has("anchor_bg"))
	assert_eq(changes["anchor_bg"], Vector2(0.5, 0.8))


func test_compute_fg_changes_detects_scale_change():
	var fg = Foreground.new()
	fg.scale = 1.0
	var snapshot = _ctrl._capture_fg_snapshot(fg)
	fg.scale = 2.0
	var changes = _ctrl._compute_fg_changes(fg, snapshot)
	assert_true(changes.has("scale"))
	assert_almost_eq(changes["scale"], 2.0, 0.001)


func test_compute_fg_changes_returns_empty_when_no_change():
	var fg = Foreground.new()
	var snapshot = _ctrl._capture_fg_snapshot(fg)
	var changes = _ctrl._compute_fg_changes(fg, snapshot)
	assert_eq(changes.size(), 0)


func test_compute_fg_changes_detects_multiple_changes():
	var fg = Foreground.new()
	fg.scale = 1.0
	fg.flip_h = false
	var snapshot = _ctrl._capture_fg_snapshot(fg)
	fg.scale = 2.0
	fg.flip_h = true
	var changes = _ctrl._compute_fg_changes(fg, snapshot)
	assert_eq(changes.size(), 2)
	assert_true(changes.has("scale"))
	assert_true(changes.has("flip_h"))
```

- [ ] **Step 17: Lancer les tests pour vérifier qu'ils échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/sequence/test_foreground_propagation.gd
```

Expected: FAIL — `_capture_fg_snapshot` et `_compute_fg_changes` n'existent pas encore.

---

### Task 7: Orchestration dans `sequence_ui_controller.gd`

**Files:**
- Modify: `src/controllers/sequence_ui_controller.gd` (ajouter après ligne 13 pour les variables, et à la fin pour les méthodes)

- [ ] **Step 18: Ajouter le snapshot et la logique de propagation**

Ajouter après `var _main: Control` (ligne 13) :

```gdscript
var _fg_initial_snapshot: Dictionary = {}
var _fg_snapshot_uuid: String = ""

const TRACKED_FG_PROPERTIES := [
	"anchor_bg", "scale", "z_order",
	"flip_h", "flip_v", "opacity",
	"transition_type", "transition_duration",
]
```

Ajouter à la fin du fichier :

```gdscript

# --- Propagation foregrounds ---

func _capture_fg_snapshot(fg) -> Dictionary:
	var snapshot := {}
	for prop in TRACKED_FG_PROPERTIES:
		snapshot[prop] = fg.get(prop)
	return snapshot


func _compute_fg_changes(fg, snapshot: Dictionary) -> Dictionary:
	var changes := {}
	for key in snapshot.keys():
		if fg.get(key) != snapshot[key]:
			changes[key] = fg.get(key)
	return changes


func on_foreground_selected(uuid: String) -> void:
	# Note: for inherited foregrounds, this snapshot may reference a shared object.
	# Step 24 re-captures after ensure_own_foregrounds() creates local copies.
	_fg_snapshot_uuid = uuid
	var fg = _main._visual_editor.find_foreground(uuid)
	if fg:
		_fg_initial_snapshot = _capture_fg_snapshot(fg)
	else:
		_fg_initial_snapshot = {}


func on_foreground_deselected() -> void:
	_fg_initial_snapshot = {}
	_fg_snapshot_uuid = ""


func on_foreground_modified(uuid: String = "") -> void:
	var target_uuid = uuid if uuid != "" else _fg_snapshot_uuid
	if target_uuid == "" or _fg_initial_snapshot.is_empty():
		return

	var fg = _main._visual_editor.find_foreground(target_uuid)
	if fg == null:
		return

	var changes = _compute_fg_changes(fg, _fg_initial_snapshot)
	if changes.is_empty():
		_fg_initial_snapshot = _capture_fg_snapshot(fg)
		return

	var idx = _main._sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		_fg_initial_snapshot = _capture_fg_snapshot(fg)
		return

	var initial_anchor_bg: Vector2 = _fg_initial_snapshot.get("anchor_bg", fg.anchor_bg)
	var matches = _main._sequence_editor_ctrl.find_similar_foregrounds(initial_anchor_bg, idx)

	if matches.is_empty():
		_fg_initial_snapshot = _capture_fg_snapshot(fg)
		return

	# Count distinct dialogues
	var dialogue_indices := {}
	for m in matches:
		dialogue_indices[m["dialogue_index"]] = true

	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "%d foreground(s) dans %d dialogue(s) suivant(s) ont une position similaire.\nAppliquer la modification à tous ?" % [matches.size(), dialogue_indices.size()]
	confirm.ok_button_text = "Oui"
	confirm.cancel_button_text = "Non"

	var captured_changes = changes.duplicate()
	var captured_matches = matches.duplicate()
	var captured_initial = initial_anchor_bg

	confirm.confirmed.connect(func():
		_main._sequence_editor_ctrl.propagate_fg_changes(captured_matches, captured_changes, captured_initial)
		EventBus.story_modified.emit()
		confirm.queue_free()
	)
	confirm.canceled.connect(func():
		confirm.queue_free()
	)

	_fg_initial_snapshot = _capture_fg_snapshot(fg)

	_main.add_child(confirm)
	confirm.popup_centered()
```

- [ ] **Step 19: Lancer les tests pour vérifier qu'ils passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/sequence/test_foreground_propagation.gd
```

Expected: tous PASS.

- [ ] **Step 20: Commit**

```bash
git add src/controllers/sequence_ui_controller.gd specs/ui/sequence/test_foreground_propagation.gd
git commit -m "feat(ui-controller): add foreground propagation orchestration with snapshot/confirmation"
```

---

### Task 8: Connexion des signaux dans `main.gd`

**Files:**
- Modify: `src/main.gd`

- [ ] **Step 21: Connecter les signaux dans `_connect_signals()`**

Dans `_connect_signals()`, après la ligne de connexion `_visual_editor.inherited_foreground_edit_confirmed` (ligne 287), ajouter :

```gdscript
	_visual_editor.foreground_modified.connect(_seq_ui_ctrl.on_foreground_modified)
```

- [ ] **Step 22: Déléguer la capture du snapshot sur sélection/désélection**

Modifier `_on_foreground_selected` (vers ligne 365) pour ajouter l'appel au snapshot.

Le code actuel (lignes 364-375) :
```gdscript
func _on_foreground_selected(uuid: String) -> void:
	var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		_properties_panel.hide_panel()
		return
	var fgs = _sequence_editor_ctrl.get_effective_foregrounds(idx)
	for fg in fgs:
		if fg.uuid == uuid:
			_properties_panel.show_for_foreground(fg)
			_layer_panel.select_foreground(uuid)
			return
	_properties_panel.hide_panel()
```

Remplacer par :
```gdscript
func _on_foreground_selected(uuid: String) -> void:
	var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		_properties_panel.hide_panel()
		return
	var fgs = _sequence_editor_ctrl.get_effective_foregrounds(idx)
	for fg in fgs:
		if fg.uuid == uuid:
			_properties_panel.show_for_foreground(fg)
			_layer_panel.select_foreground(uuid)
			_seq_ui_ctrl.on_foreground_selected(uuid)
			return
	_properties_panel.hide_panel()
```

Modifier `_on_foreground_deselected` (vers ligne 378) :

Le code actuel :
```gdscript
func _on_foreground_deselected() -> void:
	_properties_panel.hide_panel()
	_layer_panel.deselect_all()
```

Remplacer par :
```gdscript
func _on_foreground_deselected() -> void:
	_properties_panel.hide_panel()
	_layer_panel.deselect_all()
	_seq_ui_ctrl.on_foreground_deselected()
```

- [ ] **Step 23: Déléguer depuis `_on_foreground_properties_changed`**

Le code actuel (ligne 383) :
```gdscript
func _on_foreground_properties_changed() -> void:
	_visual_editor.refresh_foreground_z_order()
	_visual_editor.refresh_foreground_flip()
	_visual_editor.update_foregrounds()
	_rebuild_dialogue_list()
	EventBus.story_modified.emit()
```

Remplacer par :
```gdscript
func _on_foreground_properties_changed() -> void:
	_visual_editor.refresh_foreground_z_order()
	_visual_editor.refresh_foreground_flip()
	_visual_editor.update_foregrounds()
	_rebuild_dialogue_list()
	EventBus.story_modified.emit()
	_seq_ui_ctrl.on_foreground_modified()
```

- [ ] **Step 24: Recapturer le snapshot après `ensure_own_foregrounds`**

Modifier `_on_inherited_fg_edit_confirmed` (ligne 446) :

Le code actuel :
```gdscript
func _on_inherited_fg_edit_confirmed() -> void:
	var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		return
	_sequence_editor_ctrl.ensure_own_foregrounds(idx)
	_update_layer_panel(idx)
	_visual_editor.set_inherited_mode(false)
	update_preview_for_dialogue(idx)
	EventBus.story_modified.emit()
```

Remplacer par :
```gdscript
func _on_inherited_fg_edit_confirmed() -> void:
	var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		return
	_sequence_editor_ctrl.ensure_own_foregrounds(idx)
	_update_layer_panel(idx)
	_visual_editor.set_inherited_mode(false)
	update_preview_for_dialogue(idx)
	EventBus.story_modified.emit()
	# Re-resolve foreground by UUID after ensure_own_foregrounds (new objects)
	var selected_uuid = _visual_editor._selected_fg_uuid
	if selected_uuid != "":
		var seq = _sequence_editor_ctrl.get_sequence()
		if seq and idx >= 0 and idx < seq.dialogues.size():
			for fg in seq.dialogues[idx].foregrounds:
				if fg.uuid == selected_uuid:
					_seq_ui_ctrl.on_foreground_selected(selected_uuid)
					break
```

- [ ] **Step 25: Commit**

```bash
git add src/main.gd
git commit -m "feat(main): wire foreground propagation signals and snapshot lifecycle"
```

---

## Chunk 4 : Tests de régression et validation finale

### Task 9: Tests de régression complets

- [ ] **Step 26: Lancer tous les tests unitaires**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd
```

Expected: tous PASS, pas de régression.

- [ ] **Step 27: Lancer `/check-global-acceptance`**

Exécuter la validation obligatoire avant de déclarer le travail terminé.

- [ ] **Step 28: Commit final si corrections nécessaires**

Si des corrections ont été apportées lors des étapes 26-27, committer :

```bash
git add -A
git commit -m "fix: address regression issues from foreground propagation"
```
