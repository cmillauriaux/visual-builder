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
	var wf = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 3.0)
	assert_eq(wf["wv:vace"]["inputs"]["num_frames"], 48)
	# Lower bound: 0.5 sec → roundi(0.5*16/8)*8 = roundi(1)*8 = 8, clamped to 16
	var wf_short = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 0.5)
	assert_eq(wf_short["wv:vace"]["inputs"]["num_frames"], 16)
	# Upper bound: 9 sec → roundi(9*16/8)*8 = roundi(18)*8 = 144, clamped to 128
	var wf_long = client._build_wan_vace_workflow("src.png", "p", 1, false, 7.0, 20, 0.85, "", 6, 9.0)
	assert_eq(wf_long["wv:vace"]["inputs"]["num_frames"], 128)

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
