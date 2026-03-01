extends GutTest

const ComfyUIClient = preload("res://src/services/comfyui_client.gd")

var _client: Node

func before_each():
	_client = Node.new()
	_client.set_script(ComfyUIClient)
	add_child_autofree(_client)

# --- build_workflow ---

func test_build_workflow_returns_dictionary():
	var wf = _client.build_workflow("test.png", "a cute cat", 12345)
	assert_typeof(wf, TYPE_DICTIONARY)

func test_build_workflow_contains_required_nodes():
	var wf = _client.build_workflow("test.png", "a cute cat", 42)
	assert_has(wf, "75:73", "Seed node (RandomNoise) must exist")
	assert_has(wf, "75:74", "Prompt node (CLIPTextEncode) must exist")
	assert_has(wf, "76", "Image upload node (LoadImage) must exist")
	assert_has(wf, "100", "BiRefNetRMBG node must exist")
	assert_has(wf, "9", "SaveImage output node must exist")

func test_build_workflow_sets_filename():
	var wf = _client.build_workflow("my_image.png", "prompt", 1)
	# Node 76 is the LoadImage node
	assert_eq(wf["76"]["inputs"]["image"], "my_image.png")

func test_build_workflow_sets_prompt():
	var wf = _client.build_workflow("img.png", "a beautiful hero", 1)
	# Node 75:74 is the CLIPTextEncode for the prompt
	assert_eq(wf["75:74"]["inputs"]["text"], "a beautiful hero")

func test_build_workflow_sets_seed():
	var wf = _client.build_workflow("img.png", "prompt", 99999)
	# Node 75:73 is the RandomNoise with noise_seed
	assert_eq(wf["75:73"]["inputs"]["noise_seed"], 99999)

func test_build_workflow_different_seeds_produce_different_workflows():
	var wf1 = _client.build_workflow("img.png", "prompt", 111)
	var wf2 = _client.build_workflow("img.png", "prompt", 222)
	assert_ne(wf1["75:73"]["inputs"]["noise_seed"], wf2["75:73"]["inputs"]["noise_seed"])

# --- build_workflow without background removal ---

func test_build_workflow_no_remove_bg_excludes_birefnet_node():
	var wf = _client.build_workflow("test.png", "a landscape", 42, false)
	assert_false(wf.has("100"), "BiRefNetRMBG node should not exist when remove_background is false")

func test_build_workflow_no_remove_bg_save_image_points_to_vae_decode():
	var wf = _client.build_workflow("test.png", "a landscape", 42, false)
	assert_eq(wf["9"]["inputs"]["images"], ["75:65", 0], "SaveImage should point directly to VAEDecode output")

func test_build_workflow_with_remove_bg_includes_birefnet_node():
	var wf = _client.build_workflow("test.png", "a cat", 42, true)
	assert_has(wf, "100", "BiRefNetRMBG node should exist when remove_background is true")
	assert_eq(wf["9"]["inputs"]["images"], ["100", 0], "SaveImage should point to BiRefNetRMBG output")

func test_build_workflow_default_includes_birefnet():
	var wf = _client.build_workflow("test.png", "a cat", 42)
	assert_has(wf, "100", "Default should include BiRefNetRMBG node")

# --- build_multipart_body ---

func test_build_multipart_body_returns_array():
	var result = _client.build_multipart_body("test.png", PackedByteArray([0x89, 0x50, 0x4E, 0x47]))
	assert_typeof(result, TYPE_ARRAY)
	assert_eq(result.size(), 2, "Should return [body_bytes, boundary]")

func test_build_multipart_body_contains_filename():
	var result = _client.build_multipart_body("my_file.png", PackedByteArray([1, 2, 3]))
	var body_bytes: PackedByteArray = result[0]
	var body_str = body_bytes.get_string_from_utf8()
	assert_string_contains(body_str, "my_file.png")

func test_build_multipart_body_contains_file_data():
	var file_data = PackedByteArray([0x89, 0x50, 0x4E, 0x47])
	var result = _client.build_multipart_body("test.png", file_data)
	var body_bytes: PackedByteArray = result[0]
	# The file data should be embedded in the body
	var found = false
	for i in range(body_bytes.size() - file_data.size() + 1):
		var is_match = true
		for j in range(file_data.size()):
			if body_bytes[i + j] != file_data[j]:
				is_match = false
				break
		if is_match:
			found = true
			break
	assert_true(found, "File data should be present in multipart body")

func test_build_multipart_body_contains_boundary():
	var result = _client.build_multipart_body("test.png", PackedByteArray([1]))
	var boundary: String = result[1]
	assert_ne(boundary, "", "Boundary should not be empty")
	var body_str = result[0].get_string_from_utf8()
	assert_string_contains(body_str, boundary)

func test_build_multipart_body_contains_content_disposition():
	var result = _client.build_multipart_body("test.png", PackedByteArray([1]))
	var body_str = result[0].get_string_from_utf8()
	assert_string_contains(body_str, "Content-Disposition: form-data")

func test_build_multipart_body_no_subfolder():
	var result = _client.build_multipart_body("test.png", PackedByteArray([1]))
	var body_str = result[0].get_string_from_utf8()
	assert_false(body_str.contains("subfolder"), "Multipart body should not include subfolder")

# --- parse_prompt_response ---

func test_parse_prompt_response_extracts_prompt_id():
	var json_str = '{"prompt_id": "abc-123-def"}'
	var result = _client.parse_prompt_response(json_str)
	assert_eq(result, "abc-123-def")

func test_parse_prompt_response_empty_returns_empty():
	var result = _client.parse_prompt_response("")
	assert_eq(result, "")

func test_parse_prompt_response_invalid_json_returns_empty():
	var result = _client.parse_prompt_response("{invalid")
	assert_eq(result, "")

# --- parse_history_response ---

func test_parse_history_response_not_ready():
	var json_str = '{}'
	var result = _client.parse_history_response(json_str, "prompt-id-1")
	assert_eq(result["status"], "pending")

func test_parse_history_response_completed():
	# Node 9 is SaveImage — the output node in the real workflow
	var json_str = '{"prompt-id-1": {"outputs": {"9": {"images": [{"filename": "result.png", "type": "output"}]}}}}'
	var result = _client.parse_history_response(json_str, "prompt-id-1")
	assert_eq(result["status"], "completed")
	assert_eq(result["filename"], "result.png")

func test_parse_history_response_no_images():
	var json_str = '{"prompt-id-1": {"outputs": {"9": {}}}}'
	var result = _client.parse_history_response(json_str, "prompt-id-1")
	assert_eq(result["status"], "error")

# --- Signals exist ---

func test_has_generation_completed_signal():
	assert_true(_client.has_signal("generation_completed"))

func test_has_generation_failed_signal():
	assert_true(_client.has_signal("generation_failed"))

func test_has_generation_progress_signal():
	assert_true(_client.has_signal("generation_progress"))

# --- State ---

func test_initial_state_not_generating():
	assert_false(_client.is_generating())

func test_cancel_when_not_generating():
	_client.cancel()
	assert_false(_client.is_generating(), "Cancel when idle should remain idle")
