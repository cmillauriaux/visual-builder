extends GutTest

## Tests pour PlayController — integration audio en mode Play editeur.

const MainScript = load("res://src/main.gd")
const PlayControllerScript = load("res://src/controllers/play_controller.gd")
const SequenceScript = load("res://src/models/sequence.gd")
const DialogueScript = load("res://src/models/dialogue.gd")

var _main: Control


func before_each() -> void:
	_main = Control.new()
	_main.set_script(MainScript)
	add_child(_main)


func after_each() -> void:
	remove_child(_main)
	_main.queue_free()


func test_music_player_created_and_assigned() -> void:
	assert_not_null(_main._play_ctrl._music_player)
	assert_true(_main._play_ctrl._music_player is MusicPlayer)


func test_music_player_is_child_of_main() -> void:
	var mp = _main._play_ctrl._music_player
	assert_eq(mp.get_parent(), _main)


func test_apply_sequence_audio_no_crash_when_music_player_null() -> void:
	_main._play_ctrl._music_player = null
	_main._play_ctrl._current_playing_sequence = SequenceScript.new()
	_main._play_ctrl._apply_sequence_audio()
	pass_test("no crash with null music_player")


func test_apply_sequence_audio_no_crash_when_sequence_null() -> void:
	_main._play_ctrl._current_playing_sequence = null
	_main._play_ctrl._apply_sequence_audio()
	pass_test("no crash with null sequence")


func test_apply_sequence_audio_calls_apply_sequence() -> void:
	var seq = SequenceScript.new()
	seq.music = "nonexistent_music.ogg"
	seq.audio_fx = "nonexistent_fx.ogg"
	_main._play_ctrl._current_playing_sequence = seq
	# Should not crash even with invalid paths
	_main._play_ctrl._apply_sequence_audio()
	pass_test("apply_sequence_audio delegates to music_player without crash")


func test_on_stop_pressed_stops_music() -> void:
	var mp = _main._play_ctrl._music_player
	# Simulate that music was playing by setting internal state
	mp._current_music_path = "some_track.ogg"
	_main._play_ctrl.on_stop_pressed()
	assert_eq(mp._current_music_path, "", "music should be stopped after on_stop_pressed")


func test_stop_story_play_stops_music() -> void:
	var mp = _main._play_ctrl._music_player
	mp._current_music_path = "some_track.ogg"
	# Need to set story play mode for _stop_story_play to be reachable
	_main._play_ctrl._is_story_play_mode = true
	_main._play_ctrl._stop_story_play()
	assert_eq(mp._current_music_path, "", "music should be stopped after _stop_story_play")


func test_on_play_fx_finished_applies_audio() -> void:
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.text = "Test"
	seq.dialogues.append(dlg)
	_main._play_ctrl._current_playing_sequence = seq
	_main._sequence_editor_ctrl.load_sequence(seq)
	# Call the method that fires after FX finish
	_main._play_ctrl._on_play_fx_finished()
	pass_test("_on_play_fx_finished applies audio without crash")
