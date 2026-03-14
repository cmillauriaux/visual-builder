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
