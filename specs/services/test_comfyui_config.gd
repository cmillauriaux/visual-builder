extends GutTest

const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")

var _config: RefCounted

func before_each():
	_config = ComfyUIConfig.new()

# --- Valeurs par défaut ---

func test_default_url():
	assert_eq(_config.get_url(), "http://localhost:8188")

func test_default_token():
	assert_eq(_config.get_token(), "")

# --- Setters ---

func test_set_url():
	_config.set_url("http://192.168.1.10:8188")
	assert_eq(_config.get_url(), "http://192.168.1.10:8188")

func test_set_token():
	_config.set_token("my-secret-token")
	assert_eq(_config.get_token(), "my-secret-token")

# --- URL complète ---

func test_get_full_url_without_token():
	_config.set_url("http://localhost:8188")
	_config.set_token("")
	assert_eq(_config.get_full_url("/upload/image"), "http://localhost:8188/upload/image")

func test_get_full_url_no_token_in_query():
	_config.set_url("http://localhost:8188")
	_config.set_token("abc123")
	assert_eq(_config.get_full_url("/upload/image"), "http://localhost:8188/upload/image")

func test_get_full_url_trailing_slash_on_base():
	_config.set_url("http://localhost:8188/")
	_config.set_token("")
	assert_eq(_config.get_full_url("/upload/image"), "http://localhost:8188/upload/image")

func test_get_full_url_with_existing_query_params():
	_config.set_url("http://localhost:8188")
	_config.set_token("abc123")
	assert_eq(_config.get_full_url("/view?filename=test.png&type=output"), "http://localhost:8188/view?filename=test.png&type=output")

# --- Auth headers ---

func test_get_auth_headers_empty_when_no_token():
	_config.set_token("")
	var headers = _config.get_auth_headers()
	assert_eq(headers.size(), 0)

func test_get_auth_headers_bearer_when_token_set():
	_config.set_token("my-secret-token")
	var headers = _config.get_auth_headers()
	assert_eq(headers.size(), 1)
	assert_eq(headers[0], "Authorization: Bearer my-secret-token")

# --- Persistance ---

func test_save_and_load():
	var path = "user://test_comfyui_config.cfg"
	_config.set_url("http://myserver:9999")
	_config.set_token("secret-token-42")
	_config.save_to(path)

	var loaded = ComfyUIConfig.new()
	loaded.load_from(path)
	assert_eq(loaded.get_url(), "http://myserver:9999")
	assert_eq(loaded.get_token(), "secret-token-42")

	# Cleanup
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_load_nonexistent_file_keeps_defaults():
	_config.load_from("user://nonexistent_config_file.cfg")
	assert_eq(_config.get_url(), "http://localhost:8188")
	assert_eq(_config.get_token(), "")
