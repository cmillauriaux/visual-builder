# SPDX-License-Identifier: AGPL-3.0-only
extends GutTest

const ForegroundAnimPlayer = preload("res://src/ui/visual/foreground_anim_player.gd")

func _make_player(frame_count: int, delay: float = 0.1) -> Node:
	var player = Control.new()
	player.set_script(ForegroundAnimPlayer)
	add_child_autofree(player)
	for _i in range(frame_count):
		var img = Image.create(1, 1, false, Image.FORMAT_RGB8)
		player._frames.append(ImageTexture.create_from_image(img))
		player._delays.append(delay)
	return player

func test_default_values():
	var player = Control.new()
	player.set_script(ForegroundAnimPlayer)
	add_child_autofree(player)
	assert_eq(player.anim_speed, 1.0)
	assert_eq(player.anim_loop, true)
	assert_eq(player.anim_reverse, false)
	assert_eq(player.anim_reverse_loop, false)
	assert_false(player.is_playing())

func test_play_starts_at_frame_zero():
	var player = _make_player(3)
	player.play()
	assert_eq(player._current_frame, 0)
	assert_true(player.is_playing())

func test_play_reverse_loop_starts_at_last_frame():
	var player = _make_player(3)
	player.anim_reverse_loop = true
	player.play()
	assert_eq(player._current_frame, 2)

func test_stop_halts_playback():
	var player = _make_player(3)
	player.play()
	player.stop()
	assert_false(player.is_playing())

func test_loop_mode_cycles_forward():
	var player = _make_player(3, 0.1)
	player.anim_loop = true
	player.play()
	assert_eq(player._current_frame, 0)
	simulate(player, 2, 0.11)  # 2 × 0.11s > 2 × 0.1s → avance de 2 frames
	assert_eq(player._current_frame, 2)

func test_loop_mode_wraps_around():
	var player = _make_player(3, 0.1)
	player.anim_loop = true
	player.play()
	simulate(player, 4, 0.11)  # 4 frames → dépasse la fin, boucle : 4 % 3 = 1
	assert_eq(player._current_frame, 1)

func test_reverse_loop_cycles_backward():
	var player = _make_player(3, 0.1)
	player.anim_reverse_loop = true
	player.play()
	assert_eq(player._current_frame, 2)
	simulate(player, 1, 0.11)
	assert_eq(player._current_frame, 1)

func test_reverse_loop_wraps_around():
	var player = _make_player(3, 0.1)
	player.anim_reverse_loop = true
	player.play()
	# Commence à 2, recule de 4 : 2-1=1, 1-1=0, 0-1→wrap à 2, 2-1=1
	simulate(player, 4, 0.11)
	assert_eq(player._current_frame, 1)

func test_one_shot_forward_stops_at_last():
	var player = _make_player(3, 0.1)
	player.anim_loop = false
	player.anim_reverse = false
	player.play()
	simulate(player, 5, 0.11)
	assert_eq(player._current_frame, 2)
	assert_false(player.is_playing())

func test_one_shot_reverse_stops_at_zero():
	var player = _make_player(3, 0.1)
	player.anim_loop = false
	player.anim_reverse = true
	player.anim_reverse_loop = false
	player.play()
	# Commence à 0 en reverse → tente de reculer → stop immédiatement
	simulate(player, 2, 0.11)
	assert_eq(player._current_frame, 0)
	assert_false(player.is_playing())

func test_speed_factor_slows_advance():
	var player = _make_player(3, 0.1)
	player.anim_speed = 0.5  # ×0.5 → délai effectif 0.2s
	player.anim_loop = true
	player.play()
	simulate(player, 1, 0.11)  # 0.11s < 0.2s → pas d'avancement
	assert_eq(player._current_frame, 0)
	simulate(player, 1, 0.12)  # 0.12s de plus → total 0.23s > 0.2s → avance
	assert_eq(player._current_frame, 1)

func test_get_first_frame_texture_returns_null_when_empty():
	var player = Control.new()
	player.set_script(ForegroundAnimPlayer)
	add_child_autofree(player)
	assert_null(player.get_first_frame_texture())

func test_get_first_frame_texture_returns_first():
	var player = _make_player(3)
	assert_not_null(player.get_first_frame_texture())
	assert_eq(player.get_first_frame_texture(), player._frames[0])
