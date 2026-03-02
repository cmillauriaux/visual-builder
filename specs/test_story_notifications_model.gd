extends GutTest

## Tests des modifications du modèle Story pour les notifications.

const StoryScript = preload("res://src/models/story.gd")
const StoryNotification = preload("res://src/models/story_notification.gd")

var _story: RefCounted

func before_each() -> void:
	_story = StoryScript.new()


# --- Champ notifications ---

func test_story_has_notifications_field() -> void:
	assert_not_null(_story.get("notifications"))

func test_notifications_is_empty_by_default() -> void:
	assert_eq(_story.notifications.size(), 0)


# --- get_triggered_notifications() ---

func test_get_triggered_notifications_empty_story() -> void:
	var result = _story.get_triggered_notifications("any_var")
	assert_eq(result.size(), 0)

func test_get_triggered_notifications_match() -> void:
	var n = StoryNotification.new()
	n.pattern = "*_affinity"
	n.message = "Souvenir"
	_story.notifications.append(n)
	var result = _story.get_triggered_notifications("mme_girard_affinity")
	assert_eq(result.size(), 1)
	assert_eq(result[0].message, "Souvenir")

func test_get_triggered_notifications_no_match() -> void:
	var n = StoryNotification.new()
	n.pattern = "*_affinity"
	n.message = "Souvenir"
	_story.notifications.append(n)
	var result = _story.get_triggered_notifications("score")
	assert_eq(result.size(), 0)

func test_get_triggered_notifications_multiple_matches() -> void:
	var n1 = StoryNotification.new()
	n1.pattern = "*_affinity"
	n1.message = "Souvenir"
	var n2 = StoryNotification.new()
	n2.pattern = "mme_*"
	n2.message = "Madame"
	_story.notifications.append(n1)
	_story.notifications.append(n2)
	var result = _story.get_triggered_notifications("mme_girard_affinity")
	assert_eq(result.size(), 2)

func test_get_triggered_notifications_only_matching() -> void:
	var n1 = StoryNotification.new()
	n1.pattern = "*_affinity"
	n1.message = "Souvenir"
	var n2 = StoryNotification.new()
	n2.pattern = "score"
	n2.message = "Score"
	_story.notifications.append(n1)
	_story.notifications.append(n2)
	var result = _story.get_triggered_notifications("mary_affinity")
	assert_eq(result.size(), 1)
	assert_eq(result[0].message, "Souvenir")


# --- Sérialisation ---

func test_to_dict_includes_notifications() -> void:
	var n = StoryNotification.new()
	n.pattern = "*_affinity"
	n.message = "Souvenir"
	_story.notifications.append(n)
	var d = _story.to_dict()
	assert_true(d.has("notifications"))
	assert_eq(d["notifications"].size(), 1)
	assert_eq(d["notifications"][0]["pattern"], "*_affinity")

func test_to_dict_notifications_empty_array() -> void:
	var d = _story.to_dict()
	assert_true(d.has("notifications"))
	assert_eq(d["notifications"].size(), 0)


# --- Désérialisation ---

func test_from_dict_loads_notifications() -> void:
	var d = {
		"title": "Test",
		"notifications": [
			{"pattern": "*_affinity", "message": "Souvenir"},
		]
	}
	var s = StoryScript.from_dict(d)
	assert_eq(s.notifications.size(), 1)
	assert_eq(s.notifications[0].pattern, "*_affinity")
	assert_eq(s.notifications[0].message, "Souvenir")

func test_from_dict_missing_notifications_gives_empty() -> void:
	var d = {"title": "Test"}
	var s = StoryScript.from_dict(d)
	assert_eq(s.notifications.size(), 0)

func test_from_dict_multiple_notifications() -> void:
	var d = {
		"title": "Test",
		"notifications": [
			{"pattern": "*_affinity", "message": "A"},
			{"pattern": "score", "message": "B"},
		]
	}
	var s = StoryScript.from_dict(d)
	assert_eq(s.notifications.size(), 2)
