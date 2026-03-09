extends GutTest

var ComfyUIClientScript

func before_each():
	ComfyUIClientScript = load("res://src/services/comfyui_client.gd")

func test_build_workflow_creation():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "prompt", 123, true, 1.0, 4, 0)
	assert_eq(wf["76"]["inputs"]["image"], "test.png")
	assert_eq(wf["75:74"]["inputs"]["text"], "prompt")
	assert_eq(wf["75:73"]["inputs"]["noise_seed"], 123)
	assert_true(wf.has("100")) # BiRefNet present

func test_build_workflow_no_bg_removal():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "prompt", 123, false, 1.0, 4, 0)
	assert_false(wf.has("100")) # BiRefNet removed
	assert_eq(wf["9"]["inputs"]["images"][0], "75:65") # Direct output

func test_build_multipart_body():
	var client = ComfyUIClientScript.new()
	var data = PackedByteArray([1, 2, 3])
	var result = client.build_multipart_body("test.png", data)
	assert_eq(result.size(), 2)
	var body = result[0]
	var boundary = result[1]
	assert_true(body.size() > 0)
	assert_string_contains(body.get_string_from_utf8(), boundary)
	assert_string_contains(body.get_string_from_utf8(), "test.png")

func test_parse_prompt_response_valid():
	var client = ComfyUIClientScript.new()
	var prompt_id = client.parse_prompt_response('{"prompt_id": "abc-123"}')
	assert_eq(prompt_id, "abc-123")

func test_parse_prompt_response_invalid():
	var client = ComfyUIClientScript.new()
	var prompt_id = client.parse_prompt_response('{"error": "bad"}')
	assert_eq(prompt_id, "")

func test_parse_history_response_completed():
	var client = ComfyUIClientScript.new()
	var json = '{"id1": {"outputs": {"9": {"images": [{"filename": "out.png"}]}}, "status": {"completed": true}}}'
	var parsed = client.parse_history_response(json, "id1")
	assert_eq(parsed["status"], "completed")
	assert_eq(parsed["filename"], "out.png")

func test_parse_history_response_pending():
	var client = ComfyUIClientScript.new()
	var json = '{"id1": {"status": {"completed": false}}}'
	var parsed = client.parse_history_response(json, "id1")
	assert_eq(parsed["status"], "pending")
