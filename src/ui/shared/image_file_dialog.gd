extends FileDialog

## FileDialog spécialisé pour la sélection d'images avec prévisualisation.

var _preview_rect: TextureRect
var _preview_container: MarginContainer
var _last_path: String = ""

func _init() -> void:
	access = ACCESS_FILESYSTEM
	file_mode = FILE_MODE_OPEN_FILE
	filters = PackedStringArray(["*.png ; PNG", "*.jpg ; JPG", "*.jpeg ; JPEG", "*.webp ; WEBP"])
	
	_preview_container = MarginContainer.new()
	_preview_container.add_theme_constant_override("margin_left", 8)
	_preview_container.add_theme_constant_override("margin_right", 8)
	_preview_container.add_theme_constant_override("margin_top", 8)
	_preview_container.add_theme_constant_override("margin_bottom", 8)
	_preview_container.custom_minimum_size = Vector2(250, 0)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_preview_container.add_child(vbox)
	
	var label = Label.new()
	label.text = tr("Prévisualisation")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	_preview_rect = TextureRect.new()
	_preview_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_preview_rect)

func _ready() -> void:
	# Dans Godot 4, FileDialog est une fenêtre.
	# On cherche l'élément qui contient la liste des fichiers pour insérer notre preview à côté.
	_find_and_setup_preview(self)

func _find_and_setup_preview(node: Node) -> bool:
	for child in node.get_children(true):
		# On cherche soit un SplitContainer (Godot 4 classique) 
		# soit le MarginContainer qui contient le Tree (vu en headless)
		if child is SplitContainer:
			_wrap_in_hbox(child)
			return true
		
		if child is Tree and child.get_name() == "Tree":
			var target = child.get_parent()
			if target is MarginContainer:
				_wrap_in_hbox(target)
				return true
		
		if _find_and_setup_preview(child):
			return true
	return false

func _wrap_in_hbox(target: Control) -> void:
	var parent = target.get_parent()
	var idx = target.get_index()
	parent.remove_child(target)
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)
	parent.move_child(hbox, idx)
	
	hbox.add_child(target)
	target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	hbox.add_child(_preview_container)

func _process(_delta: float) -> void:
	if not visible:
		return
		
	var current_path = get_current_path()
	if current_path != _last_path:
		_last_path = current_path
		_update_preview(current_path)

func _update_preview(path: String) -> void:
	if path == "" or DirAccess.dir_exists_absolute(path):
		_preview_rect.texture = null
		return
		
	var ext = path.get_extension().to_lower()
	if ext in ["png", "jpg", "jpeg", "webp"]:
		var img = Image.new()
		var err = img.load(path)
		if err == OK:
			_preview_rect.texture = ImageTexture.create_from_image(img)
		else:
			_preview_rect.texture = null
	else:
		_preview_rect.texture = null
