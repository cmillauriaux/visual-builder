extends Node

## Gère l'animation périodique de clignement des yeux d'un foreground.
## Attaché à un foreground wrapper (Control avec un enfant TextureRect nommé "Texture").

const BLINK_INTERVAL_BASE := 3.0      # Intervalle moyen entre deux clignements (secondes)
const BLINK_INTERVAL_RANDOM := 1.0    # Variation aléatoire ± (secondes)
const BLINK_HOLD_DURATION := 0.3      # Durée de maintien les yeux fermés (secondes)

var _texture_rect: TextureRect = null  # Le TextureRect du foreground
var _normal_texture: Texture2D = null  # Texture yeux ouverts
var _blink_texture: Texture2D = null   # Texture yeux fermés
var _timer: Timer = null
var _is_blinking: bool = false
var _current_tween: Tween = null


## Initialise le joueur de clignotement et démarre le timer.
func setup(texture_rect: TextureRect, normal_texture: Texture2D, blink_texture: Texture2D) -> void:
	_texture_rect = texture_rect
	_normal_texture = normal_texture
	_blink_texture = blink_texture

	if _timer == null:
		_timer = Timer.new()
		_timer.one_shot = true
		add_child(_timer)
		_timer.timeout.connect(_do_blink)

	_schedule_next_blink()


## Met à jour les textures lors d'une transition de dialogue.
## Si blink est null, arrête le clignotement.
func update_textures(normal: Texture2D, blink: Texture2D) -> void:
	_normal_texture = normal
	_blink_texture = blink

	if blink == null:
		stop_blink()
	else:
		# Si un clignotement est en cours, la texture normale sera restaurée correctement
		# lors de la fin du clignotement. Si ce n'est pas le cas, on s'assure juste
		# que le timer est actif.
		if _timer != null and _timer.is_stopped() and not _is_blinking:
			_schedule_next_blink()


## Arrête le timer, stoppe tout tween en cours et restaure la texture normale.
func stop_blink() -> void:
	if _timer != null and is_instance_valid(_timer):
		_timer.stop()

	_kill_current_tween()
	_is_blinking = false

	# Restaurer la texture normale
	if _texture_rect != null and is_instance_valid(_texture_rect):
		if _normal_texture != null:
			_texture_rect.texture = _normal_texture


func _schedule_next_blink() -> void:
	if _timer == null or not is_instance_valid(_timer):
		return
	if _blink_texture == null:
		return
	var wait_time = BLINK_INTERVAL_BASE + randf_range(-BLINK_INTERVAL_RANDOM, BLINK_INTERVAL_RANDOM)
	_timer.wait_time = wait_time
	_timer.start()


func _do_blink() -> void:
	if _is_blinking:
		return
	if _texture_rect == null or not is_instance_valid(_texture_rect):
		return
	if _blink_texture == null:
		return

	_is_blinking = true
	_kill_current_tween()

	_current_tween = create_tween()

	# Swap instantané vers texture yeux fermés
	_current_tween.tween_callback(func():
		if is_instance_valid(_texture_rect) and _blink_texture != null:
			_texture_rect.texture = _blink_texture
	)

	# Maintien yeux fermés
	_current_tween.tween_interval(BLINK_HOLD_DURATION)

	# Swap instantané vers texture normale
	_current_tween.tween_callback(func():
		if is_instance_valid(_texture_rect) and _normal_texture != null:
			_texture_rect.texture = _normal_texture
	)

	# Fin : réinitialiser l'état et replanifier
	_current_tween.finished.connect(func():
		_is_blinking = false
		_current_tween = null
		_schedule_next_blink()
	)


func _kill_current_tween() -> void:
	if _current_tween != null and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = null
