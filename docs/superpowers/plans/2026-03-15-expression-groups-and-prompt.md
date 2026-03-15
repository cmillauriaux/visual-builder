# Expression Groups & Prompt Fix — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Diviser la liste d'expressions en deux groupes "Élémentaires" / "Avancées" avec boutons "Cocher tout" indépendants, et corriger le prompt de génération.

**Architecture:** Modification de `ai_studio_dialog.gd` (constantes, variables, UI) et de `expression_queue_service.gd` (prompt). Pas de nouveau fichier. Approche TDD avec commits fréquents.

**Tech Stack:** GDScript / Godot 4.6.1, GUT 9.3.0

---

## Commandes de test

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}

# Tests du service uniquement
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_expression_queue_service.gd

# Tests du dialog uniquement
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/dialogs/test_ai_studio_dialog.gd

# Tous les tests
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd
```

---

## Chunk 1 : Fix `_build_prompt`

### Task 1 : Test + implémentation du nouveau prompt

**Files:**
- Modify: `specs/services/test_expression_queue_service.gd`
- Modify: `src/services/expression_queue_service.gd:101-102`

- [ ] **Step 1 : Écrire le test qui échoue**

Dans `specs/services/test_expression_queue_service.gd`, ajouter à la fin :

```gdscript
func test_build_prompt():
	var svc = ExpressionQueueServiceScript
	assert_eq(
		svc._build_prompt("smile"),
		"The same character with a smile expression, keep the eyes color"
	)
```

- [ ] **Step 2 : Vérifier que le test échoue**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_expression_queue_service.gd
```

Attendu : FAIL sur `test_build_prompt` — `"smile" != "The same character with a smile expression, keep the eyes color"`

- [ ] **Step 3 : Implémenter le fix**

Dans `src/services/expression_queue_service.gd`, remplacer :

```gdscript
static func _build_prompt(expression: String) -> String:
	return expression
```

par :

```gdscript
static func _build_prompt(expression: String) -> String:
	return "The same character with a %s expression, keep the eyes color" % expression
```

- [ ] **Step 4 : Vérifier que le test passe**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_expression_queue_service.gd
```

Attendu : tous les tests PASS (dont `test_build_prompt`)

- [ ] **Step 5 : Commit**

```bash
git add specs/services/test_expression_queue_service.gd src/services/expression_queue_service.gd
git commit -m "feat(expressions): fix build_prompt to include character context and eye color"
```

---

## Chunk 2 : Regroupement UI des expressions

### Task 2 : Tests qui échouent pour la nouvelle structure

**Files:**
- Modify: `specs/ui/dialogs/test_ai_studio_dialog.gd`

- [ ] **Step 1 : Écrire les tests échouants**

Ajouter à la fin de `specs/ui/dialogs/test_ai_studio_dialog.gd` :

```gdscript
# ========================================================
# Expressions — Groupes
# ========================================================

func test_elementary_expressions_count():
	assert_eq(AIStudioDialog.ELEMENTARY_EXPRESSIONS.size(), 16)


func test_advanced_expressions_count():
	assert_eq(AIStudioDialog.ADVANCED_EXPRESSIONS.size(), 29)


func test_expressions_total_is_45():
	var all = AIStudioDialog.ELEMENTARY_EXPRESSIONS + AIStudioDialog.ADVANCED_EXPRESSIONS
	assert_eq(all.size(), 45)


func test_expression_groups_are_disjoint():
	for expr in AIStudioDialog.ELEMENTARY_EXPRESSIONS:
		assert_false(
			AIStudioDialog.ADVANCED_EXPRESSIONS.has(expr),
			"Expression '%s' présente dans les deux groupes" % expr
		)


func test_has_elementary_checkboxes():
	assert_not_null(_dialog._expr_elementary_checkboxes)
	assert_eq(_dialog._expr_elementary_checkboxes.size(), 16)


func test_has_advanced_checkboxes():
	assert_not_null(_dialog._expr_advanced_checkboxes)
	assert_eq(_dialog._expr_advanced_checkboxes.size(), 29)


func test_has_elementary_select_all_btn():
	assert_not_null(_dialog._expr_elementary_select_all_btn)
	assert_is(_dialog._expr_elementary_select_all_btn, Button)


func test_has_advanced_select_all_btn():
	assert_not_null(_dialog._expr_advanced_select_all_btn)
	assert_is(_dialog._expr_advanced_select_all_btn, Button)


func test_elementary_select_all_btn_initial_text():
	# Seule la première expression est cochée au départ → pas "toutes cochées"
	assert_eq(_dialog._expr_elementary_select_all_btn.text, "Cocher tout")


func test_advanced_select_all_btn_initial_text():
	assert_eq(_dialog._expr_advanced_select_all_btn.text, "Cocher tout")


func test_elementary_select_all_checks_only_elementary():
	# Décocher toutes d'abord
	for cb in _dialog._expr_elementary_checkboxes:
		cb.button_pressed = false
	for cb in _dialog._expr_advanced_checkboxes:
		cb.button_pressed = false
	# Cliquer le bouton "Cocher tout" des élémentaires
	_dialog._expr_elementary_select_all_btn.emit_signal("pressed")
	# Toutes les élémentaires cochées
	for cb in _dialog._expr_elementary_checkboxes:
		assert_true(cb.button_pressed, "Elementary '%s' devrait être coché" % cb.text)
	# Les avancées restent décochées
	for cb in _dialog._expr_advanced_checkboxes:
		assert_false(cb.button_pressed, "Advanced '%s' ne devrait pas être coché" % cb.text)


func test_advanced_select_all_checks_only_advanced():
	for cb in _dialog._expr_elementary_checkboxes:
		cb.button_pressed = false
	for cb in _dialog._expr_advanced_checkboxes:
		cb.button_pressed = false
	_dialog._expr_advanced_select_all_btn.emit_signal("pressed")
	for cb in _dialog._expr_advanced_checkboxes:
		assert_true(cb.button_pressed, "Advanced '%s' devrait être coché" % cb.text)
	for cb in _dialog._expr_elementary_checkboxes:
		assert_false(cb.button_pressed, "Elementary '%s' ne devrait pas être coché" % cb.text)


func test_get_selected_expressions_includes_custom():
	# Décocher toutes les expressions par défaut
	for cb in _dialog._expr_elementary_checkboxes:
		cb.button_pressed = false
	for cb in _dialog._expr_advanced_checkboxes:
		cb.button_pressed = false
	# Ajouter une expression custom cochée
	_dialog._expr_custom_input.text = "ma_custom_expr"
	_dialog._on_expr_add_custom()
	var selected = _dialog._get_selected_expressions()
	assert_true(selected.has("ma_custom_expr"), "Custom expression devrait être dans la sélection")
```

- [ ] **Step 2 : Vérifier que les tests échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/dialogs/test_ai_studio_dialog.gd
```

Attendu : FAIL sur les nouveaux tests (ELEMENTARY_EXPRESSIONS manquant, etc.)

- [ ] **Step 3 : Commit des tests**

```bash
git add specs/ui/dialogs/test_ai_studio_dialog.gd
git commit -m "test(ai-studio): add failing tests for expression groups UI"
```

---

### Task 3 : Implémenter les constantes et variables

**Files:**
- Modify: `src/ui/dialogs/ai_studio_dialog.gd:14-24` (constantes)
- Modify: `src/ui/dialogs/ai_studio_dialog.gd:77` (variable)

- [ ] **Step 1 : Remplacer `DEFAULT_EXPRESSIONS` par deux constantes**

Dans `src/ui/dialogs/ai_studio_dialog.gd`, remplacer les lignes 14-24 :

```gdscript
const DEFAULT_EXPRESSIONS := [
	"smile", "sad", "shy", "grumpy", "laughing out loud",
	"angry", "surprised", "worried", "neutral", "scared",
	"disgusted", "confused", "proud", "embarrassed", "bored",
	"idle", "speaking", "thinking", "listening", "happy",
	"cheerful", "confident", "playful", "curious", "calm",
	"warm", "friendly", "joyful", "serene", "enthusiastic",
	"excited", "crying", "hopeful", "determined", "jealous",
	"dreamy", "mischievous", "exhausted", "relieved", "suspicious",
	"tender", "annoyed", "desperate", "nostalgic", "seductive",
]
```

par :

```gdscript
const ELEMENTARY_EXPRESSIONS := [
	"smile", "sad", "shy", "grumpy", "laughing out loud",
	"angry", "surprised", "scared", "bored", "speaking",
	"happy", "calm", "crying", "determined", "exhausted",
	"annoyed",
]

const ADVANCED_EXPRESSIONS := [
	"worried", "neutral", "disgusted", "confused", "proud",
	"embarrassed", "idle", "thinking", "listening", "cheerful",
	"confident", "playful", "curious", "warm", "friendly",
	"joyful", "serene", "enthusiastic", "excited", "hopeful",
	"jealous", "dreamy", "mischievous", "relieved", "suspicious",
	"tender", "desperate", "nostalgic", "seductive",
]
```

- [ ] **Step 2 : Mettre à jour les variables de classe**

Dans `src/ui/dialogs/ai_studio_dialog.gd`, remplacer la ligne 77 :

```gdscript
var _expr_expression_checkboxes: Array = []
```

par :

```gdscript
var _expr_elementary_checkboxes: Array = []
var _expr_advanced_checkboxes: Array = []
var _expr_elementary_select_all_btn: Button
var _expr_advanced_select_all_btn: Button
```

- [ ] **Step 3 : Vérifier que les tests de constantes passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/dialogs/test_ai_studio_dialog.gd
```

Attendu : `test_elementary_expressions_count`, `test_advanced_expressions_count`, `test_expressions_total_is_45`, `test_expression_groups_are_disjoint` passent. Les autres tests UI échouent encore (normal).

---

### Task 4 : Refactorer `_build_expressions_tab()`

**Files:**
- Modify: `src/ui/dialogs/ai_studio_dialog.gd:559-595` (section expressions)

- [ ] **Step 1 : Remplacer la section "Expressions" dans `_build_expressions_tab()`**

Dans `src/ui/dialogs/ai_studio_dialog.gd`, remplacer le bloc complet depuis `# Expressions` (ligne 559) jusqu'à la ligne 595 (`_expr_expression_checkboxes.append(cb)`) incluse :

```gdscript
	# Expressions
	var expr_header = HBoxContainer.new()
	vbox.add_child(expr_header)

	var expr_label = Label.new()
	expr_label.text = "Expressions :"
	expr_label.add_theme_font_size_override("font_size", 16)
	expr_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expr_header.add_child(expr_label)

	var toggle_all_btn = Button.new()
	toggle_all_btn.text = "Décocher tout"
	toggle_all_btn.pressed.connect(func():
		var all_checked = _expr_expression_checkboxes.all(func(c): return c.button_pressed)
		for c in _expr_expression_checkboxes:
			c.button_pressed = not all_checked
		toggle_all_btn.text = "Cocher tout" if all_checked else "Décocher tout"
		_update_expr_generate_button()
	)
	expr_header.add_child(toggle_all_btn)

	var expr_flow = HFlowContainer.new()
	expr_flow.add_theme_constant_override("h_separation", 8)
	expr_flow.add_theme_constant_override("v_separation", 4)
	vbox.add_child(expr_flow)

	for i in range(DEFAULT_EXPRESSIONS.size()):
		var cb = CheckBox.new()
		cb.text = DEFAULT_EXPRESSIONS[i]
		cb.button_pressed = (i == 0)
		cb.toggled.connect(func(_p):
			var all_checked = _expr_expression_checkboxes.all(func(c): return c.button_pressed)
			toggle_all_btn.text = "Décocher tout" if all_checked else "Cocher tout"
			_update_expr_generate_button()
		)
		expr_flow.add_child(cb)
		_expr_expression_checkboxes.append(cb)
```

par :

```gdscript
	# Expressions élémentaires
	var elem_header = HBoxContainer.new()
	vbox.add_child(elem_header)

	var elem_label = Label.new()
	elem_label.text = "Expressions élémentaires"
	elem_label.add_theme_font_size_override("font_size", 16)
	elem_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elem_header.add_child(elem_label)

	_expr_elementary_select_all_btn = Button.new()
	_expr_elementary_select_all_btn.text = "Cocher tout"
	_expr_elementary_select_all_btn.pressed.connect(func():
		var all_checked = _expr_elementary_checkboxes.all(func(c): return c.button_pressed)
		for c in _expr_elementary_checkboxes:
			c.button_pressed = not all_checked
		_update_group_select_all_btn(_expr_elementary_select_all_btn, _expr_elementary_checkboxes)
		_update_expr_generate_button()
	)
	elem_header.add_child(_expr_elementary_select_all_btn)

	var elem_flow = HFlowContainer.new()
	elem_flow.add_theme_constant_override("h_separation", 8)
	elem_flow.add_theme_constant_override("v_separation", 4)
	vbox.add_child(elem_flow)

	for i in range(ELEMENTARY_EXPRESSIONS.size()):
		var cb = CheckBox.new()
		cb.text = ELEMENTARY_EXPRESSIONS[i]
		cb.button_pressed = (i == 0)
		cb.toggled.connect(func(_p):
			_update_group_select_all_btn(_expr_elementary_select_all_btn, _expr_elementary_checkboxes)
			_update_expr_generate_button()
		)
		elem_flow.add_child(cb)
		_expr_elementary_checkboxes.append(cb)

	vbox.add_child(HSeparator.new())

	# Expressions avancées
	var adv_header = HBoxContainer.new()
	vbox.add_child(adv_header)

	var adv_label = Label.new()
	adv_label.text = "Expressions avancées"
	adv_label.add_theme_font_size_override("font_size", 16)
	adv_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adv_header.add_child(adv_label)

	_expr_advanced_select_all_btn = Button.new()
	_expr_advanced_select_all_btn.text = "Cocher tout"
	_expr_advanced_select_all_btn.pressed.connect(func():
		var all_checked = _expr_advanced_checkboxes.all(func(c): return c.button_pressed)
		for c in _expr_advanced_checkboxes:
			c.button_pressed = not all_checked
		_update_group_select_all_btn(_expr_advanced_select_all_btn, _expr_advanced_checkboxes)
		_update_expr_generate_button()
	)
	adv_header.add_child(_expr_advanced_select_all_btn)

	var adv_flow = HFlowContainer.new()
	adv_flow.add_theme_constant_override("h_separation", 8)
	adv_flow.add_theme_constant_override("v_separation", 4)
	vbox.add_child(adv_flow)

	for expr in ADVANCED_EXPRESSIONS:
		var cb = CheckBox.new()
		cb.text = expr
		cb.button_pressed = false
		cb.toggled.connect(func(_p):
			_update_group_select_all_btn(_expr_advanced_select_all_btn, _expr_advanced_checkboxes)
			_update_expr_generate_button()
		)
		adv_flow.add_child(cb)
		_expr_advanced_checkboxes.append(cb)
```

- [ ] **Step 2 : Ajouter le helper `_update_group_select_all_btn`**

Dans `src/ui/dialogs/ai_studio_dialog.gd`, ajouter cette fonction aux côtés de `_update_expr_generate_button` :

```gdscript
func _update_group_select_all_btn(btn: Button, checkboxes: Array) -> void:
	var all_checked = checkboxes.all(func(c): return c.button_pressed)
	btn.text = "Décocher tout" if all_checked else "Cocher tout"
```

---

### Task 5 : Mettre à jour les fonctions qui utilisaient `_expr_expression_checkboxes`

**Files:**
- Modify: `src/ui/dialogs/ai_studio_dialog.gd` (fonctions `_get_selected_expressions`, `_expression_already_exists`, `_add_custom_expression_ui`)

- [ ] **Step 1 : Mettre à jour `_get_selected_expressions()`**

Remplacer :

```gdscript
func _get_selected_expressions() -> Array:
	var expressions: Array = []
	for cb in _expr_expression_checkboxes:
		if cb.button_pressed:
			expressions.append(cb.text)
	return expressions
```

par :

```gdscript
func _get_selected_expressions() -> Array:
	var expressions: Array = []
	for cb in _expr_elementary_checkboxes + _expr_advanced_checkboxes:
		if cb.button_pressed:
			expressions.append(cb.text)
	for child in _expr_custom_container.get_children():
		if child is HBoxContainer and child.get_child_count() > 0:
			var cb = child.get_child(0)
			if cb is CheckBox and cb.button_pressed:
				expressions.append(cb.text)
	return expressions
```

- [ ] **Step 2 : Mettre à jour `_expression_already_exists()`**

Remplacer :

```gdscript
func _expression_already_exists(expr_text: String) -> bool:
	for cb in _expr_expression_checkboxes:
		if cb.text.to_lower() == expr_text.to_lower():
			return true
	return false
```

par :

```gdscript
func _expression_already_exists(expr_text: String) -> bool:
	for cb in _expr_elementary_checkboxes + _expr_advanced_checkboxes:
		if cb.text.to_lower() == expr_text.to_lower():
			return true
	for child in _expr_custom_container.get_children():
		if child is HBoxContainer and child.get_child_count() > 0:
			var cb = child.get_child(0)
			if cb is CheckBox and cb.text.to_lower() == expr_text.to_lower():
				return true
	return false
```

- [ ] **Step 3 : Mettre à jour `_add_custom_expression_ui()`**

Dans `_add_custom_expression_ui`, supprimer les deux lignes qui référencent `_expr_expression_checkboxes` :

```gdscript
	# Ligne à supprimer dans le pressed.connect du del_btn :
	_expr_expression_checkboxes.erase(cb)

	# Ligne à supprimer à la fin de la fonction :
	_expr_expression_checkboxes.append(cb)
```

Le résultat doit être :

```gdscript
func _add_custom_expression_ui(expr_text: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var cb = CheckBox.new()
	cb.text = expr_text
	cb.button_pressed = false
	cb.toggled.connect(func(_p): _update_expr_generate_button())
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(cb)

	var del_btn = Button.new()
	del_btn.text = "✕"
	del_btn.custom_minimum_size = Vector2(30, 0)
	del_btn.pressed.connect(func():
		hbox.queue_free()
		_save_custom_expressions()
		_update_expr_generate_button()
	)
	hbox.add_child(del_btn)

	_expr_custom_container.add_child(hbox)
```

- [ ] **Step 4 : Lancer les tests et vérifier que tout passe**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/dialogs/test_ai_studio_dialog.gd
```

Attendu : tous les tests PASS (y compris les nouveaux tests de groupes)

- [ ] **Step 5 : Lancer la suite complète**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd
```

Attendu : tous les tests PASS, aucune régression

- [ ] **Step 6 : Commit**

```bash
git add src/ui/dialogs/ai_studio_dialog.gd
git commit -m "feat(ai-studio): group expressions into elementary/advanced with independent select-all buttons"
```
