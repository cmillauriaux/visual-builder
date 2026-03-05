extends GutTest

## Tests pour AudioPanel — panel de configuration audio d'une séquence.

const AudioPanelScript = preload("res://src/ui/sequence/audio_panel.gd")
const SequenceScript = preload("res://src/models/sequence.gd")

var _panel: VBoxContainer


func before_each() -> void:
	_panel = VBoxContainer.new()
	_panel.set_script(AudioPanelScript)
	add_child_autofree(_panel)


func test_panel_exists() -> void:
	assert_not_null(_panel)


func test_has_audio_changed_signal() -> void:
	assert_has_signal(_panel, "audio_changed")


func test_initial_music_label_text() -> void:
	assert_eq(_panel._music_label.text, "Aucune musique")


func test_initial_fx_label_text() -> void:
	assert_eq(_panel._fx_label.text, "Aucun FX")


func test_initial_music_clear_disabled() -> void:
	assert_true(_panel._music_clear_btn.disabled)


func test_initial_fx_clear_disabled() -> void:
	assert_true(_panel._fx_clear_btn.disabled)


func test_load_sequence_null() -> void:
	_panel.load_sequence(null)
	assert_eq(_panel._music_label.text, "Aucune musique")
	assert_eq(_panel._fx_label.text, "Aucun FX")


func test_load_sequence_with_music() -> void:
	var seq = SequenceScript.new()
	seq.music = "/assets/music/theme.ogg"
	_panel.load_sequence(seq)
	assert_eq(_panel._music_label.text, "theme.ogg")
	assert_false(_panel._music_clear_btn.disabled)


func test_load_sequence_with_fx() -> void:
	var seq = SequenceScript.new()
	seq.audio_fx = "/assets/fx/click.ogg"
	_panel.load_sequence(seq)
	assert_eq(_panel._fx_label.text, "click.ogg")
	assert_false(_panel._fx_clear_btn.disabled)


func test_load_sequence_with_stop_music() -> void:
	var seq = SequenceScript.new()
	seq.stop_music = true
	_panel.load_sequence(seq)
	assert_true(_panel._stop_music_check.button_pressed)


func test_clear_resets_panel() -> void:
	var seq = SequenceScript.new()
	seq.music = "/assets/music/theme.ogg"
	_panel.load_sequence(seq)
	_panel.clear()
	assert_eq(_panel._music_label.text, "Aucune musique")
	assert_true(_panel._music_clear_btn.disabled)


func test_setup_story_path() -> void:
	var parent_node = Node.new()
	add_child_autofree(parent_node)
	_panel.setup_story_path("/my/story", parent_node)
	assert_eq(_panel._story_base_path, "/my/story")
	assert_eq(_panel._dialog_parent, parent_node)


func test_on_music_clear_emits_signal() -> void:
	var seq = SequenceScript.new()
	seq.music = "/assets/music/theme.ogg"
	_panel.load_sequence(seq)
	watch_signals(_panel)
	_panel._on_music_clear()
	assert_signal_emitted(_panel, "audio_changed")
	assert_eq(seq.music, "")


func test_on_fx_clear_emits_signal() -> void:
	var seq = SequenceScript.new()
	seq.audio_fx = "/assets/fx/click.ogg"
	_panel.load_sequence(seq)
	watch_signals(_panel)
	_panel._on_fx_clear()
	assert_signal_emitted(_panel, "audio_changed")
	assert_eq(seq.audio_fx, "")


func test_on_stop_music_toggled() -> void:
	var seq = SequenceScript.new()
	_panel.load_sequence(seq)
	watch_signals(_panel)
	_panel._on_stop_music_toggled(true)
	assert_true(seq.stop_music)
	assert_signal_emitted(_panel, "audio_changed")


func test_on_music_selected() -> void:
	var seq = SequenceScript.new()
	_panel.load_sequence(seq)
	watch_signals(_panel)
	_panel._on_music_selected("/new/music.ogg")
	assert_eq(seq.music, "/new/music.ogg")
	assert_signal_emitted(_panel, "audio_changed")


func test_on_fx_selected() -> void:
	var seq = SequenceScript.new()
	_panel.load_sequence(seq)
	watch_signals(_panel)
	_panel._on_fx_selected("/new/fx.ogg")
	assert_eq(seq.audio_fx, "/new/fx.ogg")
	assert_signal_emitted(_panel, "audio_changed")


func test_music_clear_without_sequence() -> void:
	_panel._on_music_clear()
	assert_eq(_panel._sequence, null)


func test_fx_clear_without_sequence() -> void:
	_panel._on_fx_clear()
	assert_eq(_panel._sequence, null)


func test_stop_music_toggle_without_sequence() -> void:
	_panel._on_stop_music_toggled(true)
	assert_eq(_panel._sequence, null)
