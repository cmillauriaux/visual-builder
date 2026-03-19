extends AcceptDialog

## Dialog de gestion des notifications de l'histoire.
## Chaque notification associe un pattern glob à un message affiché en toast au joueur.

const StoryNotificationScript = preload("res://src/models/story_notification.gd")

var _story = null
var _list: VBoxContainer
var _add_btn: Button


func _ready() -> void:
	title = tr("Notifications")
	ok_button_text = tr("Fermer")
	_build_ui()


func setup(story) -> void:
	_story = story
	_rebuild_list()


func get_notification_count() -> int:
	if _story == null:
		return 0
	return _story.notifications.size()


func add_notification() -> void:
	if _story == null:
		return
	var n = StoryNotificationScript.new()
	_story.notifications.append(n)
	_rebuild_list()


func remove_notification(index: int) -> void:
	if _story == null:
		return
	if index < 0 or index >= _story.notifications.size():
		return
	_story.notifications.remove_at(index)
	_rebuild_list()


func update_pattern(index: int, new_pattern: String) -> void:
	if _story == null or index < 0 or index >= _story.notifications.size():
		return
	_story.notifications[index].pattern = new_pattern


func update_message(index: int, new_message: String) -> void:
	if _story == null or index < 0 or index >= _story.notifications.size():
		return
	_story.notifications[index].message = new_message


# --- Private ---

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(500, 300)
	add_child(vbox)

	var title_label = Label.new()
	title_label.text = tr("Notifications de variables")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	var desc = Label.new()
	desc.text = tr("Définissez des patterns glob (ex: *_affinity) pour afficher\nun message quand une variable correspondante est modifiée.")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_add_btn = Button.new()
	_add_btn.text = tr("+ Ajouter une notification")
	_add_btn.pressed.connect(_on_add_pressed)
	vbox.add_child(_add_btn)


func _rebuild_list() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	if _story == null:
		return
	for i in range(_story.notifications.size()):
		var row = _create_row(i, _story.notifications[i])
		_list.add_child(row)


func _create_row(index: int, notif) -> HBoxContainer:
	var row = HBoxContainer.new()

	var pattern_edit = LineEdit.new()
	pattern_edit.text = notif.pattern
	pattern_edit.placeholder_text = "*_affinity"
	pattern_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pattern_edit.text_changed.connect(_on_pattern_changed.bind(index))
	row.add_child(pattern_edit)

	var arrow = Label.new()
	arrow.text = " → "
	row.add_child(arrow)

	var message_edit = LineEdit.new()
	message_edit.text = notif.message
	message_edit.placeholder_text = tr("Le personnage s'en souviendra")
	message_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_edit.text_changed.connect(_on_message_changed.bind(index))
	row.add_child(message_edit)

	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.pressed.connect(_on_delete_pressed.bind(index))
	row.add_child(delete_btn)

	return row


func _on_add_pressed() -> void:
	add_notification()


func _on_pattern_changed(new_text: String, index: int) -> void:
	update_pattern(index, new_text)


func _on_message_changed(new_text: String, index: int) -> void:
	update_message(index, new_text)


func _on_delete_pressed(index: int) -> void:
	remove_notification(index)
