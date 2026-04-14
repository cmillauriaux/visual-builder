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
