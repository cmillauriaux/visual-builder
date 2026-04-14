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
