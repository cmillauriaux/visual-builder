extends HBoxContainer

## Fil d'Ariane pour la navigation hiérarchique.

signal level_clicked(index: int)
signal story_context_menu_requested()
signal story_rename_requested()

var _path: Array = []
var _current_level: String = "chapters"
var _popup_menu: PopupMenu = null

const POPUP_ID_RENAME = 0
const POPUP_ID_GO_CHAPTERS = 1

func set_path(path: Array) -> void:
	_path = path.duplicate()
	_rebuild()

func get_path_labels() -> Array:
	return _path.duplicate()

func set_current_level(level: String) -> void:
	_current_level = level

func get_popup_menu() -> PopupMenu:
	return _popup_menu

func navigate_to(index: int) -> void:
	level_clicked.emit(index)

func _rebuild() -> void:
	for child in get_children():
		if child != _popup_menu:
			child.queue_free()

	if _popup_menu == null:
		_popup_menu = PopupMenu.new()
		_popup_menu.name = "StoryPopupMenu"
		_popup_menu.id_pressed.connect(_on_popup_id_pressed)
		add_child(_popup_menu)

	for i in range(_path.size()):
		if i > 0:
			var sep = Label.new()
			sep.text = " > "
			add_child(sep)

		var btn = Button.new()
		btn.text = _path[i]
		btn.pressed.connect(_on_level_pressed.bind(i))
		add_child(btn)

	_update_popup_items()

func _update_popup_items() -> void:
	if _popup_menu == null:
		return
	_popup_menu.clear()
	_popup_menu.add_item("Renommer", POPUP_ID_RENAME)
	if _current_level != "chapters":
		_popup_menu.add_item("Aller aux chapitres", POPUP_ID_GO_CHAPTERS)

func _on_level_pressed(index: int) -> void:
	if index == 0:
		story_context_menu_requested.emit()
		_show_popup_at_story_button()
	else:
		navigate_to(index)

func _show_popup_at_story_button() -> void:
	if _popup_menu == null:
		return
	# Positionner le popup sous le premier bouton
	var story_btn: Button = null
	for child in get_children():
		if child is Button:
			story_btn = child
			break
	if story_btn:
		var pos = story_btn.global_position + Vector2(0, story_btn.size.y)
		_popup_menu.position = Vector2i(int(pos.x), int(pos.y))
		_popup_menu.popup()

func _on_popup_id_pressed(id: int) -> void:
	if id == POPUP_ID_RENAME:
		story_rename_requested.emit()
	elif id == POPUP_ID_GO_CHAPTERS:
		level_clicked.emit(0)
