extends GutTest

## Tests pour NotificationDialog — gestion des notifications de l'histoire.

var NotificationDialogScript = load("res://src/ui/dialogs/notification_dialog.gd")
var StoryScript = load("res://src/models/story.gd")
var StoryNotificationScript = load("res://src/models/story_notification.gd")

var _dialog: AcceptDialog


func before_each() -> void:
	_dialog = AcceptDialog.new()
	_dialog.set_script(NotificationDialogScript)
	add_child_autofree(_dialog)


func _make_story() -> RefCounted:
	return StoryScript.new()


func test_dialog_exists() -> void:
	assert_not_null(_dialog)


func test_title_is_notifications() -> void:
	assert_eq(_dialog.title, tr("Notifications"))


func test_ok_button_text() -> void:
	assert_eq(_dialog.ok_button_text, tr("Fermer"))


func test_get_notification_count_no_story() -> void:
	assert_eq(_dialog.get_notification_count(), 0)


func test_setup_with_story() -> void:
	var story = _make_story()
	_dialog.setup(story)
	assert_eq(_dialog.get_notification_count(), 0)


func test_add_notification() -> void:
	var story = _make_story()
	_dialog.setup(story)
	_dialog.add_notification()
	assert_eq(_dialog.get_notification_count(), 1)
	assert_eq(story.notifications.size(), 1)


func test_add_multiple_notifications() -> void:
	var story = _make_story()
	_dialog.setup(story)
	_dialog.add_notification()
	_dialog.add_notification()
	_dialog.add_notification()
	assert_eq(_dialog.get_notification_count(), 3)


func test_remove_notification() -> void:
	var story = _make_story()
	_dialog.setup(story)
	_dialog.add_notification()
	_dialog.add_notification()
	_dialog.remove_notification(0)
	assert_eq(_dialog.get_notification_count(), 1)


func test_remove_notification_invalid_index() -> void:
	var story = _make_story()
	_dialog.setup(story)
	_dialog.add_notification()
	_dialog.remove_notification(-1)
	_dialog.remove_notification(99)
	assert_eq(_dialog.get_notification_count(), 1)


func test_update_pattern() -> void:
	var story = _make_story()
	_dialog.setup(story)
	_dialog.add_notification()
	_dialog.update_pattern(0, "*_affinity")
	assert_eq(story.notifications[0].pattern, "*_affinity")


func test_update_message() -> void:
	var story = _make_story()
	_dialog.setup(story)
	_dialog.add_notification()
	_dialog.update_message(0, "Le personnage s'en souviendra")
	assert_eq(story.notifications[0].message, "Le personnage s'en souviendra")


func test_update_pattern_invalid_index() -> void:
	var story = _make_story()
	_dialog.setup(story)
	_dialog.add_notification()
	_dialog.update_pattern(-1, "test")
	_dialog.update_pattern(99, "test")
	assert_eq(story.notifications[0].pattern, "")


func test_update_message_invalid_index() -> void:
	var story = _make_story()
	_dialog.setup(story)
	_dialog.add_notification()
	_dialog.update_message(-1, "test")
	_dialog.update_message(99, "test")
	assert_eq(story.notifications[0].message, "")


func test_add_notification_without_story() -> void:
	_dialog.add_notification()
	assert_eq(_dialog.get_notification_count(), 0)


func test_remove_notification_without_story() -> void:
	_dialog.remove_notification(0)
	assert_eq(_dialog.get_notification_count(), 0)
