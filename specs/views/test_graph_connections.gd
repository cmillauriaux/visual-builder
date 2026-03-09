extends GutTest

var GraphConnectionsScript

func before_each():
	GraphConnectionsScript = load("res://src/views/graph_connections.gd")

func test_get_connection_type_from_name():
	var helper = GraphConnectionsScript
	assert_eq(helper.get_connection_type_from_name("chapter_"), "chapter")
	assert_eq(helper.get_connection_type_from_name("scene_"), "scene")
	assert_eq(helper.get_connection_type_from_name("seq_"), "sequence")
	assert_eq(helper.get_connection_type_from_name("cond_"), "condition")
	assert_eq(helper.get_connection_type_from_name("end_"), "ending")

func test_get_connection_type_unknown():
	var helper = GraphConnectionsScript
	assert_eq(helper.get_connection_type_from_name("unknown_"), "unknown")
	assert_eq(helper.get_connection_type_from_name("test"), "test")
