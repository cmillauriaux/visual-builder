extends HBoxContainer

## Fil d'Ariane pour la navigation hiérarchique.

signal level_clicked(index: int)

var _path: Array = []

func set_path(path: Array) -> void:
	_path = path.duplicate()
	_rebuild()

func get_path_labels() -> Array:
	return _path.duplicate()

func navigate_to(index: int) -> void:
	level_clicked.emit(index)

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()

	for i in range(_path.size()):
		if i > 0:
			var sep = Label.new()
			sep.text = " > "
			add_child(sep)

		var btn = Button.new()
		btn.text = _path[i]
		btn.pressed.connect(_on_level_pressed.bind(i))
		add_child(btn)

func _on_level_pressed(index: int) -> void:
	navigate_to(index)
