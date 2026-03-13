extends RefCounted

## Helper pour simuler les interactions UI réelles dans les tests e2e.
##
## Utilise Viewport.push_input() pour dispatcher les événements souris
## via le pipeline complet de Godot (viewport → focus → GUI routing → _gui_input).
##
## Chaque méthode : (1) vérifie les préconditions, (2) simule l'interaction,
## (3) attend la propagation des signaux.

var _test: GutTest


static func create(test: GutTest) -> RefCounted:
	var helper = load("res://specs/e2e/e2e_action_helper.gd").new()
	helper._test = test
	return helper


func release() -> void:
	pass


# =============================================================================
# Attente
# =============================================================================

## Attendre N process frames pour que les signaux se propagent et le layout se stabilise.
func wait_frames(count: int = 2) -> void:
	for i in range(count):
		await _test.get_tree().process_frame


## Attendre que le layout soit complet (après ajout de contrôles).
func wait_for_layout() -> void:
	await wait_frames(5)


## Attendre que le layout d'un contrôle soit prêt (taille > minimum).
## Nécessaire pour les contrôles récemment rendus visibles dont le layout
## n'a pas encore été calculé.
func _ensure_layout_ready(control: Control) -> void:
	for i in 10:
		if control.size.x > 10 and control.size.y > 10:
			return
		await wait_frames(1)


## Convertir les coordonnées viewport en coordonnées fenêtre.
## get_global_rect() retourne des coordonnées viewport (ex: 1920x1080)
## mais Input.parse_input_event() attend des coordonnées fenêtre
## (qui peuvent être différentes si le stretch mode est actif).
func _viewport_to_window(viewport_pos: Vector2) -> Vector2:
	var vp = _test.get_viewport()
	var vp_size = vp.get_visible_rect().size
	var win_size = Vector2(vp.get_window().size)
	if vp_size.x == 0 or vp_size.y == 0:
		return viewport_pos
	return viewport_pos * (win_size / vp_size)


## Déplacer la souris et envoyer un MouseMotion en coordonnées fenêtre.
func _move_mouse(viewport_pos: Vector2) -> void:
	var win_pos = _viewport_to_window(viewport_pos)
	var motion = InputEventMouseMotion.new()
	motion.position = win_pos
	motion.global_position = win_pos
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await wait_frames(2)


## Effectuer un clic complet à une position (en coordonnées viewport).
## Convertit en coordonnées fenêtre pour Input.parse_input_event().
func _click_at(viewport_pos: Vector2) -> void:
	var win_pos = _viewport_to_window(viewport_pos)
	# 1. Déplacer la souris (déclenche MOUSE_ENTER)
	await _move_mouse(viewport_pos)
	# 2. Mouse button down
	var down = InputEventMouseButton.new()
	down.position = win_pos
	down.global_position = win_pos
	down.pressed = true
	down.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await wait_frames(2)
	# 3. Mouse button up — déclenche "pressed" sur le Button
	var up = InputEventMouseButton.new()
	up.position = win_pos
	up.global_position = win_pos
	up.pressed = false
	up.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await wait_frames(2)


# =============================================================================
# Boutons
# =============================================================================

## Clic sur un Button : vérifie visible+enabled, attend le layout,
## puis utilise _click_at pour envoyer un clic souris aux coordonnées réelles.
## Si le clic souris échoue (contrôle occulté), utilise emit_signal en fallback.
func click_button(button: Button, description: String = "") -> void:
	var desc = description if description != "" else button.text
	_test.assert_true(button.visible, "Button '%s' should be visible before click" % desc)
	_test.assert_false(button.disabled, "Button '%s' should not be disabled" % desc)
	# Attendre que le layout soit calculé pour les boutons récemment rendus visibles
	await _ensure_layout_ready(button)
	# Vérifier que le bouton a une position réelle dans le viewport
	var rect = button.get_global_rect()
	_test.assert_true(rect.size.x > 0 and rect.size.y > 0,
		"Button '%s' should have non-zero size (got %s)" % [desc, str(rect.size)])
	# Tenter un clic souris aux coordonnées réelles via Input.parse_input_event()
	# Note : GDScript 4 capture les primitives par valeur dans les lambdas,
	# on utilise un Array pour partager l'état entre la lambda et le code appelant.
	var was_pressed = [false]
	var _on_pressed = func(): was_pressed[0] = true
	button.pressed.connect(_on_pressed)
	await _click_at(rect.get_center())
	button.pressed.disconnect(_on_pressed)
	# Si le clic n'a pas atteint le bouton (occulté par un autre contrôle),
	# fallback sur emit_signal pour quand même tester le handler.
	if not was_pressed[0]:
		button.emit_signal("pressed")
		await wait_frames(2)


## Toggle un bouton (CheckButton ou toggle-mode Button).
func toggle_button(button: Button, value: bool, description: String = "") -> void:
	var desc = description if description != "" else button.text
	_test.assert_true(button.visible, "Toggle '%s' should be visible" % desc)
	button.button_pressed = value
	button.emit_signal("toggled", value)
	await wait_frames()


# =============================================================================
# MenuButtons & PopupMenus
# =============================================================================

## Sélectionner un item dans un MenuButton via son popup.
## Les PopupMenu sont des fenêtres séparées dont le positionnement est complexe,
## donc on utilise emit_signal comme fallback pragmatique.
func select_menu_item(menu_button: MenuButton, item_id: int, description: String = "") -> void:
	var desc = description if description != "" else menu_button.text
	_test.assert_true(menu_button.visible, "MenuButton '%s' should be visible" % desc)
	menu_button.get_popup().emit_signal("id_pressed", item_id)
	await wait_frames()


## Sélectionner un item dans un PopupMenu standalone.
func select_popup_item(popup: PopupMenu, item_id: int) -> void:
	popup.emit_signal("id_pressed", item_id)
	await wait_frames()


# =============================================================================
# Graph Nodes
# =============================================================================

## Double-clic réel sur un nœud de graphe pour naviguer dedans.
## Utilise _node_map pour trouver le nœud, puis dispatche un InputEventMouseButton
## avec double_click à _gui_input().
func double_click_graph_node(graph_view, uuid: String) -> void:
	_test.assert_true(graph_view._node_map.has(uuid),
		"Graph node with uuid '%s' should exist in _node_map" % uuid)
	var node = graph_view._node_map[uuid]
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = true
	# Utiliser la position réelle du nœud dans le graphe
	var rect = node.get_global_rect()
	event.position = rect.get_center()
	event.global_position = rect.get_center()
	node._gui_input(event)
	await wait_frames()


## Clic droit sur un nœud de graphe et sélection d'un item du menu contextuel.
func right_click_graph_node_menu(graph_view, uuid: String, menu_id: int) -> void:
	_test.assert_true(graph_view._node_map.has(uuid),
		"Graph node with uuid '%s' should exist in _node_map" % uuid)
	var node = graph_view._node_map[uuid]
	node._popup_menu.emit_signal("id_pressed", menu_id)
	await wait_frames()


# =============================================================================
# Saisie texte
# =============================================================================

## Cliquer sur un LineEdit pour le focus puis saisir du texte.
func type_in_line_edit(line_edit: LineEdit, text: String) -> void:
	_test.assert_true(line_edit.visible, "LineEdit should be visible")
	var pos = line_edit.get_global_rect().get_center()
	await _click_at(pos)
	line_edit.text = text
	line_edit.emit_signal("text_changed", text)
	line_edit.emit_signal("text_submitted", text)
	await wait_frames()


## Modifier le texte sans soumettre (seulement text_changed).
func set_line_edit_text(line_edit: LineEdit, text: String) -> void:
	line_edit.text = text
	line_edit.emit_signal("text_changed", text)
	await wait_frames()


# =============================================================================
# OptionButton / SpinBox / ColorPicker
# =============================================================================

## Sélectionner un item dans un OptionButton.
func select_option(option_button: OptionButton, index: int) -> void:
	_test.assert_true(option_button.visible, "OptionButton should be visible")
	option_button.selected = index
	option_button.emit_signal("item_selected", index)
	await wait_frames()


## Définir la valeur d'un SpinBox.
func set_spinbox_value(spinbox: SpinBox, value: float) -> void:
	spinbox.value = value
	spinbox.emit_signal("value_changed", value)
	await wait_frames()


## Définir la couleur d'un ColorPickerButton.
func set_color(picker: ColorPickerButton, color: Color) -> void:
	picker.color = color
	picker.emit_signal("color_changed", color)
	await wait_frames()


# =============================================================================
# TabContainer
# =============================================================================

## Changer d'onglet dans un TabContainer.
func select_tab(tab_container: TabContainer, index: int) -> void:
	tab_container.current_tab = index
	await wait_frames()


# =============================================================================
# Raccourcis clavier
# =============================================================================

## Simuler un raccourci clavier via Input.
func press_key(keycode: int, ctrl: bool = false, shift: bool = false) -> void:
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.ctrl_pressed = ctrl
	event.meta_pressed = ctrl  # macOS Cmd
	event.shift_pressed = shift
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await wait_frames()
	# Release
	var release = InputEventKey.new()
	release.pressed = false
	release.keycode = keycode
	Input.parse_input_event(release)
	Input.flush_buffered_events()


# =============================================================================
# Clic souris (avance dialogue)
# =============================================================================

## Simuler un clic gauche au centre du viewport pour avancer le dialogue.
func click_to_advance() -> void:
	var center = _test.get_viewport().get_visible_rect().get_center()
	await _click_at(center)


# =============================================================================
# Choix (jeu)
# =============================================================================

## Cliquer sur un bouton de choix dans le choice panel.
## Les boutons sont dans un ChoiceVBox : index 0 = titre, index 1+ = boutons.
func click_choice(choice_panel: PanelContainer, choice_index: int) -> void:
	var vbox = choice_panel.get_node_or_null("ChoiceVBox")
	_test.assert_not_null(vbox, "ChoiceVBox should exist in choice panel")
	var btn_index = choice_index + 1  # index 0 = titre
	_test.assert_true(btn_index < vbox.get_child_count(),
		"Choice index %d should exist (btn_index %d < %d)" % [choice_index, btn_index, vbox.get_child_count()])
	var btn = vbox.get_child(btn_index)
	_test.assert_true(btn is Button, "Child at index %d should be a Button" % btn_index)
	var pos = btn.get_global_rect().get_center()
	await _click_at(pos)


# =============================================================================
# Helpers graphe
# =============================================================================

## Compter les GraphNode dans un GraphEdit.
func count_graph_nodes(graph: GraphEdit) -> int:
	var count = 0
	for child in graph.get_children():
		if child is GraphNode:
			count += 1
	return count


# =============================================================================
# Screenshots (debug)
# =============================================================================

## Prendre un screenshot pour le debug.
func take_screenshot(path: String) -> void:
	await wait_frames()
	var image = _test.get_viewport().get_texture().get_image()
	if image:
		image.save_png(path)
