# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Persistance de la configuration IA (provider, URL + token) via ConfigFile.

const PROVIDER_LOCAL = 0   ## ComfyUI local
const PROVIDER_RUNPOD = 1  ## RunPod serverless

const DEFAULT_URL := "http://localhost:8188"
const DEFAULT_TOKEN := ""
const DEFAULT_NEGATIVE_PROMPT := ""
const DEFAULT_PATH := "user://comfyui_config.cfg"

var _provider: int = PROVIDER_LOCAL
var _url: String = DEFAULT_URL
var _token: String = ""
var _negative_prompt: String = DEFAULT_NEGATIVE_PROMPT
var _custom_expressions: PackedStringArray = PackedStringArray([])

func get_provider() -> int:
	return _provider

func set_provider(p: int) -> void:
	_provider = p

func is_runpod() -> bool:
	return _provider == PROVIDER_RUNPOD

func get_url() -> String:
	return _url

func set_url(url: String) -> void:
	_url = url

func get_token() -> String:
	return _token

func set_token(token: String) -> void:
	_token = token

func get_negative_prompt() -> String:
	return _negative_prompt

func set_negative_prompt(prompt: String) -> void:
	_negative_prompt = prompt

func get_custom_expressions() -> PackedStringArray:
	return _custom_expressions

func set_custom_expressions(expressions: PackedStringArray) -> void:
	_custom_expressions = expressions

func get_full_url(endpoint: String) -> String:
	var base = _url.rstrip("/")
	return base + endpoint

func get_auth_headers() -> PackedStringArray:
	if _token != "":
		return PackedStringArray(["Authorization: Bearer " + _token])
	return PackedStringArray([])

func save_to(path: String = DEFAULT_PATH) -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("comfyui", "provider", _provider)
	cfg.set_value("comfyui", "url", _url)
	cfg.set_value("comfyui", "token", _token)
	cfg.set_value("comfyui", "negative_prompt", _negative_prompt)
	if _custom_expressions.size() > 0:
		cfg.set_value("expressions", "custom", ",".join(_custom_expressions))
	cfg.save(path)

func load_from(path: String = DEFAULT_PATH) -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(path)
	if err != OK:
		return
	_provider = cfg.get_value("comfyui", "provider", PROVIDER_LOCAL)
	_url = cfg.get_value("comfyui", "url", DEFAULT_URL)
	_token = cfg.get_value("comfyui", "token", DEFAULT_TOKEN)
	_negative_prompt = cfg.get_value("comfyui", "negative_prompt", DEFAULT_NEGATIVE_PROMPT)
	var raw = cfg.get_value("expressions", "custom", "")
	if raw != "":
		_custom_expressions = PackedStringArray(raw.split(","))
	else:
		_custom_expressions = PackedStringArray([])