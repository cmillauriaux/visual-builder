extends GutTest

const Chapter = preload("res://src/models/chapter.gd")
const Story = preload("res://src/models/story.gd")

# Tests pour le modèle Story

func test_create_story():
	var story = Story.new()
	story.title = "Mon Histoire"
	story.author = "Auteur"
	assert_eq(story.title, "Mon Histoire")
	assert_eq(story.author, "Auteur")

func test_default_values():
	var story = Story.new()
	assert_eq(story.title, "")
	assert_eq(story.author, "")
	assert_eq(story.description, "")
	assert_eq(story.version, "1.0.0")
	assert_ne(story.created_at, "", "created_at doit être auto-généré")
	assert_ne(story.updated_at, "", "updated_at doit être auto-généré")
	assert_eq(story.chapters.size(), 0)
	assert_eq(story.connections.size(), 0)

func test_add_chapter():
	var story = Story.new()
	var ch = Chapter.new()
	ch.chapter_name = "Chapitre 1"
	story.chapters.append(ch)
	assert_eq(story.chapters.size(), 1)

func test_add_connection():
	var story = Story.new()
	story.connections.append({"from": "abc-123", "to": "def-456"})
	assert_eq(story.connections.size(), 1)

func test_to_dict():
	var story = Story.new()
	story.title = "Mon Histoire"
	story.author = "Auteur"
	story.description = "Une aventure"
	story.version = "1.0.0"
	story.created_at = "2026-02-21T10:00:00Z"
	story.updated_at = "2026-02-21T15:30:00Z"

	var ch = Chapter.new()
	ch.uuid = "abc-123"
	ch.chapter_name = "Chapitre 1"
	ch.position = Vector2(100, 200)
	story.chapters.append(ch)
	story.connections.append({"from": "abc-123", "to": "def-456"})

	var d = story.to_dict()
	assert_eq(d["title"], "Mon Histoire")
	assert_eq(d["author"], "Auteur")
	assert_eq(d["description"], "Une aventure")
	assert_eq(d["version"], "1.0.0")
	assert_eq(d["created_at"], "2026-02-21T10:00:00Z")
	assert_eq(d["updated_at"], "2026-02-21T15:30:00Z")
	assert_eq(d["chapters"].size(), 1)
	assert_eq(d["chapters"][0]["uuid"], "abc-123")
	assert_eq(d["connections"].size(), 1)

func test_from_dict():
	var d = {
		"title": "Mon Histoire",
		"author": "Auteur",
		"description": "Une aventure",
		"version": "1.0.0",
		"created_at": "2026-02-21T10:00:00Z",
		"updated_at": "2026-02-21T15:30:00Z",
		"chapters": [
			{"uuid": "abc-123", "name": "Chapitre 1", "position": {"x": 100, "y": 200}}
		],
		"connections": [
			{"from": "abc-123", "to": "def-456"}
		]
	}
	var story = Story.from_dict(d)
	assert_eq(story.title, "Mon Histoire")
	assert_eq(story.author, "Auteur")
	assert_eq(story.description, "Une aventure")
	assert_eq(story.version, "1.0.0")
	assert_eq(story.chapters.size(), 1)
	assert_eq(story.chapters[0].uuid, "abc-123")
	assert_eq(story.connections.size(), 1)

func test_from_dict_minimal():
	var d = {"title": "Test", "author": "Moi"}
	var story = Story.from_dict(d)
	assert_eq(story.title, "Test")
	assert_eq(story.author, "Moi")
	assert_eq(story.description, "")
	assert_eq(story.version, "1.0.0")
	assert_eq(story.chapters.size(), 0)
	assert_eq(story.connections.size(), 0)

func test_update_modified_date():
	var story = Story.new()
	var old_date = story.updated_at
	story.touch()
	assert_ne(story.updated_at, "", "updated_at ne doit pas être vide après touch()")

func test_find_chapter_by_uuid():
	var story = Story.new()
	var ch1 = Chapter.new()
	ch1.uuid = "abc-123"
	ch1.chapter_name = "Premier"
	var ch2 = Chapter.new()
	ch2.uuid = "def-456"
	ch2.chapter_name = "Deuxième"
	story.chapters.append(ch1)
	story.chapters.append(ch2)
	var found = story.find_chapter("def-456")
	assert_not_null(found)
	assert_eq(found.chapter_name, "Deuxième")

func test_find_chapter_not_found():
	var story = Story.new()
	assert_null(story.find_chapter("nonexistent"))

# --- Tests des champs menu ---

func test_menu_fields_default_values():
	var story = Story.new()
	assert_eq(story.menu_title, "", "menu_title doit être vide par défaut")
	assert_eq(story.menu_subtitle, "", "menu_subtitle doit être vide par défaut")
	assert_eq(story.menu_background, "", "menu_background doit être vide par défaut")

func test_menu_fields_to_dict():
	var story = Story.new()
	story.menu_title = "Mon Jeu"
	story.menu_subtitle = "Une aventure épique"
	story.menu_background = "backgrounds/menu_bg.png"
	var d = story.to_dict()
	assert_eq(d["menu_title"], "Mon Jeu")
	assert_eq(d["menu_subtitle"], "Une aventure épique")
	assert_eq(d["menu_background"], "backgrounds/menu_bg.png")

func test_menu_fields_from_dict():
	var d = {
		"title": "Test",
		"menu_title": "Titre Menu",
		"menu_subtitle": "Sous-titre",
		"menu_background": "backgrounds/bg.png",
	}
	var story = Story.from_dict(d)
	assert_eq(story.menu_title, "Titre Menu")
	assert_eq(story.menu_subtitle, "Sous-titre")
	assert_eq(story.menu_background, "backgrounds/bg.png")

func test_menu_fields_from_dict_missing():
	# Rétrocompatibilité : les vieilles stories n'ont pas ces champs
	var d = {"title": "Old Story"}
	var story = Story.from_dict(d)
	assert_eq(story.menu_title, "")
	assert_eq(story.menu_subtitle, "")
	assert_eq(story.menu_background, "")

func test_ui_theme_mode_default_value() -> void:
	var story = Story.new()
	assert_eq(story.ui_theme_mode, "default", "ui_theme_mode should default to 'default'")

func test_to_dict_includes_ui_theme() -> void:
	var story = Story.new()
	story.ui_theme_mode = "custom"
	var d = story.to_dict()
	assert_true(d.has("ui_theme"), "to_dict should include 'ui_theme' key")
	assert_eq(d["ui_theme"]["mode"], "custom")

func test_to_dict_ui_theme_default() -> void:
	var story = Story.new()
	var d = story.to_dict()
	assert_eq(d["ui_theme"]["mode"], "default")

func test_from_dict_reads_ui_theme_mode() -> void:
	var d = {"ui_theme": {"mode": "custom"}}
	var story = Story.from_dict(d)
	assert_eq(story.ui_theme_mode, "custom")

func test_from_dict_missing_ui_theme_defaults_to_default() -> void:
	var d = {}  # ancienne story sans ui_theme
	var story = Story.from_dict(d)
	assert_eq(story.ui_theme_mode, "default", "Missing field should default to 'default'")
