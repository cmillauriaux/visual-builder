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

# --- Tests subtitle ---

func test_setup_without_subtitle():
	# ContentLabel doit afficher le nom si pas de sous-titre
	var label = _node.get_node("ContentLabel")
	assert_eq(label.text, "Mon Noeud")
	assert_eq(_node.get_subtitle(), "")

func test_setup_with_subtitle():
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	node.setup("uuid-2", "Chapitre 1", Vector2.ZERO, "La forêt maudite")
	add_child_autofree(node)
	assert_eq(node.get_subtitle(), "La forêt maudite")
	assert_eq(node.title, "Chapitre 1")
	var label = node.get_node("ContentLabel")
	assert_eq(label.text, "La forêt maudite")

func test_set_subtitle():
	_node.set_subtitle("Description")
	assert_eq(_node.get_subtitle(), "Description")
	var label = _node.get_node("ContentLabel")
	assert_eq(label.text, "Description")

func test_set_subtitle_empty_fallback():
	_node.set_subtitle("Quelque chose")
	_node.set_subtitle("")
	var label = _node.get_node("ContentLabel")
	assert_eq(label.text, "Mon Noeud")

func test_set_item_name_preserves_subtitle():
	_node.set_subtitle("Ma description")
	_node.set_item_name("Nouveau titre")
	assert_eq(_node.title, "Nouveau titre")
	var label = _node.get_node("ContentLabel")
	assert_eq(label.text, "Ma description")

func test_set_item_name_and_subtitle():
	_node.set_item_name_and_subtitle("Chapitre 2", "Le donjon")
	assert_eq(_node.get_item_name(), "Chapitre 2")
	assert_eq(_node.get_subtitle(), "Le donjon")
	assert_eq(_node.title, "Chapitre 2")
	var label = _node.get_node("ContentLabel")
	assert_eq(label.text, "Le donjon")

func test_set_item_name_and_subtitle_empty():
	_node.set_item_name_and_subtitle("Chapitre 3", "")
	var label = _node.get_node("ContentLabel")
	assert_eq(label.text, "Chapitre 3")

# --- Tests context menu ---

func test_context_menu_exists():
	assert_true(_node.has_node("ContextMenu"), "Le menu contextuel doit exister")

func test_rename_requested_signal():
	watch_signals(_node)
	_node._on_popup_id_pressed(0)
	assert_signal_emitted(_node, "rename_requested")
