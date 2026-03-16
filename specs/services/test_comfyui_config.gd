extends GutTest

var ComfyUIConfigScript

func before_each():
	ComfyUIConfigScript = load("res://src/services/comfyui_config.gd")

func test_default_values():
	var cfg = ComfyUIConfigScript.new()
	assert_eq(cfg.get_url(), "http://localhost:8188")
	assert_eq(cfg.get_token(), "")

func test_get_full_url():
	var cfg = ComfyUIConfigScript.new()
	cfg.set_url("http://1.2.3.4:8188/")
	assert_eq(cfg.get_full_url("/prompt"), "http://1.2.3.4:8188/prompt")

func test_get_auth_headers_empty():
	var cfg = ComfyUIConfigScript.new()
	cfg.set_token("")
	assert_eq(cfg.get_auth_headers().size(), 0)

func test_get_auth_headers_with_token():
	var cfg = ComfyUIConfigScript.new()
	cfg.set_token("secret")
	var headers = cfg.get_auth_headers()
	assert_eq(headers.size(), 1)
	assert_eq(headers[0], "Authorization: Bearer secret")

func test_save_and_load():
	var cfg = ComfyUIConfigScript.new()
	cfg.set_url("http://custom:8188")
	cfg.set_token("my-token")
	var path = "user://test_comfy.cfg"
	cfg.save_to(path)

	var cfg2 = ComfyUIConfigScript.new()
	cfg2.load_from(path)
	assert_eq(cfg2.get_url(), "http://custom:8188")
	assert_eq(cfg2.get_token(), "my-token")

	DirAccess.remove_absolute(path)

func test_save_and_load_custom_expressions():
	var cfg = ComfyUIConfigScript.new()
	cfg.set_custom_expressions(PackedStringArray(["smile", "surprise"]))
	var path = "user://test_comfy_expr.cfg"
	cfg.save_to(path)
	var cfg2 = ComfyUIConfigScript.new()
	cfg2.load_from(path)
	assert_eq(cfg2.get_custom_expressions().size(), 2)
	assert_eq(cfg2.get_custom_expressions()[0], "smile")
	DirAccess.remove_absolute(path)

func test_negative_prompt():
	var cfg = ComfyUIConfigScript.new()
	cfg.set_negative_prompt("ugly, bad")
	assert_eq(cfg.get_negative_prompt(), "ugly, bad")
