# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

class_name DialogueModel

const ForegroundScript = preload("res://src/models/foreground.gd")

var uuid: String = ""
var character: String = ""
var text: String = ""
var voice: String = ""  # Optional: ElevenLabs voice description with annotations ([sarcastically], [whispers], etc.)
var voice_files: Dictionary = {}  # lang -> path (e.g. {"fr": "assets/voices/uuid_fr.mp3", "en": "assets/voices/uuid_en.mp3"})
var voice_request_ids: Dictionary = {}  # lang -> ElevenLabs request ID for previous_request_ids continuity
var foregrounds: Array = []  # Array[Foreground]

func _init():
	uuid = _generate_uuid()

static func _generate_uuid() -> String:
	var chars = "abcdef0123456789"
	var result = ""
	for i in range(8):
		result += chars[randi() % chars.length()]
	result += "-"
	for i in range(4):
		result += chars[randi() % chars.length()]
	result += "-4"
	for i in range(3):
		result += chars[randi() % chars.length()]
	result += "-"
	for i in range(4):
		result += chars[randi() % chars.length()]
	result += "-"
	for i in range(12):
		result += chars[randi() % chars.length()]
	return result

func to_dict() -> Dictionary:
	var fg_arr := []
	for fg in foregrounds:
		fg_arr.append(fg.to_dict())
	var d := {
		"uuid": uuid,
		"character": character,
		"text": text,
		"foregrounds": fg_arr,
	}
	if voice != "":
		d["voice"] = voice
	if not voice_files.is_empty():
		d["voice_files"] = voice_files
	if not voice_request_ids.is_empty():
		d["voice_request_ids"] = voice_request_ids
	return d

static func from_dict(d: Dictionary):
	var script = load("res://src/models/dialogue.gd")
	var dlg = script.new()
	dlg.uuid = d.get("uuid", dlg.uuid)
	dlg.character = d.get("character", "")
	dlg.text = d.get("text", "")
	dlg.voice = d.get("voice", "")
	# Rétro-compat: ancien format voice_file (String) → migration vers voice_files (Dict)
	if d.has("voice_files") and d["voice_files"] is Dictionary:
		dlg.voice_files = d["voice_files"]
	elif d.has("voice_file") and d["voice_file"] != "":
		dlg.voice_files = {"default": d["voice_file"]}
	if d.has("voice_request_ids") and d["voice_request_ids"] is Dictionary:
		dlg.voice_request_ids = d["voice_request_ids"]
	elif d.has("voice_request_id") and d["voice_request_id"] != "":
		dlg.voice_request_ids = {"default": d["voice_request_id"]}
	if d.has("foregrounds"):
		for fg_dict in d["foregrounds"]:
			dlg.foregrounds.append(ForegroundScript.from_dict(fg_dict))
	return dlg


## Retourne le voice_file pour une langue donnée, ou "" si absent.
func get_voice_file(lang: String) -> String:
	if voice_files.has(lang):
		return voice_files[lang]
	return ""


## Retourne le voice_request_id pour une langue donnée, ou "" si absent.
func get_voice_request_id(lang: String) -> String:
	if voice_request_ids.has(lang):
		return voice_request_ids[lang]
	return ""