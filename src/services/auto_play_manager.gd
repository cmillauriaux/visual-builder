extends RefCounted

## Gere l'avance automatique des dialogues (auto-play).
## Demarre un timer apres la fin du typewriter et emet un signal pour avancer.

signal auto_advance_requested()
signal auto_play_toggled(active: bool)

var enabled: bool = false
var delay: float = 2.0

var _scene_tree: SceneTree = null
var _timer: SceneTreeTimer = null


func setup(scene_tree: SceneTree) -> void:
	_scene_tree = scene_tree


func toggle() -> void:
	enabled = not enabled
	if not enabled:
		stop_timer()
	auto_play_toggled.emit(enabled)


func start_timer() -> void:
	if not enabled or _scene_tree == null:
		return
	stop_timer()
	_timer = _scene_tree.create_timer(delay)
	_timer.timeout.connect(_on_timer_timeout)


func stop_timer() -> void:
	# SceneTreeTimer cannot be cancelled directly, so we disconnect
	if _timer != null and _timer.timeout.is_connected(_on_timer_timeout):
		_timer.timeout.disconnect(_on_timer_timeout)
	_timer = null


func reset() -> void:
	if enabled:
		enabled = false
		stop_timer()
		auto_play_toggled.emit(false)


func _on_timer_timeout() -> void:
	_timer = null
	if enabled:
		auto_advance_requested.emit()
