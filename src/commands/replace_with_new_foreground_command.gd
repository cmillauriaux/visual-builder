extends "res://src/commands/base_command.gd"

const ForegroundScript = preload("res://src/models/foreground.gd")

var _dialogue
var _new_foreground
var _inherited_fgs: Array
var _had_own_foregrounds: bool

func _init(dialogue, template_fg, new_image: String, inherited_fgs: Array) -> void:
	_dialogue = dialogue
	_inherited_fgs = inherited_fgs
	_had_own_foregrounds = _dialogue.foregrounds.size() > 0
	
	_new_foreground = ForegroundScript.new()
	_new_foreground.fg_name = template_fg.fg_name
	_new_foreground.image = new_image
	_new_foreground.z_order = template_fg.z_order
	_new_foreground.opacity = template_fg.opacity
	_new_foreground.flip_h = template_fg.flip_h
	_new_foreground.flip_v = template_fg.flip_v
	_new_foreground.scale = template_fg.scale
	_new_foreground.anchor_bg = template_fg.anchor_bg
	_new_foreground.anchor_fg = template_fg.anchor_fg
	_new_foreground.transition_type = template_fg.transition_type
	_new_foreground.transition_duration = template_fg.transition_duration

func execute() -> void:
	if not _had_own_foregrounds:
		_dialogue.foregrounds.clear()
		for fg in _inherited_fgs:
			_dialogue.foregrounds.append(_copy_foreground(fg))
	_dialogue.foregrounds.append(_new_foreground)

func undo() -> void:
	if _had_own_foregrounds:
		_dialogue.foregrounds.erase(_new_foreground)
	else:
		_dialogue.foregrounds.clear()

func _copy_foreground(fg):
	var copy = ForegroundScript.new()
	copy.uuid = fg.uuid
	copy.fg_name = fg.fg_name
	copy.image = fg.image
	copy.z_order = fg.z_order
	copy.opacity = fg.opacity
	copy.flip_h = fg.flip_h
	copy.flip_v = fg.flip_v
	copy.scale = fg.scale
	copy.anchor_bg = fg.anchor_bg
	copy.anchor_fg = fg.anchor_fg
	copy.transition_type = fg.transition_type
	copy.transition_duration = fg.transition_duration
	return copy

func get_label() -> String:
	return "Remplacer par un nouveau foreground"
