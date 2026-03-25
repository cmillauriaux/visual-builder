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

func test_build_workflow_upscale():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "prompt", 42, true, 1.0, 4, 2, 0.5)
	assert_true(wf.has("1"))
	assert_eq(wf["1"]["inputs"]["image"], "test.png")
	assert_eq(wf["13"]["inputs"]["text"], "prompt")
	assert_eq(wf["20"]["inputs"]["seed"], 42)

func test_build_workflow_upscale_with_negative_prompt():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("test.png", "prompt", 42, true, 1.0, 4, 2, 0.5, "ugly")
	assert_true(wf.has("75:83"))
	assert_eq(wf["75:83"]["inputs"]["text"], "ugly")
	assert_false(wf.has("14"))

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

func test_workflow_type_hires_exists():
	var client = ComfyUIClientScript.new()
	# WorkflowType.HIRES doit valoir 3
	assert_eq(client.WorkflowType.HIRES, 3)

func test_build_workflow_hires_uses_source_as_latent():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("img.png", "high quality", 42, true, 7.0, 25, 3, 0.3, "")
	# L'image source doit être chargée
	assert_eq(wf["76"]["inputs"]["image"], "img.png")
	# Le prompt doit être appliqué
	assert_eq(wf["75:74"]["inputs"]["text"], "high quality")
	# Le seed doit être appliqué
	assert_eq(wf["75:73"]["inputs"]["noise_seed"], 42)
	# CFG appliqué
	assert_eq(wf["75:63"]["inputs"]["cfg"], 7.0)
	# SplitSigmas présent (denoise control)
	assert_true(wf.has("split_sigmas"))
	# L'encodage latent de la source est utilisé (img2img)
	assert_eq(wf["75:64"]["inputs"]["latent_image"], ["75:79:78", 0])
	# Pas de détection de visage
	assert_false(wf.has("99"))
	assert_false(wf.has("100"))
	# SaveImage pointe directement sur VAEDecode (pas de BiRefNet)
	assert_eq(wf["9"]["inputs"]["images"], ["75:65", 0])

func test_build_workflow_hires_denoise_controls_split_step():
	var client = ComfyUIClientScript.new()
	# denoise=0.3, steps=25 → split_step = max(1, round(25 * (1-0.3))) = max(1, 18) = 18
	var wf = client.build_workflow("img.png", "", 0, true, 7.0, 25, 3, 0.3, "")
	assert_eq(wf["split_sigmas"]["inputs"]["step"], 18)

func test_build_workflow_hires_negative_prompt_applied():
	var client = ComfyUIClientScript.new()
	var wf = client.build_workflow("img.png", "sharp", 0, true, 7.0, 25, 3, 0.3, "blurry")
	# Le negative prompt crée un noeud CLIPTextEncode supplémentaire
	assert_true(wf.has("75:83"))
	assert_eq(wf["75:83"]["inputs"]["text"], "blurry")

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
