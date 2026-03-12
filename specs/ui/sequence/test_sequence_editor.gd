extends GutTest

var SequenceEditor = load("res://src/ui/sequence/sequence_editor.gd")
var Sequence = load("res://src/models/sequence.gd")
var Dialogue = load("res://src/models/dialogue.gd")
var Foreground = load("res://src/models/foreground.gd")

var _editor: Control = null
var _sequence = null

func before_each():
	_editor = Control.new()
	_editor.set_script(SequenceEditor)
	add_child_autofree(_editor)
	_sequence = Sequence.new()
	_sequence.seq_name = "Test Séquence"
	_sequence.background = "bg.png"

# --- Chargement ---

func test_load_sequence():
	_editor.load_sequence(_sequence)
	assert_eq(_editor.get_sequence(), _sequence)

func test_load_null_sequence():
	_editor.load_sequence(null)
	assert_null(_editor.get_sequence())

# --- Sélection de dialogue ---

func test_no_selection_initially():
	_editor.load_sequence(_sequence)
	assert_eq(_editor.get_selected_dialogue_index(), -1)

func test_select_dialogue():
	_add_dialogue("Héros", "Bonjour")
	_editor.load_sequence(_sequence)
	_editor.select_dialogue(0)
	assert_eq(_editor.get_selected_dialogue_index(), 0)

func test_select_invalid_index():
	_editor.load_sequence(_sequence)
	_editor.select_dialogue(5)
	assert_eq(_editor.get_selected_dialogue_index(), -1)

func test_select_negative_index():
	_add_dialogue("A", "a")
	_editor.load_sequence(_sequence)
	_editor.select_dialogue(0)
	_editor.select_dialogue(-1)
	assert_eq(_editor.get_selected_dialogue_index(), -1)

# --- Héritage des foregrounds ---

func test_effective_foregrounds_empty_dialogue():
	# Premier dialogue sans foreground → vide (background seul)
	_add_dialogue("A", "Premier")
	_editor.load_sequence(_sequence)
	var fgs = _editor.get_effective_foregrounds(0)
	assert_eq(fgs.size(), 0)

func test_effective_foregrounds_with_own():
	var dlg = _add_dialogue("A", "Avec FG")
	var fg = Foreground.new()
	fg.fg_name = "Héros"
	fg.image = "hero.png"
	dlg.foregrounds.append(fg)
	_editor.load_sequence(_sequence)
	var fgs = _editor.get_effective_foregrounds(0)
	assert_eq(fgs.size(), 1)
	assert_eq(fgs[0].fg_name, "Héros")

func test_effective_foregrounds_inherited():
	# Dialogue 0 a des FG, dialogue 1 hérite
	var dlg0 = _add_dialogue("A", "Avec FG")
	var fg = Foreground.new()
	fg.fg_name = "Héros"
	fg.image = "hero.png"
	dlg0.foregrounds.append(fg)
	_add_dialogue("B", "Sans FG")
	_editor.load_sequence(_sequence)
	var fgs = _editor.get_effective_foregrounds(1)
	assert_eq(fgs.size(), 1)
	assert_eq(fgs[0].fg_name, "Héros")

func test_effective_foregrounds_skip_empty():
	# Dialogue 0 a des FG, dialogue 1 vide, dialogue 2 vide → dialogue 2 hérite de 0
	var dlg0 = _add_dialogue("A", "Avec FG")
	var fg = Foreground.new()
	fg.fg_name = "Héros"
	dlg0.foregrounds.append(fg)
	_add_dialogue("B", "Vide")
	_add_dialogue("C", "Vide aussi")
	_editor.load_sequence(_sequence)
	var fgs = _editor.get_effective_foregrounds(2)
	assert_eq(fgs.size(), 1)
	assert_eq(fgs[0].fg_name, "Héros")

func test_effective_foregrounds_first_empty():
	# Aucun dialogue précédent n'a de FG → vide
	_add_dialogue("A", "Vide")
	_add_dialogue("B", "Vide aussi")
	_editor.load_sequence(_sequence)
	var fgs = _editor.get_effective_foregrounds(1)
	assert_eq(fgs.size(), 0)

func test_effective_foregrounds_override():
	# Dialogue 0 a FG "A", dialogue 1 a son propre FG "B" → dialogue 1 utilise "B"
	var dlg0 = _add_dialogue("A", "Texte A")
	var fg_a = Foreground.new()
	fg_a.fg_name = "Perso A"
	dlg0.foregrounds.append(fg_a)
	var dlg1 = _add_dialogue("B", "Texte B")
	var fg_b = Foreground.new()
	fg_b.fg_name = "Perso B"
	dlg1.foregrounds.append(fg_b)
	_editor.load_sequence(_sequence)
	var fgs = _editor.get_effective_foregrounds(1)
	assert_eq(fgs.size(), 1)
	assert_eq(fgs[0].fg_name, "Perso B")

# --- Copie complète ---

func test_ensure_own_foregrounds_copies():
	var dlg0 = _add_dialogue("A", "Avec FG")
	var fg = Foreground.new()
	fg.fg_name = "Héros"
	fg.image = "hero.png"
	fg.transition_type = "fade"
	fg.transition_duration = 1.0
	dlg0.foregrounds.append(fg)
	_add_dialogue("B", "Sans FG")
	_editor.load_sequence(_sequence)
	_editor.ensure_own_foregrounds(1)
	# Dialogue 1 doit maintenant avoir ses propres foregrounds
	assert_eq(_sequence.dialogues[1].foregrounds.size(), 1)
	assert_eq(_sequence.dialogues[1].foregrounds[0].fg_name, "Héros")
	assert_eq(_sequence.dialogues[1].foregrounds[0].transition_type, "fade")
	# UUID doit être préservé (même entité visuelle)
	assert_eq(_sequence.dialogues[1].foregrounds[0].uuid, fg.uuid, "UUID préservé lors de la copie")
	# Vérifier que c'est une copie indépendante (propriétés modifiables séparément)
	_sequence.dialogues[1].foregrounds[0].fg_name = "Modifié"
	assert_eq(dlg0.foregrounds[0].fg_name, "Héros", "Original non modifié")

func test_ensure_own_foregrounds_already_own():
	var dlg = _add_dialogue("A", "Avec FG")
	var fg = Foreground.new()
	fg.fg_name = "Original"
	dlg.foregrounds.append(fg)
	_editor.load_sequence(_sequence)
	_editor.ensure_own_foregrounds(0)
	# Rien ne doit changer
	assert_eq(_sequence.dialogues[0].foregrounds.size(), 1)
	assert_eq(_sequence.dialogues[0].foregrounds[0].fg_name, "Original")

func test_ensure_own_foregrounds_no_inherited():
	# Pas de foreground hérité → la liste reste vide
	_add_dialogue("A", "Vide")
	_editor.load_sequence(_sequence)
	_editor.ensure_own_foregrounds(0)
	assert_eq(_sequence.dialogues[0].foregrounds.size(), 0)

# --- CRUD Dialogues ---

func test_add_dialogue():
	_editor.load_sequence(_sequence)
	_editor.add_dialogue("Héros", "Texte")
	assert_eq(_sequence.dialogues.size(), 1)
	assert_eq(_sequence.dialogues[0].character, "Héros")
	assert_ne(_sequence.dialogues[0].uuid, "")

func test_remove_dialogue():
	_add_dialogue("A", "1")
	_add_dialogue("B", "2")
	_editor.load_sequence(_sequence)
	_editor.select_dialogue(0)
	_editor.remove_dialogue(0)
	assert_eq(_sequence.dialogues.size(), 1)
	assert_eq(_sequence.dialogues[0].character, "B")

func test_remove_selected_resets_selection():
	_add_dialogue("A", "1")
	_editor.load_sequence(_sequence)
	_editor.select_dialogue(0)
	_editor.remove_dialogue(0)
	assert_eq(_editor.get_selected_dialogue_index(), -1)

func test_move_dialogue():
	_add_dialogue("A", "1")
	_add_dialogue("B", "2")
	_add_dialogue("C", "3")
	_editor.load_sequence(_sequence)
	_editor.move_dialogue(2, 0)
	assert_eq(_sequence.dialogues[0].character, "C")
	assert_eq(_sequence.dialogues[1].character, "A")
	assert_eq(_sequence.dialogues[2].character, "B")

func test_modify_dialogue():
	_add_dialogue("A", "Ancien")
	_editor.load_sequence(_sequence)
	_editor.modify_dialogue(0, "B", "Nouveau")
	assert_eq(_sequence.dialogues[0].character, "B")
	assert_eq(_sequence.dialogues[0].text, "Nouveau")

# --- Background ---

func test_set_background():
	_editor.load_sequence(_sequence)
	_editor.set_background("new_bg.png")
	assert_eq(_sequence.background, "new_bg.png")

func test_get_background():
	_editor.load_sequence(_sequence)
	assert_eq(_editor.get_background(), "bg.png")

# --- Mode Play ---

func test_initial_mode_is_edit():
	_editor.load_sequence(_sequence)
	assert_false(_editor.is_playing())

func test_start_play():
	_add_dialogue("A", "Premier")
	_add_dialogue("B", "Deuxième")
	_editor.load_sequence(_sequence)
	_editor.start_play()
	assert_true(_editor.is_playing())
	assert_eq(_editor.get_play_dialogue_index(), 0)

func test_start_play_empty_dialogues():
	_editor.load_sequence(_sequence)
	_editor.start_play()
	assert_false(_editor.is_playing(), "Ne peut pas lancer Play sans dialogues")

func test_advance_play():
	_add_dialogue("A", "Premier")
	_add_dialogue("B", "Deuxième")
	_editor.load_sequence(_sequence)
	_editor.start_play()
	_editor.advance_play()
	assert_eq(_editor.get_play_dialogue_index(), 1)

func test_advance_play_past_last_stops():
	_add_dialogue("A", "Premier")
	_editor.load_sequence(_sequence)
	_editor.start_play()
	_editor.advance_play()
	assert_false(_editor.is_playing(), "Play doit s'arrêter après le dernier dialogue")

func test_stop_play():
	_add_dialogue("A", "Premier")
	_editor.load_sequence(_sequence)
	_editor.start_play()
	_editor.stop_play()
	assert_false(_editor.is_playing())

func test_play_signals_dialogue_changed():
	_add_dialogue("A", "Premier")
	_add_dialogue("B", "Deuxième")
	_editor.load_sequence(_sequence)
	watch_signals(_editor)
	_editor.start_play()
	assert_signal_emitted(_editor, "play_dialogue_changed")

func test_play_signals_stopped():
	_add_dialogue("A", "Premier")
	_editor.load_sequence(_sequence)
	watch_signals(_editor)
	_editor.start_play()
	_editor.stop_play()
	assert_signal_emitted(_editor, "play_stopped")

# --- Typewriter ---

func test_typewriter_initial_state():
	_add_dialogue("A", "Hello")
	_editor.load_sequence(_sequence)
	_editor.start_play()
	assert_false(_editor.is_text_fully_displayed())

func test_typewriter_skip():
	_add_dialogue("A", "Hello World")
	_editor.load_sequence(_sequence)
	_editor.start_play()
	_editor.skip_typewriter()
	assert_true(_editor.is_text_fully_displayed())

func test_typewriter_get_visible_text():
	_add_dialogue("A", "Hello")
	_editor.load_sequence(_sequence)
	_editor.start_play()
	# Au début, le visible_ratio est 0
	assert_eq(_editor.get_visible_characters(), 0)
	_editor.skip_typewriter()
	assert_eq(_editor.get_visible_characters(), 5)

# --- Signaux dialogue_selected ---

func test_dialogue_selected_signal():
	_add_dialogue("A", "Test")
	_editor.load_sequence(_sequence)
	watch_signals(_editor)
	_editor.select_dialogue(0)
	assert_signal_emitted(_editor, "dialogue_selected")

# --- Foreground CRUD sur dialogue ---

func test_add_foreground_to_selected_dialogue():
	_add_dialogue("A", "Test")
	_editor.load_sequence(_sequence)
	_editor.select_dialogue(0)
	_editor.add_foreground_to_current("Perso", "perso.png")
	assert_eq(_sequence.dialogues[0].foregrounds.size(), 1)
	assert_eq(_sequence.dialogues[0].foregrounds[0].fg_name, "Perso")

func test_add_foreground_triggers_copy_if_inherited():
	var dlg0 = _add_dialogue("A", "Avec FG")
	var fg = Foreground.new()
	fg.fg_name = "Héros"
	dlg0.foregrounds.append(fg)
	_add_dialogue("B", "Sans FG")
	_editor.load_sequence(_sequence)
	_editor.select_dialogue(1)
	_editor.add_foreground_to_current("Nouveau", "new.png")
	# Dialogue 1 doit avoir les FG hérités + le nouveau
	assert_eq(_sequence.dialogues[1].foregrounds.size(), 2)

func test_remove_foreground_from_dialogue():
	var dlg = _add_dialogue("A", "Test")
	var fg = Foreground.new()
	fg.fg_name = "Perso"
	dlg.foregrounds.append(fg)
	_editor.load_sequence(_sequence)
	_editor.select_dialogue(0)
	_editor.remove_foreground_from_current(fg.uuid)
	assert_eq(_sequence.dialogues[0].foregrounds.size(), 0)

# --- start_play_at ---

func test_start_play_at_sets_correct_index():
	_add_dialogue("A", "Premier")
	_add_dialogue("B", "Deuxième")
	_add_dialogue("C", "Troisième")
	_editor.load_sequence(_sequence)
	_editor.start_play_at(2)
	assert_true(_editor.is_playing())
	assert_eq(_editor.get_play_dialogue_index(), 2)

func test_start_play_at_emits_play_dialogue_changed():
	_add_dialogue("A", "Premier")
	_add_dialogue("B", "Deuxième")
	_editor.load_sequence(_sequence)
	watch_signals(_editor)
	_editor.start_play_at(1)
	assert_signal_emitted(_editor, "play_dialogue_changed")

func test_start_play_at_clamps_index_when_out_of_bounds():
	_add_dialogue("A", "Premier")
	_add_dialogue("B", "Deuxième")
	_editor.load_sequence(_sequence)
	_editor.start_play_at(99)
	assert_eq(_editor.get_play_dialogue_index(), 1)

func test_start_play_at_clamps_negative_index_to_zero():
	_add_dialogue("A", "Premier")
	_editor.load_sequence(_sequence)
	_editor.start_play_at(-5)
	assert_eq(_editor.get_play_dialogue_index(), 0)

func test_start_play_at_does_nothing_without_sequence():
	_editor.start_play_at(0)
	assert_false(_editor.is_playing())

func test_start_play_at_zero_behaves_like_start_play():
	_add_dialogue("A", "Premier")
	_add_dialogue("B", "Deuxième")
	_editor.load_sequence(_sequence)
	_editor.start_play_at(0)
	assert_true(_editor.is_playing())
	assert_eq(_editor.get_play_dialogue_index(), 0)

# --- Normalisation dialogue foregrounds ---

func test_normalize_clears_dialogue_matching_sequence():
	# Dialogue 0 a les mêmes foregrounds que la séquence → doit être vidé
	var seq_fg = Foreground.new()
	seq_fg.image = "hero.png"
	seq_fg.anchor_bg = Vector2(0.5, 0.5)
	_sequence.foregrounds.append(seq_fg)
	var dlg = _add_dialogue("A", "Texte")
	var dlg_fg = Foreground.new()
	dlg_fg.image = "hero.png"
	dlg_fg.anchor_bg = Vector2(0.5, 0.5)
	dlg.foregrounds.append(dlg_fg)
	_editor.load_sequence(_sequence)
	var cleared = _editor.normalize_dialogue_foregrounds()
	assert_eq(cleared, 1)
	assert_eq(dlg.foregrounds.size(), 0)

func test_normalize_keeps_dialogue_with_different_image():
	var seq_fg = Foreground.new()
	seq_fg.image = "hero.png"
	seq_fg.anchor_bg = Vector2(0.5, 0.5)
	_sequence.foregrounds.append(seq_fg)
	var dlg = _add_dialogue("A", "Texte")
	var dlg_fg = Foreground.new()
	dlg_fg.image = "villain.png"
	dlg_fg.anchor_bg = Vector2(0.5, 0.5)
	dlg.foregrounds.append(dlg_fg)
	_editor.load_sequence(_sequence)
	var cleared = _editor.normalize_dialogue_foregrounds()
	assert_eq(cleared, 0)
	assert_eq(dlg.foregrounds.size(), 1)

func test_normalize_clears_dialogue_matching_previous():
	# Dialogue 1 a les mêmes foregrounds que dialogue 0 → doit être vidé
	var dlg0 = _add_dialogue("A", "Premier")
	var fg0 = Foreground.new()
	fg0.image = "hero.png"
	fg0.anchor_bg = Vector2(0.5, 0.5)
	dlg0.foregrounds.append(fg0)
	var dlg1 = _add_dialogue("B", "Deuxième")
	var fg1 = Foreground.new()
	fg1.image = "hero.png"
	fg1.anchor_bg = Vector2(0.52, 0.48)  # dans le seuil de 5%
	dlg1.foregrounds.append(fg1)
	_editor.load_sequence(_sequence)
	var cleared = _editor.normalize_dialogue_foregrounds()
	assert_eq(cleared, 1)
	assert_eq(dlg1.foregrounds.size(), 0)

func test_normalize_keeps_dialogue_with_different_count():
	var dlg0 = _add_dialogue("A", "Premier")
	var fg0 = Foreground.new()
	fg0.image = "hero.png"
	dlg0.foregrounds.append(fg0)
	var dlg1 = _add_dialogue("B", "Deuxième")
	var fg1a = Foreground.new()
	fg1a.image = "hero.png"
	var fg1b = Foreground.new()
	fg1b.image = "bg.png"
	dlg1.foregrounds.append(fg1a)
	dlg1.foregrounds.append(fg1b)
	_editor.load_sequence(_sequence)
	var cleared = _editor.normalize_dialogue_foregrounds()
	assert_eq(cleared, 0)
	assert_eq(dlg1.foregrounds.size(), 2)

func test_normalize_multiple_dialogues():
	# 3 dialogues identiques → les 2 derniers sont vidés
	var seq_fg = Foreground.new()
	seq_fg.image = "hero.png"
	seq_fg.anchor_bg = Vector2(0.5, 0.5)
	_sequence.foregrounds.append(seq_fg)
	for i in range(3):
		var dlg = _add_dialogue("D%d" % i, "Texte")
		var fg = Foreground.new()
		fg.image = "hero.png"
		fg.anchor_bg = Vector2(0.5, 0.5)
		dlg.foregrounds.append(fg)
	_editor.load_sequence(_sequence)
	var cleared = _editor.normalize_dialogue_foregrounds()
	# Dialogue 0 match la séquence → vidé
	# Dialogue 1 hérite maintenant de la séquence (dlg 0 vidé) → match → vidé
	# Dialogue 2 hérite aussi → match → vidé
	assert_eq(cleared, 3)

func test_normalize_returns_zero_no_dialogues():
	_editor.load_sequence(_sequence)
	var cleared = _editor.normalize_dialogue_foregrounds()
	assert_eq(cleared, 0)

func test_normalize_skips_empty_dialogues():
	_add_dialogue("A", "Vide")
	_add_dialogue("B", "Vide aussi")
	_editor.load_sequence(_sequence)
	var cleared = _editor.normalize_dialogue_foregrounds()
	assert_eq(cleared, 0)

func test_normalize_within_threshold():
	var seq_fg = Foreground.new()
	seq_fg.image = "hero.png"
	seq_fg.anchor_bg = Vector2(0.500, 0.500)
	seq_fg.anchor_fg = Vector2(0.5, 1.0)
	_sequence.foregrounds.append(seq_fg)
	var dlg = _add_dialogue("A", "Texte")
	var dlg_fg = Foreground.new()
	dlg_fg.image = "hero.png"
	dlg_fg.anchor_bg = Vector2(0.540, 0.530)  # dans 5%
	dlg_fg.anchor_fg = Vector2(0.5, 1.0)
	dlg.foregrounds.append(dlg_fg)
	_editor.load_sequence(_sequence)
	var cleared = _editor.normalize_dialogue_foregrounds()
	assert_eq(cleared, 1)

func test_normalize_outside_threshold():
	var seq_fg = Foreground.new()
	seq_fg.image = "hero.png"
	seq_fg.anchor_bg = Vector2(0.500, 0.500)
	_sequence.foregrounds.append(seq_fg)
	var dlg = _add_dialogue("A", "Texte")
	var dlg_fg = Foreground.new()
	dlg_fg.image = "hero.png"
	dlg_fg.anchor_bg = Vector2(0.600, 0.600)  # hors seuil
	dlg.foregrounds.append(dlg_fg)
	_editor.load_sequence(_sequence)
	var cleared = _editor.normalize_dialogue_foregrounds()
	assert_eq(cleared, 0)

# --- Alignement des positions ---

func test_normalize_aligns_same_image_positions():
	# Dialogue a la même image que la séquence mais position légèrement décalée
	var seq_fg = Foreground.new()
	seq_fg.image = "hero.png"
	seq_fg.anchor_bg = Vector2(0.500, 0.500)
	seq_fg.anchor_fg = Vector2(0.5, 1.0)
	_sequence.foregrounds.append(seq_fg)
	var dlg = _add_dialogue("A", "Texte")
	var dlg_fg = Foreground.new()
	dlg_fg.image = "hero_angry.png"  # image différente
	dlg_fg.anchor_bg = Vector2(0.520, 0.510)  # position proche
	dlg_fg.anchor_fg = Vector2(0.5, 1.0)
	dlg.foregrounds.append(dlg_fg)
	_editor.load_sequence(_sequence)
	_editor.normalize_dialogue_foregrounds()
	# La position doit être alignée sur la référence
	assert_almost_eq(dlg_fg.anchor_bg.x, 0.500, 0.001)
	assert_almost_eq(dlg_fg.anchor_bg.y, 0.500, 0.001)

func test_normalize_aligns_different_images_close_positions():
	# Deux personnages différents, positions proches → alignés
	var seq_fg1 = Foreground.new()
	seq_fg1.image = "lucy.png"
	seq_fg1.anchor_bg = Vector2(0.200, 0.800)
	seq_fg1.anchor_fg = Vector2(0.5, 1.0)
	var seq_fg2 = Foreground.new()
	seq_fg2.image = "jessy_tender.png"
	seq_fg2.anchor_bg = Vector2(0.700, 0.800)
	seq_fg2.anchor_fg = Vector2(0.5, 1.0)
	_sequence.foregrounds.append(seq_fg1)
	_sequence.foregrounds.append(seq_fg2)
	var dlg = _add_dialogue("A", "Texte")
	var dlg_fg1 = Foreground.new()
	dlg_fg1.image = "lucy_happy.png"
	dlg_fg1.anchor_bg = Vector2(0.210, 0.805)  # proche de lucy
	dlg_fg1.anchor_fg = Vector2(0.5, 1.0)
	var dlg_fg2 = Foreground.new()
	dlg_fg2.image = "jessy_sad.png"
	dlg_fg2.anchor_bg = Vector2(0.710, 0.795)  # proche de jessy
	dlg_fg2.anchor_fg = Vector2(0.5, 1.0)
	dlg.foregrounds.append(dlg_fg1)
	dlg.foregrounds.append(dlg_fg2)
	_editor.load_sequence(_sequence)
	_editor.normalize_dialogue_foregrounds()
	assert_almost_eq(dlg_fg1.anchor_bg.x, 0.200, 0.001)
	assert_almost_eq(dlg_fg1.anchor_bg.y, 0.800, 0.001)
	assert_almost_eq(dlg_fg2.anchor_bg.x, 0.700, 0.001)
	assert_almost_eq(dlg_fg2.anchor_bg.y, 0.800, 0.001)

func test_normalize_does_not_align_distant_positions():
	var seq_fg = Foreground.new()
	seq_fg.image = "hero.png"
	seq_fg.anchor_bg = Vector2(0.200, 0.200)
	_sequence.foregrounds.append(seq_fg)
	var dlg = _add_dialogue("A", "Texte")
	var dlg_fg = Foreground.new()
	dlg_fg.image = "villain.png"
	dlg_fg.anchor_bg = Vector2(0.800, 0.800)  # très loin
	dlg.foregrounds.append(dlg_fg)
	_editor.load_sequence(_sequence)
	_editor.normalize_dialogue_foregrounds()
	# Position inchangée
	assert_almost_eq(dlg_fg.anchor_bg.x, 0.800, 0.001)
	assert_almost_eq(dlg_fg.anchor_bg.y, 0.800, 0.001)

# --- Helper ---

func _add_dialogue(character: String, text: String):
	var dlg = Dialogue.new()
	dlg.character = character
	dlg.text = text
	_sequence.dialogues.append(dlg)
	return dlg
