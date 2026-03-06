extends Control

## Menu "Chapitres / Scènes" — liste tous les chapitres et scènes de la story.
## Les scènes débloquées (atteintes dans les sauvegardes) sont cliquables.
## Les scènes verrouillées sont grisées avec "Chapitre N" / "??????".

const GameTheme = preload("res://src/ui/themes/game_theme.gd")
const UIScale = preload("res://src/ui/themes/ui_scale.gd")

signal scene_selected(chapter_uuid: String, scene_uuid: String)
signal close_pressed

var _title_label: Label
var _chapters_container: VBoxContainer


func build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	# Fond sombre
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.75)
	add_child(overlay)

	# Conteneur centré
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(UIScale.scale(800), UIScale.scale(500))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIScale.scale(16))
	panel.add_child(vbox)

	# En-tête
	var header := HBoxContainer.new()
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Chapitres / Scènes"
	_title_label.add_theme_font_size_override("font_size", UIScale.scale(28))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(UIScale.scale(50), UIScale.scale(50))
	close_btn.add_theme_font_size_override("font_size", UIScale.scale(24))
	close_btn.pressed.connect(func(): close_pressed.emit())
	GameTheme.apply_close_style(close_btn)
	header.add_child(close_btn)

	# Zone de défilement pour les chapitres
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_chapters_container = VBoxContainer.new()
	_chapters_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chapters_container.add_theme_constant_override("separation", 20)
	_chapters_container.name = "ChaptersContainer"
	scroll.add_child(_chapters_container)


## Affiche le menu avec les chapitres/scènes de la story.
## max_chapter_idx et max_scene_idx définissent la progression maximale atteinte.
func show_menu(story, max_chapter_idx: int, max_scene_idx: int) -> void:
	_populate(story, max_chapter_idx, max_scene_idx)
	visible = true


func hide_menu() -> void:
	visible = false


## Construit l'arborescence des chapitres et scènes.
func _populate(story, max_chapter_idx: int, max_scene_idx: int) -> void:
	# Nettoyer
	for child in _chapters_container.get_children():
		child.queue_free()

	if story == null:
		return

	for ch_idx in range(story.chapters.size()):
		var chapter = story.chapters[ch_idx]
		_build_chapter_section(chapter, ch_idx, max_chapter_idx, max_scene_idx)


func _build_chapter_section(chapter, ch_idx: int, max_chapter_idx: int, max_scene_idx: int) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.name = "Chapter_%d" % ch_idx
	_chapters_container.add_child(section)

	# En-tête du chapitre
	var chap_label := Label.new()
	chap_label.text = "Chapitre %d — %s" % [ch_idx + 1, chapter.chapter_name]
	chap_label.add_theme_font_size_override("font_size", UIScale.scale(20))
	chap_label.add_theme_color_override("font_color", Color("#E8D5B5"))
	chap_label.name = "ChapterHeader"
	section.add_child(chap_label)

	# Rangée de scènes avec retour à la ligne automatique
	var scenes_row := FlowContainer.new()
	scenes_row.add_theme_constant_override("h_separation", 12)
	scenes_row.add_theme_constant_override("v_separation", 12)
	scenes_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scenes_row.name = "ScenesRow"
	section.add_child(scenes_row)

	for sc_idx in range(chapter.scenes.size()):
		var scene = chapter.scenes[sc_idx]
		var unlocked := _is_scene_unlocked(ch_idx, sc_idx, max_chapter_idx, max_scene_idx)
		if unlocked:
			_build_unlocked_scene(scenes_row, chapter, scene, sc_idx)
		else:
			_build_locked_scene(scenes_row, ch_idx, sc_idx)


func _is_scene_unlocked(ch_idx: int, sc_idx: int, max_chapter_idx: int, max_scene_idx: int) -> bool:
	if ch_idx < max_chapter_idx:
		return true
	if ch_idx == max_chapter_idx and sc_idx <= max_scene_idx:
		return true
	return false


func _build_unlocked_scene(parent: FlowContainer, chapter, scene, sc_idx: int) -> void:
	var btn := Button.new()
	btn.text = scene.scene_name
	btn.custom_minimum_size = Vector2(UIScale.scale(160), UIScale.scale(60))
	btn.name = "SceneButton_%d" % sc_idx
	btn.pressed.connect(func(): scene_selected.emit(chapter.uuid, scene.uuid))
	parent.add_child(btn)


func _build_locked_scene(parent: FlowContainer, ch_idx: int, sc_idx: int) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(UIScale.scale(160), UIScale.scale(60))
	card.name = "LockedScene_%d" % sc_idx
	card.self_modulate = Color(1, 1, 1, 0.4)

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(inner)

	var chap_lbl := Label.new()
	chap_lbl.text = "Chapitre %d" % (ch_idx + 1)
	chap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chap_lbl.add_theme_font_size_override("font_size", UIScale.scale(12))
	chap_lbl.add_theme_color_override("font_color", Color("#A08060"))
	chap_lbl.name = "LockedChapterLabel"
	inner.add_child(chap_lbl)

	var scene_lbl := Label.new()
	scene_lbl.text = "??????"
	scene_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scene_lbl.add_theme_font_size_override("font_size", UIScale.scale(16))
	scene_lbl.add_theme_color_override("font_color", Color("#6B5A45"))
	scene_lbl.name = "LockedSceneLabel"
	inner.add_child(scene_lbl)

	parent.add_child(card)
