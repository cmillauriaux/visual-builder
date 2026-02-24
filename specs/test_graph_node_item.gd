extends GutTest

# Tests pour le noeud de graphe réutilisable

const GraphNodeItem = preload("res://src/views/graph_node_item.gd")

var _node: GraphNode = null

func before_each():
	_node = GraphNode.new()
	_node.set_script(GraphNodeItem)
	_node.setup("test-uuid", "Mon Noeud", Vector2(100, 200))
	add_child_autofree(_node)

func test_setup():
	assert_eq(_node.get_item_uuid(), "test-uuid")
	assert_eq(_node.get_item_name(), "Mon Noeud")

func test_position():
	assert_eq(_node.position_offset, Vector2(100, 200))

func test_set_item_name():
	_node.set_item_name("Nouveau nom")
	assert_eq(_node.get_item_name(), "Nouveau nom")
	assert_eq(_node.title, "Nouveau nom")

func test_get_position():
	_node.position_offset = Vector2(300, 400)
	assert_eq(_node.get_item_position(), Vector2(300, 400))

func test_has_input_output_slots():
	# Le noeud doit avoir au moins un port d'entrée et un port de sortie
	assert_true(_node.is_slot_enabled_left(0), "Le port d'entrée doit être actif")
	assert_true(_node.is_slot_enabled_right(0), "Le port de sortie doit être actif")
