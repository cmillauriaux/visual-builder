extends GutTest

## Tests pour les champs audio du modèle Sequence (music, audio_fx, stop_music).

const Sequence = preload("res://src/models/sequence.gd")


func test_music_default_empty():
	var seq = Sequence.new()
	assert_eq(seq.music, "")


func test_audio_fx_default_empty():
	var seq = Sequence.new()
	assert_eq(seq.audio_fx, "")


func test_stop_music_default_false():
	var seq = Sequence.new()
	assert_false(seq.stop_music)


func test_music_to_dict():
	var seq = Sequence.new()
	seq.uuid = "seq-audio-001"
	seq.seq_name = "Test Audio"
	seq.position = Vector2(0, 0)
	seq.music = "/path/to/music.ogg"
	var dict = seq.to_dict()
	assert_eq(dict["music"], "/path/to/music.ogg")


func test_audio_fx_to_dict():
	var seq = Sequence.new()
	seq.uuid = "seq-audio-002"
	seq.seq_name = "Test FX"
	seq.position = Vector2(0, 0)
	seq.audio_fx = "/path/to/fx.mp3"
	var dict = seq.to_dict()
	assert_eq(dict["audio_fx"], "/path/to/fx.mp3")


func test_stop_music_to_dict():
	var seq = Sequence.new()
	seq.uuid = "seq-audio-003"
	seq.seq_name = "Stop Music"
	seq.position = Vector2(0, 0)
	seq.stop_music = true
	var dict = seq.to_dict()
	assert_true(dict["stop_music"])


func test_music_from_dict():
	var dict = {
		"uuid": "seq-audio-010",
		"name": "Test",
		"position": {"x": 0, "y": 0},
		"music": "/path/to/theme.ogg",
	}
	var seq = Sequence.from_dict(dict)
	assert_eq(seq.music, "/path/to/theme.ogg")


func test_audio_fx_from_dict():
	var dict = {
		"uuid": "seq-audio-011",
		"name": "Test",
		"position": {"x": 0, "y": 0},
		"audio_fx": "/path/to/sound.mp3",
	}
	var seq = Sequence.from_dict(dict)
	assert_eq(seq.audio_fx, "/path/to/sound.mp3")


func test_stop_music_from_dict():
	var dict = {
		"uuid": "seq-audio-012",
		"name": "Test",
		"position": {"x": 0, "y": 0},
		"stop_music": true,
	}
	var seq = Sequence.from_dict(dict)
	assert_true(seq.stop_music)


func test_audio_retrocompat():
	# Ancien format sans champs audio — doit utiliser les valeurs par défaut
	var dict = {
		"uuid": "seq-old-001",
		"name": "Ancien",
		"position": {"x": 0, "y": 0},
	}
	var seq = Sequence.from_dict(dict)
	assert_eq(seq.music, "")
	assert_eq(seq.audio_fx, "")
	assert_false(seq.stop_music)


func test_audio_roundtrip():
	var seq = Sequence.new()
	seq.music = "/music/theme.ogg"
	seq.audio_fx = "/fx/boom.mp3"
	seq.stop_music = true
	var dict = seq.to_dict()
	var restored = Sequence.from_dict(dict)
	assert_eq(restored.music, "/music/theme.ogg")
	assert_eq(restored.audio_fx, "/fx/boom.mp3")
	assert_true(restored.stop_music)
