extends GutTest

# Tests pour la vue graphe des chapitres

var ChapterGraphViewScript
var StoryScript
var ChapterScript

var _view: GraphEdit = null
var _story = null

func before_each():
	ChapterGraphViewScript = load("res://src/views/chapter_graph_view.gd")
	StoryScript = load("res://src/models/story.gd")
	ChapterScript = load("res://src/models/chapter.gd")
	
	_view = GraphEdit.new()
	_view.set_script(ChapterGraphViewScript)
	add_child_autofree(_view)
	_story = StoryScript.new()
	_story.title = "Test"
	_story.author = "Auteur"

func test_load_empty_story():
	_view.load_story(_story)
	assert_eq(_view.get_node_count(), 0)

func test_load_story_with_chapters():
	var ch1 = ChapterScript.new()
	ch1.chapter_name = "Chapitre 1"
	ch1.position = Vector2(100, 200)
	var ch2 = ChapterScript.new()
	ch2.chapter_name = "Chapitre 2"
	ch2.position = Vector2(400, 200)
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_view.load_story(_story)
	assert_eq(_view.get_node_count(), 2)

func test_add_chapter():
	_view.load_story(_story)
	_view.add_new_chapter("Nouveau Chapitre", Vector2(300, 100))
	assert_eq(_story.chapters.size(), 1)
	assert_eq(_story.chapters[0].chapter_name, "Nouveau Chapitre")
	assert_eq(_view.get_node_count(), 1)

func test_remove_chapter():
	var ch = ChapterScript.new()
	ch.chapter_name = "À supprimer"
	_story.chapters.append(ch)
	_view.load_story(_story)
	assert_eq(_view.get_node_count(), 1)
	_view.remove_chapter(ch.uuid)
	assert_eq(_story.chapters.size(), 0)
	assert_eq(_view.get_node_count(), 0)

func test_rename_chapter():
	var ch = ChapterScript.new()
	ch.chapter_name = "Ancien nom"
	_story.chapters.append(ch)
	_view.load_story(_story)
	_view.rename_chapter(ch.uuid, "Nouveau nom")
	assert_eq(_story.chapters[0].chapter_name, "Nouveau nom")

func test_add_connection():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_view.load_story(_story)
	_view.add_story_connection(ch1.uuid, ch2.uuid)
	assert_eq(_story.connections.size(), 1)
	assert_eq(_story.connections[0]["from"], ch1.uuid)
	assert_eq(_story.connections[0]["to"], ch2.uuid)

func test_remove_connection():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_story.connections.append({"from": ch1.uuid, "to": ch2.uuid})
	_view.load_story(_story)
	_view.remove_story_connection(ch1.uuid, ch2.uuid)
	assert_eq(_story.connections.size(), 0)

func test_clear_graph():
	var ch1 = ChapterScript.new()
	_story.chapters.append(ch1)
	_view.load_story(_story)
	assert_eq(_view.get_node_count(), 1)
	_view.clear_graph()
	assert_eq(_view.get_node_count(), 0)

func test_get_chapter_by_uuid():
	var ch = ChapterScript.new()
	_story.chapters.append(ch)
	_view.load_story(_story)
	var found = _view.get_chapter_by_uuid(ch.uuid)
	assert_eq(found, ch)
	assert_null(_view.get_chapter_by_uuid("invalid"))


func test_get_story():
	_view.load_story(_story)
	assert_eq(_view.get_story(), _story)


func test_get_connection_type():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_story.connections.append({"from": ch1.uuid, "to": ch2.uuid})
	_view.load_story(_story)
	assert_eq(_view.get_connection_type(ch1.uuid, ch2.uuid), "transition")


func test_sync_positions_to_model():
	var ch = ChapterScript.new()
	_story.chapters.append(ch)
	_view.load_story(_story)
	_view.sync_positions_to_model()
	pass_test("sync_positions_to_model should not crash")


func test_compute_incoming_color():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_view.load_story(_story)
	_view._connection_type_map[ch1.uuid + "→" + ch2.uuid] = "transition"
	_view._rebuild_color_indices()
	var color = _view._compute_incoming_color(ch2.uuid)
	assert_eq(color, _view.COLOR_TRANSITION)
	_view._connection_type_map[ch1.uuid + "→" + ch2.uuid] = "choice"
	_view._rebuild_color_indices()
	color = _view._compute_incoming_color(ch2.uuid)
	assert_eq(color, _view.COLOR_CHOICE)
	_view._connection_type_map[ch1.uuid + "→" + ch2.uuid] = "both"
	_view._rebuild_color_indices()
	color = _view._compute_incoming_color(ch2.uuid)
	assert_eq(color, _view.COLOR_BOTH)


func test_update_tooltip_empty_hovered_key():
	_view._hovered_key = ""
	_view._update_tooltip(Vector2.ZERO)
	assert_false(_view._tooltip_panel.visible)


func test_update_tooltip_transition():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_view.load_story(_story)
	var key = ch1.uuid + "→" + ch2.uuid
	_view._connection_type_map[key] = "transition"
	_view._hovered_key = key
	_view._update_tooltip(Vector2(50, 50))
	assert_eq(_view._tooltip_label.text, "Transition automatique")


func test_update_tooltip_choice():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_view.load_story(_story)
	var key = ch1.uuid + "→" + ch2.uuid
	_view._connection_type_map[key] = "choice"
	_view._hovered_key = key
	_view._update_tooltip(Vector2(50, 50))
	assert_eq(_view._tooltip_label.text, "Choix du joueur")


func test_update_tooltip_both():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_view.load_story(_story)
	var key = ch1.uuid + "→" + ch2.uuid
	_view._connection_type_map[key] = "both"
	_view._hovered_key = key
	_view._update_tooltip(Vector2(50, 50))
	assert_eq(_view._tooltip_label.text, "Transition et Choix")


func test_canvas_to_screen():
	var result = _view._canvas_to_screen(Vector2(100, 50))
	assert_true(result is Vector2)


func test_is_near_bezier_close():
	assert_true(_view._is_near_bezier(Vector2(150, 100), Vector2(100, 100), Vector2(200, 100)))


func test_is_near_bezier_far():
	assert_false(_view._is_near_bezier(Vector2(150, 500), Vector2(100, 100), Vector2(200, 100)))


func test_get_connection_line_backward():
	var points = _view._get_connection_line(Vector2(200, 100), Vector2(100, 100))
	assert_gt(points.size(), 0)


func test_on_node_double_clicked_emits_signal():
	var ch = ChapterScript.new()
	_story.chapters.append(ch)
	_view.load_story(_story)
	watch_signals(_view)
	_view._on_node_double_clicked(ch.uuid)
	assert_signal_emitted(_view, "chapter_double_clicked")


func test_on_node_rename_requested_emits_signal():
	var ch = ChapterScript.new()
	_story.chapters.append(ch)
	_view.load_story(_story)
	watch_signals(_view)
	_view._on_node_rename_requested(ch.uuid)
	assert_signal_emitted(_view, "chapter_rename_requested")


func test_on_node_delete_requested_emits_signal():
	var ch = ChapterScript.new()
	_story.chapters.append(ch)
	_view.load_story(_story)
	watch_signals(_view)
	_view._on_node_delete_requested(ch.uuid)
	assert_signal_emitted(_view, "chapter_delete_requested")


func test_on_entry_point_toggled_set():
	var ch = ChapterScript.new()
	_story.chapters.append(ch)
	_view.load_story(_story)
	_view._on_entry_point_toggled(ch.uuid, true)
	assert_eq(_story.entry_point_uuid, ch.uuid)


func test_on_entry_point_toggled_unset():
	var ch = ChapterScript.new()
	_story.chapters.append(ch)
	_story.entry_point_uuid = ch.uuid
	_view.load_story(_story)
	_view._on_entry_point_toggled(ch.uuid, false)
	assert_eq(_story.entry_point_uuid, "")


func test_build_connection_map_auto_redirect_chapter():
	var EndingScript = load("res://src/models/ending.gd")
	var ConsequenceScript = load("res://src/models/consequence.gd")
	var SequenceScript = load("res://src/models/sequence.gd")
	var SceneDataScript = load("res://src/models/scene_data.gd")
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	var scene = SceneDataScript.new()
	ch1.scenes.append(scene)
	var seq = SequenceScript.new()
	var ending = EndingScript.new()
	ending.type = "auto_redirect"
	var consequence = ConsequenceScript.new()
	consequence.type = "redirect_chapter"
	consequence.target = ch2.uuid
	ending.auto_consequence = consequence
	seq.ending = ending
	scene.sequences.append(seq)
	_view.load_story(_story)
	assert_eq(_view.get_connection_type(ch1.uuid, ch2.uuid), "transition")


func test_build_connection_map_choice_redirect_chapter():
	var EndingScript = load("res://src/models/ending.gd")
	var ConsequenceScript = load("res://src/models/consequence.gd")
	var ChoiceScript = load("res://src/models/choice.gd")
	var SequenceScript = load("res://src/models/sequence.gd")
	var SceneDataScript = load("res://src/models/scene_data.gd")
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	var scene = SceneDataScript.new()
	ch1.scenes.append(scene)
	var seq = SequenceScript.new()
	var ending = EndingScript.new()
	ending.type = "choices"
	var choice = ChoiceScript.new()
	var consequence = ConsequenceScript.new()
	consequence.type = "redirect_chapter"
	consequence.target = ch2.uuid
	choice.consequence = consequence
	ending.choices.append(choice)
	seq.ending = ending
	scene.sequences.append(seq)
	_view.load_story(_story)
	assert_eq(_view.get_connection_type(ch1.uuid, ch2.uuid), "choice")


func test_build_connection_map_condition_rule_redirect_chapter():
	var ConsequenceScript = load("res://src/models/consequence.gd")
	var ConditionScript = load("res://src/models/condition.gd")
	var ConditionRuleScript = load("res://src/models/condition_rule.gd")
	var SceneDataScript = load("res://src/models/scene_data.gd")
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	var scene = SceneDataScript.new()
	ch1.scenes.append(scene)
	var cond = ConditionScript.new()
	var rule = ConditionRuleScript.new()
	var consequence = ConsequenceScript.new()
	consequence.type = "redirect_chapter"
	consequence.target = ch2.uuid
	rule.consequence = consequence
	cond.rules.append(rule)
	scene.conditions.append(cond)
	_view.load_story(_story)
	assert_eq(_view.get_connection_type(ch1.uuid, ch2.uuid), "transition")


func test_build_connection_map_condition_default_consequence():
	var ConsequenceScript = load("res://src/models/consequence.gd")
	var ConditionScript = load("res://src/models/condition.gd")
	var SceneDataScript = load("res://src/models/scene_data.gd")
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	var scene = SceneDataScript.new()
	ch1.scenes.append(scene)
	var cond = ConditionScript.new()
	var consequence = ConsequenceScript.new()
	consequence.type = "redirect_chapter"
	consequence.target = ch2.uuid
	cond.default_consequence = consequence
	scene.conditions.append(cond)
	_view.load_story(_story)
	assert_eq(_view.get_connection_type(ch1.uuid, ch2.uuid), "transition")


func test_entry_point_switch():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_view.load_story(_story)
	_view._on_entry_point_toggled(ch1.uuid, true)
	assert_eq(_story.entry_point_uuid, ch1.uuid)
	_view._on_entry_point_toggled(ch2.uuid, true)
	assert_eq(_story.entry_point_uuid, ch2.uuid)


# === Tests optimisation : index couleurs O(1) ===

func test_rebuild_color_indices_populates_outgoing_index():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_story.connections.append({"from": ch1.uuid, "to": ch2.uuid})
	_view.load_story(_story)
	assert_true(_view._outgoing_index.has(ch1.uuid))
	assert_true(_view._outgoing_index[ch1.uuid].get("has_transition", false))
	assert_false(_view._outgoing_index[ch1.uuid].get("has_choice", false))


func test_rebuild_color_indices_populates_incoming_index():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_story.connections.append({"from": ch1.uuid, "to": ch2.uuid})
	_view.load_story(_story)
	assert_true(_view._incoming_index.has(ch2.uuid))
	assert_true(_view._incoming_index[ch2.uuid].get("has_transition", false))
	assert_false(_view._incoming_index[ch2.uuid].get("has_choice", false))


func test_color_index_handles_both_type():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_view.load_story(_story)
	# Simuler un type "both" dans la map
	_view._connection_type_map[ch1.uuid + "→" + ch2.uuid] = "both"
	_view._rebuild_color_indices()
	assert_true(_view._outgoing_index[ch1.uuid].get("has_transition", false))
	assert_true(_view._outgoing_index[ch1.uuid].get("has_choice", false))
	assert_true(_view._incoming_index[ch2.uuid].get("has_transition", false))
	assert_true(_view._incoming_index[ch2.uuid].get("has_choice", false))


func test_color_index_cleared_on_clear_graph():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_story.connections.append({"from": ch1.uuid, "to": ch2.uuid})
	_view.load_story(_story)
	assert_false(_view._outgoing_index.is_empty())
	_view.clear_graph()
	assert_true(_view._outgoing_index.is_empty())
	assert_true(_view._incoming_index.is_empty())


func test_color_index_updated_on_add_connection():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_view.load_story(_story)
	assert_false(_view._outgoing_index.has(ch1.uuid))
	_view.add_story_connection(ch1.uuid, ch2.uuid)
	assert_true(_view._outgoing_index.has(ch1.uuid))


func test_color_index_updated_on_remove_connection():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_story.connections.append({"from": ch1.uuid, "to": ch2.uuid})
	_view.load_story(_story)
	assert_true(_view._outgoing_index.has(ch1.uuid))
	_view.remove_story_connection(ch1.uuid, ch2.uuid)
	# L'index est reconstruit : ch1 n'a plus de connexion sortante
	assert_false(_view._outgoing_index.has(ch1.uuid))


func test_compute_outgoing_color_choice_via_index():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_view.load_story(_story)
	_view._connection_type_map[ch1.uuid + "→" + ch2.uuid] = "choice"
	_view._rebuild_color_indices()
	assert_eq(_view._compute_outgoing_color(ch1.uuid), _view.COLOR_CHOICE)


func test_compute_outgoing_color_both_via_index():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_view.load_story(_story)
	_view._connection_type_map[ch1.uuid + "→" + ch2.uuid] = "both"
	_view._rebuild_color_indices()
	assert_eq(_view._compute_outgoing_color(ch1.uuid), _view.COLOR_BOTH)


func test_compute_outgoing_color_no_connection_returns_transition():
	var ch1 = ChapterScript.new()
	_story.chapters.append(ch1)
	_view.load_story(_story)
	# Pas de connexion → couleur par défaut
	assert_eq(_view._compute_outgoing_color(ch1.uuid), _view.COLOR_TRANSITION)


# === Tests optimisation : cache bezier ===

func test_bezier_cache_empty_initially():
	_view.load_story(_story)
	assert_true(_view._bezier_cache.is_empty())


func test_bezier_cache_populated_after_rebuild():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_story.connections.append({"from": ch1.uuid, "to": ch2.uuid})
	_view.load_story(_story)
	# Le cache doit être vide jusqu'à ce que rebuild soit appelé
	assert_true(_view._bezier_cache.is_empty())
	_view._rebuild_bezier_cache_if_stale()
	# Après rebuild, une entrée par connexion
	assert_eq(_view._bezier_cache.size(), _view._connection_type_map.size())


func test_bezier_cache_has_points_per_connection():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_story.connections.append({"from": ch1.uuid, "to": ch2.uuid})
	_view.load_story(_story)
	_view._rebuild_bezier_cache_if_stale()
	var key = ch1.uuid + "→" + ch2.uuid
	assert_true(_view._bezier_cache.has(key))
	assert_gt(_view._bezier_cache[key].size(), 0)


func test_bezier_cache_cleared_on_clear_graph():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_story.connections.append({"from": ch1.uuid, "to": ch2.uuid})
	_view.load_story(_story)
	_view._rebuild_bezier_cache_if_stale()
	assert_false(_view._bezier_cache.is_empty())
	_view.clear_graph()
	assert_true(_view._bezier_cache.is_empty())


func test_bezier_cache_entry_removed_on_remove_connection():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_story.connections.append({"from": ch1.uuid, "to": ch2.uuid})
	_view.load_story(_story)
	_view._rebuild_bezier_cache_if_stale()
	var key = ch1.uuid + "→" + ch2.uuid
	assert_true(_view._bezier_cache.has(key))
	_view.remove_story_connection(ch1.uuid, ch2.uuid)
	assert_false(_view._bezier_cache.has(key))


func test_bezier_cache_rebuilt_on_node_position_change():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_story.connections.append({"from": ch1.uuid, "to": ch2.uuid})
	_view.load_story(_story)
	_view._rebuild_bezier_cache_if_stale()
	var key = ch1.uuid + "→" + ch2.uuid
	var old_points = _view._bezier_cache[key].duplicate()
	# Simuler un déplacement de nœud
	_view._node_map[ch1.uuid].position_offset = Vector2(500, 500)
	_view._rebuild_bezier_cache_if_stale()
	var new_points = _view._bezier_cache[key]
	# Les points doivent avoir changé
	assert_ne(old_points[0], new_points[0])


func test_rebuild_bezier_cache_not_stale_when_same():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_story.connections.append({"from": ch1.uuid, "to": ch2.uuid})
	_view.load_story(_story)
	_view._rebuild_bezier_cache_if_stale()
	var key = ch1.uuid + "→" + ch2.uuid
	var points_ref = _view._bezier_cache[key]
	# Appel répété sans changement → même référence de tableau
	_view._rebuild_bezier_cache_if_stale()
	assert_eq(_view._bezier_cache[key], points_ref)
