extends RefCounted

const ChapterScript = preload("res://src/models/chapter.gd")
const VariableDefinitionScript = preload("res://src/models/variable_definition.gd")

var title: String = ""
var author: String = ""
var description: String = ""
var version: String = "1.0.0"
var created_at: String = ""
var updated_at: String = ""
var chapters: Array = []  # Array[Chapter]
var variables: Array = []  # Array[VariableDefinition]
var connections: Array = []  # Array[Dictionary] — {"from": uuid, "to": uuid}
var entry_point_uuid: String = ""
var menu_title: String = ""
var menu_subtitle: String = ""
var menu_background: String = ""

func _init():
	var now = _iso_now()
	created_at = now
	updated_at = now

func touch():
	updated_at = _iso_now()

func find_chapter(chapter_uuid: String):
	for ch in chapters:
		if ch.uuid == chapter_uuid:
			return ch
	return null

func find_variable(var_name: String):
	for v in variables:
		if v.var_name == var_name:
			return v
	return null

func get_variable_names() -> Array:
	var names := []
	for v in variables:
		names.append(v.var_name)
	return names

func to_dict() -> Dictionary:
	var ch_arr := []
	for ch in chapters:
		ch_arr.append(ch.to_dict_header())

	var var_arr := []
	for v in variables:
		var_arr.append(v.to_dict())

	var conn_arr := []
	for conn in connections:
		conn_arr.append(conn)

	return {
		"title": title,
		"author": author,
		"description": description,
		"version": version,
		"created_at": created_at,
		"updated_at": updated_at,
		"chapters": ch_arr,
		"variables": var_arr,
		"connections": conn_arr,
		"entry_point": entry_point_uuid,
		"menu_title": menu_title,
		"menu_subtitle": menu_subtitle,
		"menu_background": menu_background,
	}

static func from_dict(d: Dictionary):
	var script = load("res://src/models/story.gd")
	var story = script.new()
	story.title = d.get("title", "")
	story.author = d.get("author", "")
	story.description = d.get("description", "")
	story.version = d.get("version", "1.0.0")
	story.created_at = d.get("created_at", story.created_at)
	story.updated_at = d.get("updated_at", story.updated_at)

	if d.has("chapters"):
		for ch_dict in d["chapters"]:
			story.chapters.append(ChapterScript.from_dict_header(ch_dict))

	if d.has("variables"):
		for var_dict in d["variables"]:
			story.variables.append(VariableDefinitionScript.from_dict(var_dict))

	if d.has("connections"):
		for conn in d["connections"]:
			story.connections.append(conn)

	story.entry_point_uuid = d.get("entry_point", "")
	story.menu_title = d.get("menu_title", "")
	story.menu_subtitle = d.get("menu_subtitle", "")
	story.menu_background = d.get("menu_background", "")

	return story

static func _iso_now() -> String:
	var dt = Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"], dt["second"]]
