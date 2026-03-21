# Chapter Transition Loading Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Afficher l'image `menu_background` de la story (au lieu d'un écran noir) pendant le chargement inter-chapitres.

**Architecture:** Modifier `_build_loading_overlay()` dans `game_ui_builder.gd` pour utiliser un `TextureRect` + scrim au lieu du `ColorRect` semi-transparent, exposer la référence via `game._loading_overlay_bg`, puis appeler `_setup_loading_overlay_image(story)` dans `game.gd` aux 3 endroits où `_current_story` est assigné.

**Tech Stack:** GDScript 4, Godot 4.6.1, GUT 9.3.0

---

## Fichiers modifiés

- **Modifier:** `src/controllers/game_ui_builder.gd:182-204` — `_build_loading_overlay()`
- **Modifier:** `src/game.gd:105-106` — déclaration variable + 3 call sites + nouvelle fonction
- **Modifier:** `specs/game/test_game_ui_builder.gd` — ajout `test_builds_loading_overlay_bg`

---

## Task 1 : Test unitaire + modification du builder

**Files:**
- Modify: `specs/game/test_game_ui_builder.gd` (après la dernière fonction `test_`)
- Modify: `src/game.gd:105-106`
- Modify: `src/controllers/game_ui_builder.gd:182-204`

- [ ] **Step 1 : Écrire le test qui échoue**

Ajouter à la fin de `specs/game/test_game_ui_builder.gd` (avant la dernière ligne si elle existe, sinon à la fin) :

```gdscript
func test_builds_loading_overlay_bg() -> void:
	assert_not_null(_game._loading_overlay_bg, "loading_overlay_bg should be created")
	assert_true(_game._loading_overlay_bg is TextureRect, "loading_overlay_bg should be a TextureRect")
	assert_eq(_game._loading_overlay_bg.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	assert_true(_game._loading_overlay.get_child(0) is TextureRect, "first child should be TextureRect (image behind scrim)")
	assert_true(_game._loading_overlay.get_child(1) is ColorRect, "second child should be ColorRect (scrim)")
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/game/test_game_ui_builder.gd 2>&1 | tail -30
```

Attendu : FAIL sur `test_builds_loading_overlay_bg` (null reference ou wrong type).

- [ ] **Step 3 : Déclarer `_loading_overlay_bg` dans `game.gd`**

Dans `src/game.gd`, trouver les lignes :
```gdscript
var _loading_overlay: Control
var _loading_overlay_label: Label
```

Ajouter après :
```gdscript
var _loading_overlay_bg: TextureRect
```

- [ ] **Step 4 : Modifier `_build_loading_overlay()` dans `game_ui_builder.gd`**

Remplacer la fonction entière `_build_loading_overlay` (lignes 182-204) :

```gdscript
static func _build_loading_overlay(game: Control) -> void:
	game._loading_overlay = Control.new()
	game._loading_overlay.visible = false
	game._loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	game._loading_overlay.z_index = 90
	game.add_child(game._loading_overlay)

	var bg := TextureRect.new()
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._loading_overlay_bg = bg
	game._loading_overlay.add_child(bg)

	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.7)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._loading_overlay.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._loading_overlay.add_child(center)

	game._loading_overlay_label = Label.new()
	game._loading_overlay_label.text = "Chargement..."
	game._loading_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game._loading_overlay_label.add_theme_font_size_override("font_size", UIScale.scale(28))
	game._loading_overlay_label.add_theme_color_override("font_color", Color.WHITE)
	center.add_child(game._loading_overlay_label)
```

- [ ] **Step 5 : Lancer le test pour vérifier qu'il passe**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/game/test_game_ui_builder.gd 2>&1 | tail -30
```

Attendu : tous les tests PASS, y compris `test_builds_loading_overlay_bg`.

- [ ] **Step 6 : Commit**

```bash
git add specs/game/test_game_ui_builder.gd src/game.gd src/controllers/game_ui_builder.gd
git commit -m "feat: utiliser TextureRect comme fond de l'overlay de chargement inter-chapitres"
```

---

## Task 2 : Charger l'image au démarrage de la story

**Files:**
- Modify: `specs/game/test_game_ui_builder.gd` — test pour `_setup_loading_overlay_image`
- Modify: `src/game.gd` — nouvelle fonction + 3 appels

- [ ] **Step 1 : Écrire le test qui échoue**

Ajouter après `test_builds_loading_overlay_bg` dans `specs/game/test_game_ui_builder.gd` :

```gdscript
func test_setup_loading_overlay_image_with_null_clears_texture() -> void:
	_game._setup_loading_overlay_image(null)
	assert_null(_game._loading_overlay_bg.texture, "texture should be null when story is null")
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/game/test_game_ui_builder.gd 2>&1 | tail -20
```

Attendu : FAIL — `_setup_loading_overlay_image` n'existe pas encore.

- [ ] **Step 3 : Ajouter `_setup_loading_overlay_image()` dans `game.gd`**

Ajouter cette fonction après la fermeture de `_on_chapter_loading_finished()` (avant `_on_analytics_story_finished`, ligne ~1058) :

```gdscript
func _setup_loading_overlay_image(story) -> void:
	if _loading_overlay_bg == null:
		return
	if story == null or story.menu_background.is_empty():
		_loading_overlay_bg.texture = null
		return
	_loading_overlay_bg.texture = TextureLoader.load_texture(story.menu_background)
```

- [ ] **Step 4 : Lancer le test pour vérifier qu'il passe**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/game/test_game_ui_builder.gd 2>&1 | tail -20
```

Attendu : tous les tests PASS.

- [ ] **Step 5 : Appeler la fonction dans `_load_story_and_show_menu()`**

Dans `src/game.gd`, trouver (ligne ~317-318) :
```gdscript
	_current_story = story
	_current_story_path = path
```

Ajouter juste après :
```gdscript
	_setup_loading_overlay_image(_current_story)
```

- [ ] **Step 6 : Appeler la fonction dans `_on_load_slot()` (chargement sauvegarde, story différente)**

Dans `src/game.gd`, dans la fonction `_on_load_slot` (ligne ~786), trouver le bloc conditionnel :
```gdscript
		_current_story = story
		_current_story_path = target_path
```

Ajouter juste après (toujours dans le `if target_path != _current_story_path and target_path != "":`) :
```gdscript
		_setup_loading_overlay_image(_current_story)
```

- [ ] **Step 7 : Appeler la fonction dans `_do_quickload()` (quickload, story différente)**

Dans `src/game.gd`, dans la fonction `_do_quickload()` (ligne ~1108), trouver le même pattern :
```gdscript
		_current_story = story
		_current_story_path = target_path
```

Ajouter juste après (toujours dans le `if target_path != _current_story_path and target_path != "":`) :
```gdscript
		_setup_loading_overlay_image(_current_story)
```

- [ ] **Step 8 : Lancer la suite de tests complète pour vérifier aucune régression**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd 2>&1 | tail -40
```

Attendu : tous les tests passent.

- [ ] **Step 9 : Commit**

```bash
git add specs/game/test_game_ui_builder.gd src/game.gd
git commit -m "feat: afficher menu_background pendant le chargement inter-chapitres"
```
