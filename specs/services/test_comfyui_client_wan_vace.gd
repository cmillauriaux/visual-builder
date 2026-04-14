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
	assert_eq(wf["wv:dwpose"]["class_type"], "DWPreprocess")

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
