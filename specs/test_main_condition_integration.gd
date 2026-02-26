extends GutTest

const MainScript = preload("res://src/main.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const ConditionScript = preload("res://src/models/condition.gd")
const EditorMainScript = preload("res://src/ui/editor_main.gd")

var _main: Control

func before_each():
	_main = Control.new()
	_main.set_script(MainScript)
	add_child_autofree(_main)

	# Créer une histoire de test
	var story = StoryScript.new()
	story.title = "Test Story"
	var chapter = ChapterScript.new()
	chapter.chapter_name = "Ch1"
	story.chapters.append(chapter)
	var scene = SceneDataScript.new()
	scene.scene_name = "Sc1"
	chapter.scenes.append(scene)
	var seq = SequenceScript.new()
	seq.seq_name = "Seq1"
	seq.position = Vector2(100, 100)
	scene.sequences.append(seq)

	_main._editor_main.open_story(story)
	_main._editor_main.navigate_to_chapter(chapter.uuid)
	_main._editor_main.navigate_to_scene(scene.uuid)
	_main._sequence_graph_view.load_scene(scene)
	_main._update_view()

# --- Bouton création condition ---

func test_create_condition_button_exists():
	assert_not_null(_main._create_condition_button)

func test_create_condition_button_visible_at_sequences_level():
	assert_true(_main._create_condition_button.visible)

func test_create_condition_button_hidden_at_other_levels():
	_main._editor_main.navigate_back()  # → scenes
	_main._update_view()
	assert_false(_main._create_condition_button.visible)

func test_create_condition_button_creates_condition():
	_main._on_create_condition_pressed()
	var scene = _main._editor_main._current_scene
	assert_eq(scene.conditions.size(), 1)
	assert_eq(scene.conditions[0].condition_name, "Condition 1")

# --- Double-clic condition ---

func test_double_click_condition_navigates_to_condition_edit():
	var scene = _main._editor_main._current_scene
	var cond = ConditionScript.new()
	cond.condition_name = "TestCond"
	scene.conditions.append(cond)
	_main._sequence_graph_view.load_scene(scene)

	_main._on_condition_double_clicked(cond.uuid)
	assert_eq(_main._editor_main.get_current_level(), "condition_edit")

func test_condition_editor_visible_in_condition_edit():
	var scene = _main._editor_main._current_scene
	var cond = ConditionScript.new()
	cond.condition_name = "TestCond"
	scene.conditions.append(cond)
	_main._sequence_graph_view.load_scene(scene)

	_main._on_condition_double_clicked(cond.uuid)
	assert_true(_main._condition_editor_panel.visible)
	assert_false(_main._sequence_graph_view.visible)

# --- Breadcrumb ---

func test_breadcrumb_shows_condition_name():
	var scene = _main._editor_main._current_scene
	var cond = ConditionScript.new()
	cond.condition_name = "MyCond"
	scene.conditions.append(cond)
	_main._sequence_graph_view.load_scene(scene)

	_main._on_condition_double_clicked(cond.uuid)
	var path = _main._editor_main.get_breadcrumb_path()
	assert_eq(path[path.size() - 1], "MyCond")

# --- Retour ---

func test_back_from_condition_edit():
	var scene = _main._editor_main._current_scene
	var cond = ConditionScript.new()
	cond.condition_name = "TestCond"
	scene.conditions.append(cond)
	_main._sequence_graph_view.load_scene(scene)

	_main._on_condition_double_clicked(cond.uuid)
	_main._on_back_pressed()
	assert_eq(_main._editor_main.get_current_level(), "sequences")
