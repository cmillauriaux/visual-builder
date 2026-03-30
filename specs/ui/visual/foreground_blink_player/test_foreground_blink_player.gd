extends GutTest

## Tests pour ForegroundBlinkPlayer
## Vérifie l'initialisation, la gestion des textures, l'arrêt et les constantes.

var ForegroundBlinkPlayerScript = load("res://src/ui/visual/foreground_blink_player.gd")

var _player: Node = null
var _texture_rect: TextureRect = null


func before_each() -> void:
	_player = Node.new()
	_player.set_script(ForegroundBlinkPlayerScript)
	add_child(_player)

	_texture_rect = TextureRect.new()
	add_child(_texture_rect)


func after_each() -> void:
	if is_instance_valid(_player):
		_player.stop_blink()
		_player.queue_free()
	if is_instance_valid(_texture_rect):
		_texture_rect.queue_free()


# --- Constantes ---

func test_blink_interval_base_is_5() -> void:
	assert_eq(_player.BLINK_INTERVAL_BASE, 5.0)


func test_blink_interval_random_is_1() -> void:
	assert_eq(_player.BLINK_INTERVAL_RANDOM, 1.0)


func test_blink_fade_duration_is_075ms() -> void:
	assert_almost_eq(_player.BLINK_FADE_DURATION, 0.075, 0.0001)


func test_blink_hold_duration_is_150ms() -> void:
	assert_almost_eq(_player.BLINK_HOLD_DURATION, 0.15, 0.0001)


# --- État initial ---

func test_initial_state_not_blinking() -> void:
	assert_false(_player._is_blinking)


func test_initial_texture_rect_is_null() -> void:
	assert_null(_player._texture_rect)


func test_initial_normal_texture_is_null() -> void:
	assert_null(_player._normal_texture)


func test_initial_blink_texture_is_null() -> void:
	assert_null(_player._blink_texture)


func test_initial_timer_is_null() -> void:
	assert_null(_player._timer)


# --- setup() ---

func test_setup_creates_timer() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)
	assert_not_null(_player._timer)


func test_setup_timer_is_one_shot() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)
	assert_true(_player._timer.one_shot)


func test_setup_stores_texture_rect() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)
	assert_eq(_player._texture_rect, _texture_rect)


func test_setup_stores_normal_texture() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)
	assert_eq(_player._normal_texture, normal)


func test_setup_stores_blink_texture() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)
	assert_eq(_player._blink_texture, blink)


func test_setup_starts_timer() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)
	assert_false(_player._timer.is_stopped())


func test_setup_timer_wait_time_within_range() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)
	var wait = _player._timer.wait_time
	assert_true(wait >= 4.0, "wait_time doit être >= 4.0 (5.0 - 1.0)")
	assert_true(wait <= 6.0, "wait_time doit être <= 6.0 (5.0 + 1.0)")


func test_setup_does_not_create_duplicate_timer() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)
	var first_timer = _player._timer
	_player.setup(_texture_rect, normal, blink)
	assert_eq(_player._timer, first_timer, "setup() ne doit pas créer un nouveau Timer")


# --- update_textures() ---

func test_update_textures_updates_normal() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)

	var new_normal = _make_texture()
	var new_blink = _make_texture()
	_player.update_textures(new_normal, new_blink)
	assert_eq(_player._normal_texture, new_normal)


func test_update_textures_updates_blink() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)

	var new_normal = _make_texture()
	var new_blink = _make_texture()
	_player.update_textures(new_normal, new_blink)
	assert_eq(_player._blink_texture, new_blink)


func test_update_textures_null_blink_stops_timer() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)
	assert_false(_player._timer.is_stopped(), "Timer doit être actif après setup")

	_player.update_textures(normal, null)
	assert_true(_player._timer.is_stopped(), "Timer doit être arrêté quand blink est null")


func test_update_textures_null_blink_sets_blink_texture_null() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)
	_player.update_textures(normal, null)
	assert_null(_player._blink_texture)


func test_update_textures_with_blink_keeps_timer_running() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)

	var new_normal = _make_texture()
	var new_blink = _make_texture()
	_player.update_textures(new_normal, new_blink)
	assert_false(_player._timer.is_stopped(), "Timer doit rester actif quand blink n'est pas null")


# --- stop_blink() ---

func test_stop_blink_stops_timer() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)
	assert_false(_player._timer.is_stopped())
	_player.stop_blink()
	assert_true(_player._timer.is_stopped())


func test_stop_blink_restores_modulate_alpha() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)
	_texture_rect.modulate.a = 0.0  # Simuler qu'on est en plein fade
	_player.stop_blink()
	assert_almost_eq(_texture_rect.modulate.a, 1.0, 0.001)


func test_stop_blink_restores_normal_texture() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)
	_texture_rect.texture = blink  # Simuler qu'on est sur la texture blink
	_player.stop_blink()
	assert_eq(_texture_rect.texture, normal)


func test_stop_blink_clears_is_blinking() -> void:
	var normal = _make_texture()
	var blink = _make_texture()
	_player.setup(_texture_rect, normal, blink)
	_player._is_blinking = true  # Forcer l'état blinking
	_player.stop_blink()
	assert_false(_player._is_blinking)


func test_stop_blink_when_not_setup_does_not_crash() -> void:
	# Aucun setup préalable
	_player.stop_blink()
	pass_test("stop_blink() sans setup ne doit pas planter")


# --- Méthodes exposées (vérification d'existence) ---

func test_method_setup_exists() -> void:
	assert_true(_player.has_method("setup"))


func test_method_update_textures_exists() -> void:
	assert_true(_player.has_method("update_textures"))


func test_method_stop_blink_exists() -> void:
	assert_true(_player.has_method("stop_blink"))


# --- Helper ---

func _make_texture() -> ImageTexture:
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(img)
