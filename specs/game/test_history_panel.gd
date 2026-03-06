extends GutTest

## Tests pour la fonctionnalité Historique des dialogues (spec 058).
## Couvre :
##  - Accumulation des dialogues dans _dialogue_history
##  - Réinitialisation de l'historique à cleanup
##  - format_history_entry() (logique d'affichage pure)
##  - toggle open/close de l'état _history_open
##  - État du bouton (disabled/enabled) selon la lecture
##  - Texte du bouton selon l'état ouvert/fermé

const GamePlayControllerScript = preload("res://src/controllers/game_play_controller.gd")


# ---------------------------------------------------------------------------
# format_history_entry() — logique pure d'affichage
# ---------------------------------------------------------------------------

func test_format_entry_with_character() -> void:
	var result = GamePlayControllerScript.format_history_entry("Alice", "Bonjour !")
	assert_eq(result, "Alice : Bonjour !", "doit préfixer avec le nom du personnage")


func test_format_entry_without_character() -> void:
	var result = GamePlayControllerScript.format_history_entry("", "Un texte narratif.")
	assert_eq(result, "Un texte narratif.", "sans personnage, juste le texte")


func test_format_entry_empty_text() -> void:
	var result = GamePlayControllerScript.format_history_entry("Bob", "")
	assert_eq(result, "Bob : ", "personnage sans texte")


func test_format_entry_both_empty() -> void:
	var result = GamePlayControllerScript.format_history_entry("", "")
	assert_eq(result, "", "tout vide → chaîne vide")


# ---------------------------------------------------------------------------
# _dialogue_history — accumulation
# ---------------------------------------------------------------------------

func test_history_empty_at_start() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	assert_eq(ctrl._dialogue_history.size(), 0, "historique vide au démarrage")


func test_add_history_entry_appends() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	ctrl.add_history_entry("Alice", "Bonjour")
	assert_eq(ctrl._dialogue_history.size(), 1)
	assert_eq(ctrl._dialogue_history[0]["character"], "Alice")
	assert_eq(ctrl._dialogue_history[0]["text"], "Bonjour")


func test_add_multiple_entries_keeps_order() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	ctrl.add_history_entry("A", "premier")
	ctrl.add_history_entry("B", "deuxième")
	ctrl.add_history_entry("C", "troisième")
	assert_eq(ctrl._dialogue_history.size(), 3)
	assert_eq(ctrl._dialogue_history[0]["text"], "premier")
	assert_eq(ctrl._dialogue_history[2]["text"], "troisième")


func test_add_history_entry_without_character() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	ctrl.add_history_entry("", "Texte narratif")
	assert_eq(ctrl._dialogue_history[0]["character"], "")
	assert_eq(ctrl._dialogue_history[0]["text"], "Texte narratif")


func test_add_choice_entry_uses_arrow_marker() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	ctrl.add_history_entry("→", "Je choisis cette option")
	assert_eq(ctrl._dialogue_history[0]["character"], "→")
	assert_eq(ctrl._dialogue_history[0]["text"], "Je choisis cette option")


func test_choice_entry_formatted_correctly() -> void:
	var result = GamePlayControllerScript.format_history_entry("→", "Je choisis cette option")
	assert_eq(result, "→ : Je choisis cette option")


# ---------------------------------------------------------------------------
# Réinitialisation de l'historique
# ---------------------------------------------------------------------------

func test_reset_history_clears_entries() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	ctrl.add_history_entry("X", "quelque chose")
	ctrl.add_history_entry("Y", "autre chose")
	ctrl.reset_history()
	assert_eq(ctrl._dialogue_history.size(), 0, "historique doit être vide après reset")


# ---------------------------------------------------------------------------
# État du panneau — _history_open toggle
# ---------------------------------------------------------------------------

func test_history_closed_by_default() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	assert_false(ctrl._history_open, "panneau fermé par défaut")


func test_open_history_sets_flag() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	ctrl.open_history()
	assert_true(ctrl._history_open, "open_history() doit mettre _history_open à true")


func test_open_history_when_already_open_closes_it() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	ctrl._history_open = true
	ctrl.open_history()
	assert_false(ctrl._history_open, "open_history() sur un panneau ouvert doit le fermer")


func test_close_history_sets_flag_false() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	ctrl._history_open = true
	ctrl.close_history()
	assert_false(ctrl._history_open, "close_history() doit mettre _history_open à false")


func test_close_history_when_already_closed_does_not_crash() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	ctrl.close_history()
	assert_false(ctrl._history_open, "pas de crash si déjà fermé")


# ---------------------------------------------------------------------------
# Texte du bouton selon l'état
# ---------------------------------------------------------------------------

func test_history_button_text_when_closed() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	var btn = Button.new()
	add_child_autofree(btn)
	ctrl._history_button = btn

	ctrl._history_open = false
	ctrl._update_history_button_text()
	assert_eq(btn.text, "Histo (H)", "texte standard quand fermé")


func test_history_button_text_when_open() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	var btn = Button.new()
	add_child_autofree(btn)
	ctrl._history_button = btn

	ctrl._history_open = true
	ctrl._update_history_button_text()
	assert_eq(btn.text, "Histo [ON]", "texte [ON] quand ouvert")


func test_history_button_text_no_button_does_not_crash() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	ctrl._history_button = null
	ctrl._update_history_button_text()
	assert_true(true, "pas de crash sans bouton")


# ---------------------------------------------------------------------------
# État disabled du bouton
# ---------------------------------------------------------------------------

func test_enable_history_button_sets_disabled_false() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	var btn = Button.new()
	add_child_autofree(btn)
	btn.disabled = true
	ctrl._history_button = btn

	ctrl._enable_history_button(true)
	assert_false(btn.disabled, "bouton doit être activé")


func test_disable_history_button_sets_disabled_true() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	var btn = Button.new()
	add_child_autofree(btn)
	btn.disabled = false
	ctrl._history_button = btn

	ctrl._enable_history_button(false)
	assert_true(btn.disabled, "bouton doit être désactivé")


func test_enable_history_button_without_button_does_not_crash() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	ctrl._history_button = null
	ctrl._enable_history_button(true)
	assert_true(true, "pas de crash sans bouton")
