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

func test_build_inpaint_fill_workflow_has_ksampler():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_true(wf.has("3"), "KSampler absent")
	assert_eq(wf["3"]["class_type"], "KSampler")


func test_build_inpaint_fill_workflow_uses_flux_fill_model():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_true(wf.has("31"), "UNETLoader absent")
	assert_eq(wf["31"]["inputs"]["unet_name"], "flux1-fill-dev.safetensors")


func test_build_inpaint_fill_workflow_has_inpaint_model_conditioning():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_true(wf.has("38"), "InpaintModelConditioning absent")
	assert_eq(wf["38"]["class_type"], "InpaintModelConditioning")


func test_build_inpaint_fill_workflow_no_image_pad():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_false(wf.has("44"), "ImagePadForOutpaint présent (doit être absent)")


func test_build_inpaint_fill_workflow_sets_denoise():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 0.75, "", 0, 1.0, [])
	assert_eq(wf["3"]["inputs"]["denoise"], 0.75)


func test_build_inpaint_fill_workflow_has_mask_loader():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask_test.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_true(wf.has("ip:mask"), "ip:mask absent")
	assert_eq(wf["ip:mask"]["inputs"]["image"], "mask_test.png")


func test_build_inpaint_fill_workflow_has_mask_convert():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_true(wf.has("ip:mask_convert"), "ip:mask_convert absent")
	assert_eq(wf["ip:mask_convert"]["class_type"], "ImageToMask")
	assert_eq(wf["ip:mask_convert"]["inputs"]["channel"], "red")


func test_build_inpaint_fill_workflow_no_feather_removes_blur():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 0
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_false(wf.has("ip:blur"), "ip:blur présent alors que feather=0")
	assert_false(wf.has("ip:grow"), "ip:grow présent alors que feather=0")
	assert_eq(wf["38"]["inputs"]["mask"][0], "ip:mask_convert")


func test_build_inpaint_fill_workflow_with_feather_has_blur():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 20
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "", 0, 1.0, [])
	assert_true(wf.has("ip:blur"), "ip:blur absent alors que feather=20")
	assert_eq(wf["38"]["inputs"]["mask"][0], "ip:blur")


func test_build_inpaint_fill_workflow_negative_prompt():
	var client = ComfyUIClientScript.new()
	client._mask_filename = "mask.png"
	client._mask_feather = 15
	client._inpaint_guidance = 30.0
	var wf = client.build_workflow("src.png", "test", 42, false, 0.7, 20, ComfyUIClientScript.WorkflowType.INPAINT, 1.0, "bad quality", 0, 1.0, [])
	assert_true(wf.has("47"), "CLIPTextEncode négatif absent")
	assert_eq(wf["47"]["inputs"]["text"], "bad quality")
	assert_eq(wf["38"]["inputs"]["negative"], ["47", 0])
	assert_false(wf.has("46"), "ConditioningZeroOut doit être effacé")


# --- _inject_loras_create ---

func test_inject_loras_create_empty_loras():
	# Empty loras list → no lora nodes added, workflow unchanged
	var client = ComfyUIClientScript.new()
	var wf = {
		"ckpt": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "test.safetensors"}},
		"guider": {"class_type": "CFGGuider", "inputs": {"model": ["ckpt", 0], "positive": ["clip_text", 0], "negative": ["neg_cond", 0], "cfg": 1.0}},
		"clip_text": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["ckpt", 1]}}
	}
	client._inject_loras_create(wf, [], "ckpt", "guider", "clip_text")
	assert_false(wf.has("clora_0"))
	assert_eq(wf["guider"]["inputs"]["model"], ["ckpt", 0])
	assert_eq(wf["clip_text"]["inputs"]["clip"], ["ckpt", 1])

func test_inject_loras_create_single_lora():
	# One lora → creates clora_0 node, updates model_out_node.model and clip_out_node.clip
	var client = ComfyUIClientScript.new()
	var wf = {
		"ckpt": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "test.safetensors"}},
		"guider": {"class_type": "CFGGuider", "inputs": {"model": ["ckpt", 0], "positive": ["clip_text", 0], "negative": ["neg_cond", 0], "cfg": 1.0}},
		"clip_text": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["ckpt", 1]}}
	}
	client._inject_loras_create(wf, [{"name": "my_lora.safetensors", "strength": 0.8}], "ckpt", "guider", "clip_text")
	assert_true(wf.has("clora_0"))
	assert_eq(wf["clora_0"]["class_type"], "LoraLoader")
	assert_eq(wf["clora_0"]["inputs"]["lora_name"], "my_lora.safetensors")
	assert_eq(wf["clora_0"]["inputs"]["strength_model"], 0.8)
	assert_eq(wf["clora_0"]["inputs"]["model"], ["ckpt", 0])
	assert_eq(wf["clora_0"]["inputs"]["clip"], ["ckpt", 1])
	assert_eq(wf["guider"]["inputs"]["model"], ["clora_0", 0])
	assert_eq(wf["clip_text"]["inputs"]["clip"], ["clora_0", 1])

func test_inject_loras_create_multiple_loras():
	# Two loras → clora_0 feeds into clora_1
	var client = ComfyUIClientScript.new()
	var wf = {
		"ckpt": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "test.safetensors"}},
		"guider": {"class_type": "CFGGuider", "inputs": {"model": ["ckpt", 0], "positive": ["clip_text", 0], "negative": ["neg_cond", 0], "cfg": 1.0}},
		"clip_text": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["ckpt", 1]}}
	}
	var loras = [
		{"name": "lora_a.safetensors", "strength": 0.7},
		{"name": "lora_b.safetensors", "strength": 0.5}
	]
	client._inject_loras_create(wf, loras, "ckpt", "guider", "clip_text")
	assert_true(wf.has("clora_0"))
	assert_true(wf.has("clora_1"))
	assert_eq(wf["clora_0"]["inputs"]["model"], ["ckpt", 0])
	assert_eq(wf["clora_1"]["inputs"]["model"], ["clora_0", 0])
	assert_eq(wf["clora_1"]["inputs"]["clip"], ["clora_0", 1])
	assert_eq(wf["guider"]["inputs"]["model"], ["clora_1", 0])
	assert_eq(wf["clip_text"]["inputs"]["clip"], ["clora_1", 1])


# --- _build_create_flux_workflow ---

func test_build_create_flux_workflow_structure():
	var client = ComfyUIClientScript.new()
	var wf = client._build_create_flux_workflow("test prompt", "", "my_model.safetensors", [], 20, 3.5, 1.0, 12345)
	assert_true(wf.has("9"))  # SaveImage
	assert_true(wf.has("ckpt"))
	assert_true(wf.has("latent"))
	assert_true(wf.has("sampler"))
	assert_true(wf.has("noise"))
	assert_true(wf.has("clip_text"))
	assert_eq(wf["ckpt"]["class_type"], "CheckpointLoaderSimple")
	assert_eq(wf["latent"]["class_type"], "EmptyFlux2LatentImage")

func test_build_create_flux_workflow_params():
	var client = ComfyUIClientScript.new()
	var wf = client._build_create_flux_workflow("my prompt", "", "flux_model.safetensors", [], 25, 4.0, 1.0, 99999)
	assert_eq(wf["ckpt"]["inputs"]["ckpt_name"], "flux_model.safetensors")
	assert_eq(wf["clip_text"]["inputs"]["text"], "my prompt")
	assert_eq(wf["noise"]["inputs"]["noise_seed"], 99999)
	assert_eq(wf["scheduler"]["inputs"]["steps"], 25)
	assert_eq(wf["guider"]["inputs"]["cfg"], 4.0)

func test_build_create_flux_workflow_size_from_megapixels():
	var client = ComfyUIClientScript.new()
	var wf = client._build_create_flux_workflow("prompt", "", "model.safetensors", [], 20, 1.0, 1.0, 0)
	var w = wf["latent"]["inputs"]["width"]
	var h = wf["latent"]["inputs"]["height"]
	assert_true(w > 0)
	assert_true(h > 0)
	assert_eq(w % 64, 0)  # Must be multiple of 64
	assert_eq(h % 64, 0)
	# For 1MP: approx 1024x1024
	assert_gt(w, 512)
	assert_gt(h, 512)


# --- _build_illustrious_workflow ---

func test_build_illustrious_workflow_structure():
	var client = ComfyUIClientScript.new()
	var wf = client._build_illustrious_workflow("test", "negative", "illust.safetensors", [], 20, 7.0, 1.0, 42)
	assert_true(wf.has("9"))  # SaveImage
	assert_true(wf.has("ckpt"))
	assert_true(wf.has("latent"))
	assert_true(wf.has("ksampler"))
	assert_true(wf.has("pos"))
	assert_true(wf.has("neg"))
	assert_eq(wf["ckpt"]["class_type"], "CheckpointLoaderSimple")
	assert_eq(wf["latent"]["class_type"], "EmptyLatentImage")
	assert_eq(wf["ksampler"]["class_type"], "KSampler")

func test_build_illustrious_workflow_params():
	var client = ComfyUIClientScript.new()
	var wf = client._build_illustrious_workflow("positive prompt", "negative prompt", "sdxl.safetensors", [], 30, 7.5, 1.0, 777)
	assert_eq(wf["ckpt"]["inputs"]["ckpt_name"], "sdxl.safetensors")
	assert_eq(wf["pos"]["inputs"]["text"], "positive prompt")
	assert_eq(wf["neg"]["inputs"]["text"], "negative prompt")
	assert_eq(wf["ksampler"]["inputs"]["seed"], 777)
	assert_eq(wf["ksampler"]["inputs"]["steps"], 30)
	assert_eq(wf["ksampler"]["inputs"]["cfg"], 7.5)

func test_build_create_flux_workflow_with_lora_and_negative_prompt():
	# When loras provided AND negative_prompt non-empty, both must use the final lora's clip output
	var client = ComfyUIClientScript.new()
	var loras = [{"name": "test_lora.safetensors", "strength": 0.8}]
	var wf = client._build_create_flux_workflow("positive", "negative text", "model.safetensors", loras, 20, 3.5, 1.0, 0)
	assert_true(wf.has("clora_0"))
	# The negative text node's clip must point to the last lora output, not the original checkpoint
	var neg_nodes = []
	for key in wf.keys():
		if wf[key].get("class_type", "") == "CLIPTextEncode" and wf[key]["inputs"].get("text", "") == "negative text":
			neg_nodes.append(key)
	assert_eq(neg_nodes.size(), 1, "Must have exactly one negative CLIPTextEncode")
	var neg_node = neg_nodes[0]
	assert_eq(wf[neg_node]["inputs"]["clip"], ["clora_0", 1], "Negative clip must use last lora clip output")

func test_build_illustrious_workflow_with_lora_and_negative_prompt():
	# When loras provided, neg.clip must use the final lora's clip output
	var client = ComfyUIClientScript.new()
	var loras = [{"name": "test_lora.safetensors", "strength": 0.9}]
	var wf = client._build_illustrious_workflow("positive", "negative text", "model.safetensors", loras, 20, 7.0, 1.0, 0)
	assert_true(wf.has("clora_0"))
	assert_eq(wf["neg"]["inputs"]["clip"], ["clora_0", 1], "neg.clip must use last lora clip output")
	assert_eq(wf["pos"]["inputs"]["clip"], ["clora_0", 1], "pos.clip must use last lora clip output")

# --- Assembler workflow (img2img sans YOLO) ---

func test_build_assembler_workflow_no_yolo_nodes():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "tilt head", 42, true, 3.0, 4,
		ComfyUIClientScript.WorkflowType.ASSEMBLER, 0.5)
	assert_false(wf.has("99"), "UltralyticsDetectorProvider doit être absent")
	assert_false(wf.has("100"), "BboxDetectorCombined doit être absent")
	assert_false(wf.has("101"), "GrowMask doit être absent")
	assert_false(wf.has("102"), "ImpactGaussianBlurMask doit être absent")
	assert_false(wf.has("103"), "ImageCompositeMasked doit être absent")

func test_build_assembler_workflow_is_img2img():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "tilt head", 42, true, 3.0, 4,
		ComfyUIClientScript.WorkflowType.ASSEMBLER, 0.5)
	assert_eq(wf["75:64"]["inputs"]["latent_image"], ["75:79:78", 0])
	assert_false(wf.has("75:66"))

func test_build_assembler_workflow_has_split_sigmas():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "tilt head", 42, true, 3.0, 4,
		ComfyUIClientScript.WorkflowType.ASSEMBLER, 0.5)
	assert_true(wf.has("split_sigmas"))
	assert_eq(wf["split_sigmas"]["class_type"], "SplitSigmas")
	assert_eq(wf["75:64"]["inputs"]["sigmas"], ["split_sigmas", 1])

func test_build_assembler_workflow_split_sigmas_step_from_denoise():
	# denoise=0.5, steps=4 → split_step = max(1, round(4 * (1.0 - 0.5))) = 2
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "p", 1, true, 3.0, 4,
		ComfyUIClientScript.WorkflowType.ASSEMBLER, 0.5)
	assert_eq(wf["split_sigmas"]["inputs"]["step"], 2)

func test_build_assembler_workflow_split_sigmas_high_denoise():
	# denoise=1.0, steps=4 → split_step = max(1, round(4 * 0.0)) = max(1,0) = 1
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "p", 1, true, 3.0, 4,
		ComfyUIClientScript.WorkflowType.ASSEMBLER, 1.0)
	assert_eq(wf["split_sigmas"]["inputs"]["step"], 1)

func test_build_assembler_workflow_birefnet_wired_to_vaedecode():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "tilt head", 42, true, 3.0, 4,
		ComfyUIClientScript.WorkflowType.ASSEMBLER, 0.5)
	assert_true(wf.has("106"))
	assert_eq(wf["106"]["inputs"]["image"], ["75:65", 0])
	assert_eq(wf["9"]["inputs"]["images"], ["106", 0])

func test_build_assembler_workflow_no_bg_removal():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "tilt head", 42, false, 3.0, 4,
		ComfyUIClientScript.WorkflowType.ASSEMBLER, 0.5)
	assert_false(wf.has("106"))
	assert_eq(wf["9"]["inputs"]["images"], ["75:65", 0])

func test_build_assembler_workflow_sets_image_and_prompt():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("src.png", "change head tilt", 99, true, 3.0, 4,
		ComfyUIClientScript.WorkflowType.ASSEMBLER, 0.5)
	assert_eq(wf["76"]["inputs"]["image"], "src.png")
	assert_eq(wf["75:74"]["inputs"]["text"], "change head tilt")
	assert_eq(wf["75:73"]["inputs"]["noise_seed"], 99)

func test_build_assembler_workflow_sets_cfg_and_steps():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("t.png", "p", 1, true, 4.0, 6,
		ComfyUIClientScript.WorkflowType.ASSEMBLER, 0.5)
	assert_eq(wf["75:63"]["inputs"]["cfg"], 4.0)
	assert_eq(wf["75:62"]["inputs"]["steps"], 6)
