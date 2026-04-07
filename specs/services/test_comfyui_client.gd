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

func test_build_expression_workflow_default_face_box():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "smile", 123, true, 1.0, 4, 1, 0.5, "", 80)
	assert_eq(wf["100"]["inputs"]["dilation"], 80)
	assert_eq(wf["101"]["inputs"]["expand"], 80)

func test_build_expression_workflow_custom_face_box():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "smile", 123, true, 1.0, 4, 1, 0.5, "", 30)
	assert_eq(wf["100"]["inputs"]["dilation"], 30)
	assert_eq(wf["101"]["inputs"]["expand"], 30)

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

func test_is_generating_default():
	var client = ComfyUIClientScript.new()
	assert_false(client.is_generating())

func test_parse_prompt_response_empty_string():
	var client = ComfyUIClientScript.new()
	var result = client.parse_prompt_response("")
	assert_eq(result, "")

func test_parse_history_response_invalid_json():
	var client = ComfyUIClientScript.new()
	var parsed = client.parse_history_response("not valid json", "id1")
	assert_eq(parsed["status"], "error")

func test_parse_history_response_missing_prompt_id():
	var client = ComfyUIClientScript.new()
	var json = '{"other_id": {}}'
	var parsed = client.parse_history_response(json, "id1")
	assert_eq(parsed["status"], "pending")

func test_parse_history_response_completed_no_outputs():
	var client = ComfyUIClientScript.new()
	var json = '{"id1": {"status": {"completed": true}}}'
	var parsed = client.parse_history_response(json, "id1")
	assert_eq(parsed["status"], "error")

func test_parse_history_response_no_images_in_outputs():
	var client = ComfyUIClientScript.new()
	var json = '{"id1": {"outputs": {"9": {"data": []}}}}'
	var parsed = client.parse_history_response(json, "id1")
	assert_eq(parsed["status"], "error")

func test_build_workflow_creation_with_negative_prompt():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "prompt", 42, true, 1.0, 4, 0, 0.5, "ugly")
	assert_true(wf.has("75:83"))
	assert_eq(wf["75:83"]["inputs"]["text"], "ugly")

func test_generate_already_generating():
	var client = ComfyUIClientScript.new()
	add_child_autofree(client)
	client._generating = true
	watch_signals(client)
	client.generate(null, "", "")
	assert_signal_emitted(client, "generation_failed")

func test_cancel_when_not_generating():
	var client = ComfyUIClientScript.new()
	client._generating = false
	client.cancel()
	assert_true(client._cancelled)

func test_cancel_when_generating():
	var client = ComfyUIClientScript.new()
	add_child_autofree(client)
	client._generating = true
	watch_signals(client)
	client.cancel()
	assert_false(client._generating)
	assert_signal_emitted(client, "generation_progress")

func test_build_expression_workflow_no_bg_removal():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "smile", 42, false, 1.0, 4, 1, 0.5)
	assert_eq(wf["9"]["inputs"]["images"][0], "103")
	assert_false(wf.has("106"))

func test_parse_history_response_execution_error_in_messages():
	var client = ComfyUIClientScript.new()
	var json = JSON.stringify({
		"id1": {
			"status": {
				"completed": false,
				"messages": [
					["execution_error", {"node_type": "KSampler", "exception_message": "cuda error"}]
				]
			}
		}
	})
	var parsed = client.parse_history_response(json, "id1")
	assert_eq(parsed["status"], "error")
	assert_string_contains(parsed["error"], "KSampler")

func test_build_workflow_creation_no_lora_keeps_original_connections():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("t.png", "p", 1, true, 1.0, 4, 0, 0.5, "", 80, 1.0, [])
	assert_false(wf.has("lora_0"))
	assert_eq(wf["75:63"]["inputs"]["model"], ["75:70", 0])
	assert_eq(wf["75:74"]["inputs"]["clip"], ["75:71", 0])

func test_build_workflow_creation_single_lora_injects_node_and_rewires():
	var client = ComfyUIClientScript.new()
	var loras = [{"name": "test.safetensors", "strength": 0.8}]
	var wf = client.build_workflow("t.png", "p", 1, true, 1.0, 4, 0, 0.5, "", 80, 1.0, loras)
	assert_true(wf.has("lora_0"))
	assert_eq(wf["lora_0"]["class_type"], "LoraLoader")
	assert_eq(wf["lora_0"]["inputs"]["lora_name"], "test.safetensors")
	assert_eq(wf["lora_0"]["inputs"]["strength_model"], 0.8)
	assert_eq(wf["lora_0"]["inputs"]["model"], ["75:70", 0])
	assert_eq(wf["lora_0"]["inputs"]["clip"], ["75:71", 0])
	assert_eq(wf["75:63"]["inputs"]["model"], ["lora_0", 0])
	assert_eq(wf["75:74"]["inputs"]["clip"], ["lora_0", 1])

func test_build_workflow_creation_multiple_loras_chain_correctly():
	var client = ComfyUIClientScript.new()
	var loras = [
		{"name": "a.safetensors", "strength": 1.0},
		{"name": "b.safetensors", "strength": 0.5},
	]
	var wf = client.build_workflow("t.png", "p", 1, true, 1.0, 4, 0, 0.5, "", 80, 1.0, loras)
	assert_true(wf.has("lora_0"))
	assert_true(wf.has("lora_1"))
	assert_eq(wf["lora_1"]["inputs"]["model"], ["lora_0", 0])
	assert_eq(wf["lora_1"]["inputs"]["clip"], ["lora_0", 1])
	assert_eq(wf["75:63"]["inputs"]["model"], ["lora_1", 0])
	assert_eq(wf["75:74"]["inputs"]["clip"], ["lora_1", 1])


# --- Blink workflow (BiSeNet face parsing) ---

func test_build_blink_workflow_uses_bisenet():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "blink", 42, true, 1.0, 4, 6, 0.55, "", 15)
	assert_false(wf.has("99"), "YOLO node should be removed")
	assert_false(wf.has("100"), "BboxDetector node should be removed")
	assert_eq(wf["110"]["class_type"], "FaceParsingLoader")
	assert_eq(wf["111"]["class_type"], "FaceParsingInfer")
	assert_eq(wf["112"]["class_type"], "FacePartMask")

func test_build_blink_workflow_default_eyes_only():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "blink", 42, true, 1.0, 4, 6, 0.55, "", 15)
	assert_eq(wf["112"]["inputs"]["num_parts"], 2)
	assert_eq(wf["112"]["inputs"]["part_1"], "l_eye")
	assert_eq(wf["112"]["inputs"]["part_2"], "r_eye")

func test_build_blink_workflow_eyes_and_brows():
	var client = ComfyUIClientScript.new()
	client._eye_zone_mode = "eyes_and_brows"
	var wf = client.build_workflow("test.png", "blink", 42, true, 1.0, 4, 6, 0.55, "", 15)
	assert_eq(wf["112"]["inputs"]["num_parts"], 4)
	assert_eq(wf["112"]["inputs"]["part_3"], "l_brow")
	assert_eq(wf["112"]["inputs"]["part_4"], "r_brow")

func test_build_blink_workflow_mask_rewired():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "blink", 42, true, 1.0, 4, 6, 0.55, "", 15)
	assert_eq(wf["101"]["inputs"]["mask"], ["112", 0])
	assert_eq(wf["101"]["inputs"]["expand"], 15)

func test_build_blink_workflow_has_img2img():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "blink", 42, true, 1.0, 4, 6, 0.55, "", 15)
	assert_true(wf.has("split_sigmas"))
	# latent_image goes through SetLatentNoiseMask, not directly from VAEEncode
	assert_eq(wf["75:64"]["inputs"]["latent_image"], ["set_noise_mask", 0])

func test_build_blink_workflow_has_noise_mask():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "blink", 42, true, 1.0, 4, 6, 0.55, "", 15)
	assert_true(wf.has("set_noise_mask"))
	assert_eq(wf["set_noise_mask"]["class_type"], "SetLatentNoiseMask")
	assert_eq(wf["set_noise_mask"]["inputs"]["samples"], ["75:79:78", 0])
	assert_eq(wf["set_noise_mask"]["inputs"]["mask"], ["102", 0])

func test_build_blink_workflow_blur_proportional():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "blink", 42, true, 1.0, 4, 6, 0.55, "", 15)
	var kernel = wf["102"]["inputs"]["kernel_size"]
	assert_true(kernel >= 11, "kernel should be >= 11")
	assert_eq(kernel % 2, 1, "kernel should be odd")

func test_build_blink_workflow_preserves_original_alpha():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "blink", 42, true, 1.0, 4, 6, 0.55, "", 15)
	# BiRefNet never used — alpha comes from original image
	assert_false(wf.has("106"))
	assert_true(wf.has("join_alpha"))
	assert_eq(wf["join_alpha"]["class_type"], "JoinImageWithAlpha")
	assert_eq(wf["join_alpha"]["inputs"]["image"], ["103", 0])
	assert_eq(wf["join_alpha"]["inputs"]["alpha"], ["76", 1])
	assert_eq(wf["9"]["inputs"]["images"], ["join_alpha", 0])


# --- Inpaint workflow (mask-based inpainting) ---

func test_build_mask_bytes_returns_png_with_correct_dimensions():
	var client = ComfyUIClientScript.new()
	var bytes = client.build_mask_bytes(Rect2i(10, 10, 20, 20), 50, 40)
	assert_true(bytes.size() > 0)
	var img = Image.new()
	assert_eq(img.load_png_from_buffer(bytes), OK)
	assert_eq(img.get_width(), 50)
	assert_eq(img.get_height(), 40)

func test_build_mask_bytes_white_inside_rect():
	var client = ComfyUIClientScript.new()
	var bytes = client.build_mask_bytes(Rect2i(10, 10, 20, 20), 50, 50)
	var img = Image.new()
	img.load_png_from_buffer(bytes)
	# Centre du rectangle : (20, 20) → blanc
	var center = img.get_pixel(20, 20)
	assert_almost_eq(center.r, 1.0, 0.01)

func test_build_mask_bytes_black_outside_rect():
	var client = ComfyUIClientScript.new()
	var bytes = client.build_mask_bytes(Rect2i(10, 10, 20, 20), 50, 50)
	var img = Image.new()
	img.load_png_from_buffer(bytes)
	# Coin haut-gauche (0,0) → noir
	var corner = img.get_pixel(0, 0)
	assert_almost_eq(corner.r, 0.0, 0.01)

func test_build_mask_bytes_empty_rect_returns_all_black():
	var client = ComfyUIClientScript.new()
	var bytes = client.build_mask_bytes(Rect2i(0, 0, 0, 0), 10, 10)
	var img = Image.new()
	img.load_png_from_buffer(bytes)
	var px = img.get_pixel(5, 5)
	assert_almost_eq(px.r, 0.0, 0.01)

func test_build_inpaint_workflow_has_mask_loader():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask_test.png"
	client._mask_feather = 15
	var wf = client.build_workflow("src.png", "test", 42, true, 1.0, 4, 7, 0.5, "", 80, 1.0, [])
	assert_true(wf.has("ip:mask"), "ip:mask node absent")
	assert_eq(wf["ip:mask"]["inputs"]["image"], "mask_test.png")

func test_build_inpaint_workflow_has_set_noise_mask():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	var wf = client.build_workflow("src.png", "test", 42, true, 1.0, 4, 7, 0.5, "", 80, 1.0, [])
	assert_true(wf.has("set_noise_mask"), "set_noise_mask absent")
	assert_eq(wf["set_noise_mask"]["inputs"]["samples"][0], "75:79:78")

func test_build_inpaint_workflow_has_split_sigmas():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 10
	var wf = client.build_workflow("src.png", "test", 42, true, 1.0, 4, 7, 0.5, "", 80, 1.0, [])
	assert_true(wf.has("split_sigmas"), "split_sigmas absent")

func test_build_inpaint_workflow_no_face_detection():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 10
	var wf = client.build_workflow("src.png", "test", 42, true, 1.0, 4, 7, 0.5, "", 80, 1.0, [])
	assert_false(wf.has("99"), "Nœud 99 (face detector) présent mais ne devrait pas l'être")
	assert_false(wf.has("100"), "Nœud 100 (bbox detector) présent mais ne devrait pas l'être")

func test_build_inpaint_workflow_no_feather_removes_blur():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 0
	var wf = client.build_workflow("src.png", "test", 42, true, 1.0, 4, 7, 0.5, "", 80, 1.0, [])
	assert_false(wf.has("102"), "Nœud 102 (blur) présent alors que feather=0")
	assert_eq(wf["103"]["inputs"]["mask"][0], "101")

func test_build_inpaint_workflow_with_feather_has_blur():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 20
	var wf = client.build_workflow("src.png", "test", 42, true, 1.0, 4, 7, 0.5, "", 80, 1.0, [])
	assert_true(wf.has("102"), "Nœud 102 (blur) absent alors que feather=20")
	assert_eq(wf["103"]["inputs"]["mask"][0], "102")

func test_build_inpaint_workflow_no_bg_removal():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 10
	var wf = client.build_workflow("src.png", "test", 42, false, 1.0, 4, 7, 0.5, "", 80, 1.0, [])
	assert_false(wf.has("106"), "106 (BiRefNet) présent mais remove_background=false")
	assert_eq(wf["9"]["inputs"]["images"][0], "103")

func test_build_inpaint_workflow_has_mask_convert():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 10
	var wf = client.build_workflow("src.png", "test", 42, true, 1.0, 4, 7, 0.5, "", 80, 1.0, [])
	assert_true(wf.has("ip:mask_convert"), "ip:mask_convert node absent")
	assert_eq(wf["ip:mask_convert"]["class_type"], "ImageToMask")
	assert_eq(wf["ip:mask_convert"]["inputs"]["channel"], "red")
