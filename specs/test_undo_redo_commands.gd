extends GutTest

## Tests des 13 commandes undo/redo.
## Les commandes manipulent uniquement les modèles de données.

const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const ConditionScript = preload("res://src/models/condition.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")

const AddChapterCommand = preload("res://src/commands/add_chapter_command.gd")
const RemoveChapterCommand = preload("res://src/commands/remove_chapter_command.gd")
const AddSceneCommand = preload("res://src/commands/add_scene_command.gd")
const RemoveSceneCommand = preload("res://src/commands/remove_scene_command.gd")
const AddSequenceCommand = preload("res://src/commands/add_sequence_command.gd")
const RemoveSequenceCommand = preload("res://src/commands/remove_sequence_command.gd")
const AddConditionCommand = preload("res://src/commands/add_condition_command.gd")
const RemoveConditionCommand = preload("res://src/commands/remove_condition_command.gd")
const RenameNodeCommand = preload("res://src/commands/rename_node_command.gd")
const MoveNodeCommand = preload("res://src/commands/move_node_command.gd")
const AddDialogueCommand = preload("res://src/commands/add_dialogue_command.gd")
const RemoveDialogueCommand = preload("res://src/commands/remove_dialogue_command.gd")
const EditDialogueCommand = preload("res://src/commands/edit_dialogue_command.gd")

var _story
var _chapter
var _scene
var _sequence

func before_each() -> void:
	_story = StoryScript.new()
	_chapter = ChapterScript.new()
	_chapter.chapter_name = "Chapitre Test"
	_chapter.position = Vector2(100, 100)
	_scene = SceneDataScript.new()
	_scene.scene_name = "Scène Test"
	_scene.position = Vector2(200, 200)
	_sequence = SequenceScript.new()
	_sequence.seq_name = "Séquence Test"
	_sequence.position = Vector2(300, 300)


# =============================================================================
# AddChapterCommand
# =============================================================================

func test_add_chapter_execute_adds_to_story() -> void:
	var cmd = AddChapterCommand.new(_story, "Nouveau Chapitre", Vector2(100, 100))
	cmd.execute()
	assert_eq(_story.chapters.size(), 1)
	assert_eq(_story.chapters[0].chapter_name, "Nouveau Chapitre")

func test_add_chapter_undo_removes_from_story() -> void:
	var cmd = AddChapterCommand.new(_story, "Nouveau Chapitre", Vector2(100, 100))
	cmd.execute()
	cmd.undo()
	assert_eq(_story.chapters.size(), 0)

func test_add_chapter_label() -> void:
	var cmd = AddChapterCommand.new(_story, "Mon Chapitre", Vector2.ZERO)
	assert_eq(cmd.get_label(), "Ajout chapitre \"Mon Chapitre\"")

func test_add_chapter_position_set() -> void:
	var cmd = AddChapterCommand.new(_story, "Ch", Vector2(42, 99))
	cmd.execute()
	assert_eq(_story.chapters[0].position, Vector2(42, 99))


# =============================================================================
# RemoveChapterCommand
# =============================================================================

func test_remove_chapter_execute_removes_from_story() -> void:
	_story.chapters.append(_chapter)
	var cmd = RemoveChapterCommand.new(_story, _chapter)
	cmd.execute()
	assert_eq(_story.chapters.size(), 0)

func test_remove_chapter_undo_restores_chapter() -> void:
	_story.chapters.append(_chapter)
	var cmd = RemoveChapterCommand.new(_story, _chapter)
	cmd.execute()
	cmd.undo()
	assert_eq(_story.chapters.size(), 1)
	assert_eq(_story.chapters[0].uuid, _chapter.uuid)

func test_remove_chapter_undo_restores_at_original_index() -> void:
	var ch2 = ChapterScript.new()
	ch2.chapter_name = "Ch2"
	_story.chapters.append(_chapter)
	_story.chapters.append(ch2)
	var cmd = RemoveChapterCommand.new(_story, _chapter)
	cmd.execute()
	cmd.undo()
	assert_eq(_story.chapters[0].uuid, _chapter.uuid)

func test_remove_chapter_label() -> void:
	var cmd = RemoveChapterCommand.new(_story, _chapter)
	assert_eq(cmd.get_label(), "Suppression chapitre \"Chapitre Test\"")


# =============================================================================
# AddSceneCommand
# =============================================================================

func test_add_scene_execute_adds_to_chapter() -> void:
	var cmd = AddSceneCommand.new(_chapter, "Nouvelle Scène", Vector2(50, 50))
	cmd.execute()
	assert_eq(_chapter.scenes.size(), 1)
	assert_eq(_chapter.scenes[0].scene_name, "Nouvelle Scène")

func test_add_scene_undo_removes_from_chapter() -> void:
	var cmd = AddSceneCommand.new(_chapter, "Nouvelle Scène", Vector2.ZERO)
	cmd.execute()
	cmd.undo()
	assert_eq(_chapter.scenes.size(), 0)

func test_add_scene_label() -> void:
	var cmd = AddSceneCommand.new(_chapter, "Ma Scène", Vector2.ZERO)
	assert_eq(cmd.get_label(), "Ajout scène \"Ma Scène\"")


# =============================================================================
# RemoveSceneCommand
# =============================================================================

func test_remove_scene_execute_removes_from_chapter() -> void:
	_chapter.scenes.append(_scene)
	var cmd = RemoveSceneCommand.new(_chapter, _scene)
	cmd.execute()
	assert_eq(_chapter.scenes.size(), 0)

func test_remove_scene_undo_restores_scene() -> void:
	_chapter.scenes.append(_scene)
	var cmd = RemoveSceneCommand.new(_chapter, _scene)
	cmd.execute()
	cmd.undo()
	assert_eq(_chapter.scenes.size(), 1)
	assert_eq(_chapter.scenes[0].uuid, _scene.uuid)

func test_remove_scene_label() -> void:
	var cmd = RemoveSceneCommand.new(_chapter, _scene)
	assert_eq(cmd.get_label(), "Suppression scène \"Scène Test\"")


# =============================================================================
# AddSequenceCommand
# =============================================================================

func test_add_sequence_execute_adds_to_scene() -> void:
	var cmd = AddSequenceCommand.new(_scene, "Nouvelle Séquence", Vector2(10, 10))
	cmd.execute()
	assert_eq(_scene.sequences.size(), 1)
	assert_eq(_scene.sequences[0].seq_name, "Nouvelle Séquence")

func test_add_sequence_undo_removes_from_scene() -> void:
	var cmd = AddSequenceCommand.new(_scene, "Nouvelle Séquence", Vector2.ZERO)
	cmd.execute()
	cmd.undo()
	assert_eq(_scene.sequences.size(), 0)

func test_add_sequence_label() -> void:
	var cmd = AddSequenceCommand.new(_scene, "Ma Seq", Vector2.ZERO)
	assert_eq(cmd.get_label(), "Ajout séquence \"Ma Seq\"")


# =============================================================================
# RemoveSequenceCommand
# =============================================================================

func test_remove_sequence_execute_removes_from_scene() -> void:
	_scene.sequences.append(_sequence)
	var cmd = RemoveSequenceCommand.new(_scene, _sequence)
	cmd.execute()
	assert_eq(_scene.sequences.size(), 0)

func test_remove_sequence_undo_restores_sequence() -> void:
	_scene.sequences.append(_sequence)
	var cmd = RemoveSequenceCommand.new(_scene, _sequence)
	cmd.execute()
	cmd.undo()
	assert_eq(_scene.sequences.size(), 1)
	assert_eq(_scene.sequences[0].uuid, _sequence.uuid)

func test_remove_sequence_label() -> void:
	var cmd = RemoveSequenceCommand.new(_scene, _sequence)
	assert_eq(cmd.get_label(), "Suppression séquence \"Séquence Test\"")


# =============================================================================
# AddConditionCommand
# =============================================================================

func test_add_condition_execute_adds_to_scene() -> void:
	var cmd = AddConditionCommand.new(_scene, "Nouvelle Condition", Vector2(5, 5))
	cmd.execute()
	assert_eq(_scene.conditions.size(), 1)
	assert_eq(_scene.conditions[0].condition_name, "Nouvelle Condition")

func test_add_condition_undo_removes_from_scene() -> void:
	var cmd = AddConditionCommand.new(_scene, "Nouvelle Condition", Vector2.ZERO)
	cmd.execute()
	cmd.undo()
	assert_eq(_scene.conditions.size(), 0)

func test_add_condition_label() -> void:
	var cmd = AddConditionCommand.new(_scene, "Ma Cond", Vector2.ZERO)
	assert_eq(cmd.get_label(), "Ajout condition \"Ma Cond\"")


# =============================================================================
# RemoveConditionCommand
# =============================================================================

func test_remove_condition_execute_removes_from_scene() -> void:
	var cond = ConditionScript.new()
	cond.condition_name = "Cond Test"
	_scene.conditions.append(cond)
	var cmd = RemoveConditionCommand.new(_scene, cond)
	cmd.execute()
	assert_eq(_scene.conditions.size(), 0)

func test_remove_condition_undo_restores_condition() -> void:
	var cond = ConditionScript.new()
	cond.condition_name = "Cond Test"
	_scene.conditions.append(cond)
	var cmd = RemoveConditionCommand.new(_scene, cond)
	cmd.execute()
	cmd.undo()
	assert_eq(_scene.conditions.size(), 1)
	assert_eq(_scene.conditions[0].uuid, cond.uuid)

func test_remove_condition_label() -> void:
	var cond = ConditionScript.new()
	cond.condition_name = "Ma Cond"
	var cmd = RemoveConditionCommand.new(_scene, cond)
	assert_eq(cmd.get_label(), "Suppression condition \"Ma Cond\"")


# =============================================================================
# RenameNodeCommand
# =============================================================================

func test_rename_node_execute_renames() -> void:
	_chapter.chapter_name = "Ancien Nom"
	var cmd = RenameNodeCommand.new(
		func(n, s): _chapter.chapter_name = n; _chapter.subtitle = s,
		func(): return [_chapter.chapter_name, _chapter.subtitle],
		"Nouveau Nom", "Nouveau Subtitle",
		"Ancien Nom", "",
		"chapitre"
	)
	cmd.execute()
	assert_eq(_chapter.chapter_name, "Nouveau Nom")
	assert_eq(_chapter.subtitle, "Nouveau Subtitle")

func test_rename_node_undo_restores_old_name() -> void:
	_chapter.chapter_name = "Ancien Nom"
	_chapter.subtitle = "Ancien Sub"
	var cmd = RenameNodeCommand.new(
		func(n, s): _chapter.chapter_name = n; _chapter.subtitle = s,
		func(): return [_chapter.chapter_name, _chapter.subtitle],
		"Nouveau Nom", "Nouveau Sub",
		"Ancien Nom", "Ancien Sub",
		"chapitre"
	)
	cmd.execute()
	cmd.undo()
	assert_eq(_chapter.chapter_name, "Ancien Nom")
	assert_eq(_chapter.subtitle, "Ancien Sub")

func test_rename_node_label() -> void:
	var cmd = RenameNodeCommand.new(
		func(_n, _s): pass,
		func(): return ["", ""],
		"Nouveau", "", "Ancien", "",
		"scène"
	)
	assert_eq(cmd.get_label(), "Renommage scène en \"Nouveau\"")


# =============================================================================
# MoveNodeCommand
# =============================================================================

func test_move_node_execute_sets_new_position() -> void:
	_chapter.position = Vector2(10, 10)
	var cmd = MoveNodeCommand.new(
		func(p): _chapter.position = p,
		Vector2(10, 10),
		Vector2(200, 300)
	)
	cmd.execute()
	assert_eq(_chapter.position, Vector2(200, 300))

func test_move_node_undo_restores_old_position() -> void:
	_chapter.position = Vector2(10, 10)
	var cmd = MoveNodeCommand.new(
		func(p): _chapter.position = p,
		Vector2(10, 10),
		Vector2(200, 300)
	)
	cmd.execute()
	cmd.undo()
	assert_eq(_chapter.position, Vector2(10, 10))

func test_move_node_label() -> void:
	var cmd = MoveNodeCommand.new(func(_p): pass, Vector2.ZERO, Vector2(100, 100))
	assert_eq(cmd.get_label(), "Déplacement nœud")


# =============================================================================
# AddDialogueCommand
# =============================================================================

func test_add_dialogue_execute_adds_to_sequence() -> void:
	var cmd = AddDialogueCommand.new(_sequence, "Narrateur", "Bonjour !")
	cmd.execute()
	assert_eq(_sequence.dialogues.size(), 1)
	assert_eq(_sequence.dialogues[0].character, "Narrateur")
	assert_eq(_sequence.dialogues[0].text, "Bonjour !")

func test_add_dialogue_undo_removes_from_sequence() -> void:
	var cmd = AddDialogueCommand.new(_sequence, "Narrateur", "Bonjour !")
	cmd.execute()
	cmd.undo()
	assert_eq(_sequence.dialogues.size(), 0)

func test_add_dialogue_label() -> void:
	var cmd = AddDialogueCommand.new(_sequence, "Perso", "Texte")
	assert_eq(cmd.get_label(), "Ajout dialogue")


# =============================================================================
# RemoveDialogueCommand
# =============================================================================

func test_remove_dialogue_execute_removes_from_sequence() -> void:
	var dlg = DialogueScript.new()
	dlg.character = "Perso"
	dlg.text = "Texte"
	_sequence.dialogues.append(dlg)
	var cmd = RemoveDialogueCommand.new(_sequence, 0)
	cmd.execute()
	assert_eq(_sequence.dialogues.size(), 0)

func test_remove_dialogue_undo_restores_dialogue() -> void:
	var dlg = DialogueScript.new()
	dlg.character = "Perso"
	dlg.text = "Texte"
	_sequence.dialogues.append(dlg)
	var cmd = RemoveDialogueCommand.new(_sequence, 0)
	cmd.execute()
	cmd.undo()
	assert_eq(_sequence.dialogues.size(), 1)
	assert_eq(_sequence.dialogues[0].uuid, dlg.uuid)

func test_remove_dialogue_undo_restores_at_original_index() -> void:
	var dlg0 = DialogueScript.new()
	var dlg1 = DialogueScript.new()
	dlg0.text = "A"
	dlg1.text = "B"
	_sequence.dialogues.append(dlg0)
	_sequence.dialogues.append(dlg1)
	var cmd = RemoveDialogueCommand.new(_sequence, 0)
	cmd.execute()
	cmd.undo()
	assert_eq(_sequence.dialogues[0].uuid, dlg0.uuid)
	assert_eq(_sequence.dialogues[1].uuid, dlg1.uuid)

func test_remove_dialogue_label() -> void:
	var dlg = DialogueScript.new()
	_sequence.dialogues.append(dlg)
	var cmd = RemoveDialogueCommand.new(_sequence, 0)
	assert_eq(cmd.get_label(), "Suppression dialogue")


# =============================================================================
# EditDialogueCommand
# =============================================================================

func test_edit_dialogue_execute_changes_text_and_character() -> void:
	var dlg = DialogueScript.new()
	dlg.character = "Ancien Perso"
	dlg.text = "Ancien Texte"
	_sequence.dialogues.append(dlg)
	var cmd = EditDialogueCommand.new(dlg, "Nouveau Perso", "Nouveau Texte", "Ancien Perso", "Ancien Texte")
	cmd.execute()
	assert_eq(dlg.character, "Nouveau Perso")
	assert_eq(dlg.text, "Nouveau Texte")

func test_edit_dialogue_undo_restores_old_values() -> void:
	var dlg = DialogueScript.new()
	dlg.character = "Ancien Perso"
	dlg.text = "Ancien Texte"
	var cmd = EditDialogueCommand.new(dlg, "Nouveau Perso", "Nouveau Texte", "Ancien Perso", "Ancien Texte")
	cmd.execute()
	cmd.undo()
	assert_eq(dlg.character, "Ancien Perso")
	assert_eq(dlg.text, "Ancien Texte")

func test_edit_dialogue_label() -> void:
	var dlg = DialogueScript.new()
	var cmd = EditDialogueCommand.new(dlg, "N", "T", "O", "OT")
	assert_eq(cmd.get_label(), "Modification dialogue")
