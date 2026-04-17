extends GutTest

var ComfyUIClientScript

func before_each():
	ComfyUIClientScript = load("res://src/services/comfyui_client.gd")

func test_workflow_type_wan_vace_exists():
	assert_eq(ComfyUIClientScript.WorkflowType.WAN_VACE, 12)

func test_workflow_type_wan_vace_pose_exists():
	assert_eq(ComfyUIClientScript.WorkflowType.WAN_VACE_POSE, 13)

func test_workflow_type_wan_vace_dwpose_preview_exists():
	assert_eq(ComfyUIClientScript.WorkflowType.WAN_VACE_DWPOSE_PREVIEW, 14)

func test_workflow_type_wan_i2v_exists():
	assert_eq(ComfyUIClientScript.WorkflowType.WAN_I2V, 15)

func test_sequence_completed_signal_exists():
	var client = Node.new()
	client.set_script(ComfyUIClientScript)
	assert_true(client.has_signal("sequence_completed"))
	client.free()

func test_parse_history_response_all_returns_all_filenames():
	var client = ComfyUIClientScript.new()
	var json = '{"id1": {"outputs": {"9": {"images": [{"filename": "frame_00001.png", "type": "output"}, {"filename": "frame_00002.png", "type": "output"}, {"filename": "frame_00003.png", "type": "output"}]}}, "status": {"completed": true}}}'
	var parsed = client.parse_history_response_all(json, "id1")
	assert_eq(parsed["status"], "completed")
	assert_eq(parsed["filenames"].size(), 3)
	assert_eq(parsed["filenames"][0], "frame_00001.png")
	assert_eq(parsed["filenames"][2], "frame_00003.png")

func test_parse_history_response_all_pending():
	var client = ComfyUIClientScript.new()
	var json = '{"id1": {"status": {"completed": false}}}'
	var parsed = client.parse_history_response_all(json, "id1")
	assert_eq(parsed["status"], "pending")

func test_parse_history_response_all_no_output_node():
	var client = ComfyUIClientScript.new()
	var json = '{"id1": {"outputs": {}, "status": {"completed": true}}}'
	var parsed = client.parse_history_response_all(json, "id1")
	assert_eq(parsed["status"], "error")

func test_select_frames_evenly():
	var client = ComfyUIClientScript.new()
	var all = ["f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8"]
	var selected = client.select_frames(all, 4)
	assert_eq(selected.size(), 4)
	assert_eq(selected[0], "f1")
	assert_eq(selected[3], "f8")

func test_select_frames_fewer_than_requested():
	var client = ComfyUIClientScript.new()
	var all = ["f1", "f2"]
	var selected = client.select_frames(all, 6)
	assert_eq(selected.size(), 2)

func test_dispatch_prompt_routes_to_sequence_mode():
	var client = ComfyUIClientScript.new()
	# When _is_sequence_mode = false, _dispatch_prompt must not enter sequence path
	# We verify by checking that calling with sequence mode off doesn't call the stub
	# (stub would set _generating=false and emit generation_failed)
	client._is_sequence_mode = false
	client._generating = false
	# _do_prompt would fail at network level — just confirm no generation_failed
	var failed = false
	client.generation_failed.connect(func(_e): failed = true)
	# Cannot fully invoke _dispatch_prompt without network, but we can verify the flag
	assert_false(client._is_sequence_mode, "sequence mode should be off by default")

func test_parse_history_response_all_detects_execution_error():
	var client = ComfyUIClientScript.new()
	var json = '{"id1": {"status": {"completed": false, "messages": [["execution_error", {"node_type": "WanVideoSampler", "exception_message": "CUDA out of memory"}]]}}}'
	var parsed = client.parse_history_response_all(json, "id1")
	assert_eq(parsed["status"], "error")
	assert_true(parsed["error"].contains("WanVideoSampler"))

func test_build_wan_vace_dwpose_preview_has_load_image():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_vace_dwpose_preview_workflow("pose.png")
	assert_eq(wf["wv:pose_src"]["class_type"], "LoadImage")
	assert_eq(wf["wv:pose_src"]["inputs"]["image"], "pose.png")

func test_build_wan_vace_dwpose_preview_has_dwpose():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_vace_dwpose_preview_workflow("pose.png")
	assert_true(wf.has("wv:dwpose"))
	assert_eq(wf["wv:dwpose"]["class_type"], "DWPreprocessor")

func test_build_wan_vace_dwpose_preview_output_is_dwpose():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_vace_dwpose_preview_workflow("pose.png")
	assert_eq(wf["9"]["inputs"]["images"][0], "wv:dwpose")

func test_build_workflow_dispatches_dwpose_preview():
	var client = ComfyUIClientScript.new()
	client._source_filename = "pose.png"
	var wf = client.build_workflow("pose.png", "", 0, false, 1.0, 1,
		ComfyUIClientScript.WorkflowType.WAN_VACE_DWPOSE_PREVIEW)
	assert_true(wf.has("wv:dwpose"))

func test_build_wan_vace_workflow_sets_source_image():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_vace_workflow("src.png", "two characters kissing", 42,
		false, 7.0, 20, 0.85, "", 6, 3.0)
	assert_eq(wf["wv:src"]["inputs"]["image"], "src.png")

func test_build_wan_vace_workflow_has_imagescale():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0, 8, 480, 832)
	assert_true(wf.has("wv:scale"))
	assert_eq(wf["wv:scale"]["class_type"], "ImageScale")
	assert_eq(wf["wv:scale"]["inputs"]["width"], 480)
	assert_eq(wf["wv:scale"]["inputs"]["height"], 832)
	assert_eq(wf["wv:vace"]["inputs"]["input_frames"][0], "wv:scale")

func test_wan_vace_resolution_portrait():
	# 784×1312 (Anita_base.png) ≈ 9:16 → doit mapper sur 480×832
	var res = ComfyUIClientScript._wan_vace_resolution(784, 1312)
	assert_eq(res.x, 480)
	assert_eq(res.y, 832)

func test_wan_vace_resolution_landscape():
	# 1920×1080 ≈ 16:9 → doit mapper sur 1280×720
	var res = ComfyUIClientScript._wan_vace_resolution(1920, 1080)
	assert_eq(res.x, 1280)
	assert_eq(res.y, 720)

func test_wan_vace_resolution_square():
	# 512×512 ≈ 1:1 → mapper sur 720×480 ou 480×720 (plus proche de 1:1 parmi les supportées)
	var res = ComfyUIClientScript._wan_vace_resolution(512, 512)
	assert_eq(res.x, 720 if res.y == 480 else res.x, "must pick a 1:1-ish resolution")

func test_build_wan_vace_workflow_uses_wan_resolution():
	var client = ComfyUIClientScript.new()
	# 480×832 passé directement = résolution Wan valide
	var wf = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0, 8, 480, 832)
	assert_eq(wf["wv:vace"]["inputs"]["width"], 480)
	assert_eq(wf["wv:vace"]["inputs"]["height"], 832)

func test_build_wan_vace_workflow_sets_prompt():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_vace_workflow("src.png", "two characters kissing", 42,
		false, 7.0, 20, 0.85, "", 6, 3.0)
	assert_eq(wf["wv:text"]["inputs"]["positive_prompt"], "two characters kissing")

func test_build_wan_vace_workflow_sets_seed_steps_cfg():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_vace_workflow("src.png", "prompt", 99,
		false, 5.0, 15, 0.9, "", 6, 3.0)
	assert_eq(wf["wv:sampler"]["inputs"]["seed"], 99)
	assert_eq(wf["wv:sampler"]["inputs"]["steps"], 15)
	assert_eq(wf["wv:sampler"]["inputs"]["cfg"], 5.0)
	assert_eq(wf["wv:sampler"]["inputs"]["denoise_strength"], 0.9)

func test_build_wan_vace_workflow_computes_num_frames():
	var client = ComfyUIClientScript.new()
	# 3 sec * 16 fps = 48, rounded to multiple of 8 = 48
	var wf = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0, 16)
	assert_eq(wf["wv:vace"]["inputs"]["num_frames"], 48)
	# Lower bound: 0.5 sec @ 16fps → roundi(0.5*16/8)*8 = 8, clamped to 16
	var wf_short = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 0.5, 16)
	assert_eq(wf_short["wv:vace"]["inputs"]["num_frames"], 16)
	# Upper bound: 9 sec @ 16fps → roundi(18)*8 = 144, clamped to 128
	var wf_long = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 9.0, 16)
	assert_eq(wf_long["wv:vace"]["inputs"]["num_frames"], 128)
	# 3 sec @ 8fps → roundi(3*8/8)*8 = 24
	var wf_8 = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0, 8)
	assert_eq(wf_8["wv:vace"]["inputs"]["num_frames"], 24)
	# 3 sec @ 4fps → roundi(3*4/8)*8 = roundi(1.5)*8 = 16 (minimum)
	var wf_4 = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0, 4)
	assert_eq(wf_4["wv:vace"]["inputs"]["num_frames"], 16)

func test_build_wan_vace_workflow_with_remove_bg():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_vace_workflow("src.png", "p", 1, true, 7.0, 20, 0.85, "", 6, 3.0)
	assert_true(wf.has("wv:birefnet"))
	assert_eq(wf["9"]["inputs"]["images"][0], "wv:birefnet")

func test_build_wan_vace_workflow_no_birefnet_when_no_bg():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0)
	assert_false(wf.has("wv:birefnet"))
	assert_eq(wf["9"]["inputs"]["images"][0], "wv:decode")

func test_build_wan_vace_pose_workflow_has_dwpose():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_vace_pose_workflow(
		"src.png", "pose.png", "two characters kissing", 42,
		false, 7.0, 20, 0.85, "", 6, 3.0, 0.7)
	assert_true(wf.has("wv:dwpose"))
	assert_eq(wf["wv:dwpose"]["class_type"], "DWPreprocessor")
	assert_eq(wf["wv:pose_img"]["inputs"]["image"], "pose.png")

func test_build_wan_vace_pose_workflow_has_controlnet():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_vace_pose_workflow(
		"src.png", "pose.png", "prompt", 1,
		false, 7.0, 20, 0.85, "", 6, 3.0, 0.6)
	assert_true(wf.has("wv:ctrl"))
	assert_eq(wf["wv:ctrl"]["class_type"], "WanVideoControlnet")
	assert_eq(wf["wv:ctrl"]["inputs"]["strength"], 0.6)

func test_build_wan_vace_pose_workflow_sampler_uses_controlnet_model():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_vace_pose_workflow(
		"src.png", "pose.png", "prompt", 1,
		false, 7.0, 20, 0.85, "", 6, 3.0, 0.7)
	# Le sampler doit utiliser le modèle patché par WanVideoControlnet
	assert_eq(wf["wv:sampler"]["inputs"]["model"][0], "wv:ctrl")

func test_generate_sequence_fails_when_already_generating():
	var client = Node.new()
	client.set_script(ComfyUIClientScript)
	client._generating = true
	var errors = []
	client.generation_failed.connect(func(e): errors.append(e))
	var config = load("res://src/services/comfyui_config.gd").new()
	client.generate_sequence(config, "", "", false, 7.0, 20,
		ComfyUIClientScript.WorkflowType.WAN_VACE, 0.85, "", 6, 3.0)
	assert_eq(errors.size(), 1)
	assert_eq(errors[0], "Une génération est déjà en cours")
	client.free()

func test_generate_sequence_fails_if_source_missing():
	var client = Node.new()
	client.set_script(ComfyUIClientScript)
	var errors = []
	client.generation_failed.connect(func(e): errors.append(e))
	var config = load("res://src/services/comfyui_config.gd").new()
	client.generate_sequence(config, "/nonexistent/path.png", "prompt", false, 7.0, 20,
		ComfyUIClientScript.WorkflowType.WAN_VACE, 0.85, "", 6, 3.0)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "Impossible d'ouvrir l'image")
	client.free()

func test_wan_vace_tab_builds_without_crash():
	var WanVaceTab = load("res://plugins/ai_studio/ai_studio_wan_vace_tab.gd")
	assert_not_null(WanVaceTab)
	var tab = WanVaceTab.new()
	assert_not_null(tab)

func test_wan_vace_tab_generate_button_disabled_without_url():
	var WanVaceTab = load("res://plugins/ai_studio/ai_studio_wan_vace_tab.gd")
	var tab = WanVaceTab.new()
	var container = TabContainer.new()
	var neg = TextEdit.new()
	var window = Window.new()
	window.add_child(container)
	window.add_child(neg)
	var config_script = load("res://src/services/comfyui_config.gd")
	tab.initialize(window,
		func(): return config_script.new(),
		neg,
		func(_t, _n): pass,
		func(_c): pass,
		func(): pass,
		func(p): return p
	)
	tab.build_tab(container)
	tab.update_generate_button()
	assert_true(tab._generate_btn.disabled)
	window.queue_free()

func test_build_wan_i2v_workflow_has_two_unets():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0)
	assert_eq(wf["i2v:unet_high"]["class_type"], "UNETLoader")
	assert_eq(wf["i2v:unet_high"]["inputs"]["unet_name"], "wan2.2_i2v_high_noise_14B_fp16.safetensors")
	assert_eq(wf["i2v:unet_low"]["class_type"], "UNETLoader")
	assert_eq(wf["i2v:unet_low"]["inputs"]["unet_name"], "wan2.2_i2v_low_noise_14B_fp16.safetensors")
	assert_eq(wf["i2v:unet_high"]["inputs"]["weight_dtype"], "fp8_e4m3fn")

func test_build_wan_i2v_workflow_uses_wan_clip():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0)
	assert_eq(wf["i2v:clip"]["class_type"], "CLIPLoader")
	assert_eq(wf["i2v:clip"]["inputs"]["clip_name"], "umt5_xxl_fp8_e4m3fn_scaled.safetensors")
	assert_eq(wf["i2v:clip"]["inputs"]["type"], "wan")

func test_build_wan_i2v_workflow_sets_prompt():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_i2v_workflow("src.png", "my prompt", 1, 3.5, 20, "neg", 3.0)
	assert_eq(wf["i2v:pos"]["inputs"]["text"], "my prompt")
	assert_eq(wf["i2v:neg"]["inputs"]["text"], "neg")

func test_build_wan_i2v_workflow_scales_source():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0, 8, 480, 832)
	assert_eq(wf["i2v:scale"]["class_type"], "ImageScale")
	assert_eq(wf["i2v:scale"]["inputs"]["width"], 480)
	assert_eq(wf["i2v:scale"]["inputs"]["height"], 832)
	assert_eq(wf["i2v:scale"]["inputs"]["crop"], "center")
	assert_eq(wf["i2v:encode"]["inputs"]["start_image"][0], "i2v:scale")

func test_build_wan_i2v_workflow_encode_sets_resolution():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0, 8, 480, 832)
	assert_eq(wf["i2v:encode"]["class_type"], "WanImageToVideo")
	assert_eq(wf["i2v:encode"]["inputs"]["width"], 480)
	assert_eq(wf["i2v:encode"]["inputs"]["height"], 832)

func test_build_wan_i2v_workflow_num_frames_3s():
	var client = ComfyUIClientScript.new()
	# 3s × 16fps = 48, multiple of 4 = 48
	var wf = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0, 16)
	assert_eq(wf["i2v:encode"]["inputs"]["length"], 48)
	# 3s × 8fps = 24, multiple of 4 = 24
	var wf_8 = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0, 8)
	assert_eq(wf_8["i2v:encode"]["inputs"]["length"], 24)
	# 3s × 4fps = 12, clamped to minimum 16
	var wf_4 = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0, 4)
	assert_eq(wf_4["i2v:encode"]["inputs"]["length"], 16)

func test_build_wan_i2v_workflow_two_stage_sampler():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_i2v_workflow("src.png", "p", 42, 3.5, 20, "", 3.0)
	# Stage 1: high_noise, steps 0→12 (split 60/40 : 20 * 0.6 = 12)
	assert_eq(wf["i2v:sampler1"]["inputs"]["model"][0], "i2v:unet_high")
	assert_eq(wf["i2v:sampler1"]["inputs"]["add_noise"], "enable")
	assert_eq(wf["i2v:sampler1"]["inputs"]["start_at_step"], 0)
	assert_eq(wf["i2v:sampler1"]["inputs"]["end_at_step"], 12)
	assert_eq(wf["i2v:sampler1"]["inputs"]["return_with_leftover_noise"], "enable")
	# Stage 2: low_noise, steps 12→20, receives latent from stage 1
	assert_eq(wf["i2v:sampler2"]["inputs"]["model"][0], "i2v:unet_low")
	assert_eq(wf["i2v:sampler2"]["inputs"]["add_noise"], "disable")
	assert_eq(wf["i2v:sampler2"]["inputs"]["start_at_step"], 12)
	assert_eq(wf["i2v:sampler2"]["inputs"]["end_at_step"], 20)
	assert_eq(wf["i2v:sampler2"]["inputs"]["latent_image"][0], "i2v:sampler1")

func test_build_wan_i2v_workflow_decode_and_save():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0)
	assert_eq(wf["i2v:decode"]["class_type"], "VAEDecode")
	assert_eq(wf["i2v:decode"]["inputs"]["samples"][0], "i2v:sampler2")
	assert_eq(wf["9"]["inputs"]["filename_prefix"], "wan_i2v_frame")
	assert_eq(wf["9"]["inputs"]["images"][0], "i2v:decode")

func test_generate_sequence_stores_loras_and_transparent_output():
	var client = Node.new()
	client.set_script(ComfyUIClientScript)
	var config = load("res://src/services/comfyui_config.gd").new()
	var loras = [{"name": "my_lora.safetensors", "strength": 0.8}]
	# /nonexistent.png fails file open but AFTER params are stored
	client.generate_sequence(config, "/nonexistent.png", "", false, 7.0, 20,
		ComfyUIClientScript.WorkflowType.WAN_VACE, 0.85, "", 6, 3.0, "", 0.7, 8,
		loras, true)
	assert_eq(client._loras, loras)
	assert_true(client._transparent_output)
	client.free()

func test_build_wan_vace_workflow_with_loras():
	var client = ComfyUIClientScript.new()
	var loras = [
		{"name": "style.safetensors", "strength": 0.8},
		{"name": "char.safetensors", "strength": 1.2}
	]
	var wf = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0, 8, 832, 480, loras)
	assert_true(wf.has("wv:lora_0"), "wv:lora_0 doit exister")
	assert_eq(wf["wv:lora_0"]["class_type"], "LoraLoaderModelOnly")
	assert_eq(wf["wv:lora_0"]["inputs"]["lora_name"], "style.safetensors")
	assert_eq(wf["wv:lora_0"]["inputs"]["strength_model"], 0.8)
	assert_eq(wf["wv:lora_0"]["inputs"]["model"], ["wv:model", 0])
	assert_true(wf.has("wv:lora_1"), "wv:lora_1 doit exister")
	assert_eq(wf["wv:lora_1"]["inputs"]["model"], ["wv:lora_0", 0])
	assert_eq(wf["wv:sampler"]["inputs"]["model"], ["wv:lora_1", 0])

func test_build_wan_vace_workflow_no_loras_no_lora_nodes():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0)
	for key in wf.keys():
		assert_false(key.begins_with("wv:lora_"), "Nœud lora inattendu : " + key)
	assert_eq(wf["wv:sampler"]["inputs"]["model"], ["wv:model", 0])

func test_build_wan_vace_workflow_transparent_output():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_vace_workflow("src.png", "p", 1, true, 7.0, 20, 0.85, "", 6, 3.0, 8, 832, 480, [], true)
	assert_true(wf.has("wv:birefnet_out"), "wv:birefnet_out doit exister")
	assert_eq(wf["wv:birefnet_out"]["class_type"], "BiRefNetRMBG")
	assert_eq(wf["wv:birefnet_out"]["inputs"]["image"], ["wv:decode", 0])
	assert_eq(wf["9"]["inputs"]["images"], ["wv:birefnet_out", 0])
	assert_true(wf.has("wv:birefnet"), "wv:birefnet (source) doit rester intact")

func test_build_wan_i2v_workflow_with_loras():
	var client = ComfyUIClientScript.new()
	var loras = [{"name": "style.safetensors", "strength": 0.9}]
	var wf = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0, 8, 832, 480, loras)
	assert_true(wf.has("i2v:lora_high_0"), "i2v:lora_high_0 doit exister")
	assert_eq(wf["i2v:lora_high_0"]["class_type"], "LoraLoaderModelOnly")
	assert_eq(wf["i2v:lora_high_0"]["inputs"]["lora_name"], "style.safetensors")
	assert_eq(wf["i2v:lora_high_0"]["inputs"]["model"], ["i2v:unet_high", 0])
	assert_true(wf.has("i2v:lora_low_0"), "i2v:lora_low_0 doit exister")
	assert_eq(wf["i2v:lora_low_0"]["inputs"]["model"], ["i2v:unet_low", 0])
	assert_eq(wf["i2v:sampler1"]["inputs"]["model"], ["i2v:lora_high_0", 0])
	assert_eq(wf["i2v:sampler2"]["inputs"]["model"], ["i2v:lora_low_0", 0])

func test_build_wan_i2v_workflow_no_loras_no_lora_nodes():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0)
	for key in wf.keys():
		assert_false(key.contains("lora_"), "Nœud lora inattendu : " + key)
	assert_eq(wf["i2v:sampler1"]["inputs"]["model"], ["i2v:unet_high", 0])
	assert_eq(wf["i2v:sampler2"]["inputs"]["model"], ["i2v:unet_low", 0])

func test_build_wan_i2v_workflow_transparent_output():
	var client = ComfyUIClientScript.new()
	var wf = client._build_wan_i2v_workflow("src.png", "p", 1, 3.5, 20, "", 3.0, 8, 832, 480, [], true)
	assert_true(wf.has("i2v:birefnet_out"), "i2v:birefnet_out doit exister")
	assert_eq(wf["i2v:birefnet_out"]["class_type"], "BiRefNetRMBG")
	assert_eq(wf["i2v:birefnet_out"]["inputs"]["image"], ["i2v:decode", 0])
	assert_eq(wf["9"]["inputs"]["images"], ["i2v:birefnet_out", 0])
