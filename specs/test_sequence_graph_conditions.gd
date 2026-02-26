extends GutTest

const SequenceGraphViewScript = preload("res://src/views/sequence_graph_view.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const ConditionScript = preload("res://src/models/condition.gd")
const ConditionRuleScript = preload("res://src/models/condition_rule.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")
const EndingScript = preload("res://src/models/ending.gd")

var _graph: GraphEdit
var _scene_data: Object

func before_each():
	_graph = GraphEdit.new()
	_graph.set_script(SequenceGraphViewScript)
	add_child_autofree(_graph)

	_scene_data = SceneDataScript.new()
	var seq = SequenceScript.new()
	seq.seq_name = "Seq1"
	seq.position = Vector2(100, 100)
	_scene_data.sequences.append(seq)

# --- Ajout de conditions ---

func test_add_new_condition():
	_graph.load_scene(_scene_data)
	_graph.add_new_condition("Condition 1", Vector2(300, 100))
	assert_eq(_scene_data.conditions.size(), 1)
	assert_eq(_scene_data.conditions[0].condition_name, "Condition 1")

func test_add_new_condition_creates_node():
	_graph.load_scene(_scene_data)
	_graph.add_new_condition("Cond1", Vector2(300, 100))
	assert_eq(_graph.get_node_count(), 2)  # 1 seq + 1 cond

func test_condition_node_in_node_map():
	_graph.load_scene(_scene_data)
	_graph.add_new_condition("C1", Vector2(200, 200))
	var cond = _scene_data.conditions[0]
	assert_true(_graph._node_map.has(cond.uuid))

# --- Chargement avec conditions ---

func test_load_scene_with_conditions():
	var cond = ConditionScript.new()
	cond.condition_name = "Cond1"
	cond.position = Vector2(400, 200)
	_scene_data.conditions.append(cond)

	_graph.load_scene(_scene_data)
	assert_eq(_graph.get_node_count(), 2)
	assert_true(_graph._node_map.has(cond.uuid))

# --- Suppression ---

func test_remove_condition():
	var cond = ConditionScript.new()
	cond.condition_name = "To Delete"
	_scene_data.conditions.append(cond)
	_graph.load_scene(_scene_data)

	_graph.remove_condition(cond.uuid)
	assert_eq(_scene_data.conditions.size(), 0)
	assert_false(_graph._node_map.has(cond.uuid))

func test_remove_condition_removes_connections():
	var cond = ConditionScript.new()
	_scene_data.conditions.append(cond)
	var seq = _scene_data.sequences[0]
	_scene_data.connections.append({"from": seq.uuid, "to": cond.uuid})
	_graph.load_scene(_scene_data)

	_graph.remove_condition(cond.uuid)
	assert_eq(_scene_data.connections.size(), 0)

# --- Renommage ---

func test_rename_condition():
	var cond = ConditionScript.new()
	cond.condition_name = "Old"
	_scene_data.conditions.append(cond)
	_graph.load_scene(_scene_data)

	_graph.rename_condition(cond.uuid, "New", "sub")
	assert_eq(cond.condition_name, "New")
	assert_eq(cond.subtitle, "sub")

# --- Connexions dynamiques ---

func test_condition_rules_generate_connections():
	var seq1 = _scene_data.sequences[0]
	var seq2 = SequenceScript.new()
	seq2.seq_name = "Seq2"
	_scene_data.sequences.append(seq2)

	var cond = ConditionScript.new()
	var rule = ConditionRuleScript.new()
	rule.variable = "score"
	rule.operator = "greater_than"
	rule.value = "50"
	var cons = ConsequenceScript.new()
	cons.type = "redirect_sequence"
	cons.target = seq1.uuid
	rule.consequence = cons
	cond.rules.append(rule)

	var def_cons = ConsequenceScript.new()
	def_cons.type = "redirect_sequence"
	def_cons.target = seq2.uuid
	cond.default_consequence = def_cons

	_scene_data.conditions.append(cond)
	_graph.load_scene(_scene_data)

	# Vérifier les connexions
	assert_eq(_graph.get_connection_type(cond.uuid, seq1.uuid), "condition")
	assert_eq(_graph.get_connection_type(cond.uuid, seq2.uuid), "condition")

func test_condition_connection_color():
	# Vérifier que COLOR_CONDITION existe
	assert_true(SequenceGraphViewScript.COLOR_CONDITION is Color)

# --- Sync positions ---

func test_sync_positions_includes_conditions():
	var cond = ConditionScript.new()
	cond.position = Vector2(100, 100)
	_scene_data.conditions.append(cond)
	_graph.load_scene(_scene_data)

	# Déplacer le nœud
	if _graph._node_map.has(cond.uuid):
		_graph._node_map[cond.uuid].position_offset = Vector2(500, 300)

	_graph.sync_positions_to_model()
	assert_eq(cond.position, Vector2(500, 300))

# --- Signal double-clic ---

func test_condition_double_click_emits_signal():
	var cond = ConditionScript.new()
	cond.condition_name = "Click Me"
	_scene_data.conditions.append(cond)
	_graph.load_scene(_scene_data)

	watch_signals(_graph)
	_graph._on_condition_double_clicked(cond.uuid)
	assert_signal_emitted(_graph, "condition_double_clicked")

# --- Distinction visuelle ---

func test_condition_node_is_marked():
	var cond = ConditionScript.new()
	_scene_data.conditions.append(cond)
	_graph.load_scene(_scene_data)
	var node = _graph._node_map[cond.uuid]
	assert_true(_graph._condition_uuids.has(cond.uuid))
