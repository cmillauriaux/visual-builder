extends GutTest

## Tests du signal notification_triggered dans StoryPlayController.

const StoryScript = preload("res://src/models/story.gd")
const StoryNotification = preload("res://src/models/story_notification.gd")
const VariableDefinitionScript = preload("res://src/models/variable_definition.gd")
const VariableEffectScript = preload("res://src/models/variable_effect.gd")
const StoryPlayControllerScript = preload("res://src/ui/play/story_play_controller.gd")

var _ctrl: Node
var _story: RefCounted
var _received_notifications: Array  # Array[String]

func before_each() -> void:
	_ctrl = Node.new()
	_ctrl.set_script(StoryPlayControllerScript)
	add_child(_ctrl)

	_story = StoryScript.new()
	_ctrl._story = _story

	_received_notifications = []
	_ctrl.notification_triggered.connect(func(msg): _received_notifications.append(msg))


func after_each() -> void:
	_ctrl.queue_free()


# --- Signal déclaré ---

func test_notification_triggered_signal_exists() -> void:
	assert_true(_ctrl.has_signal("notification_triggered"))


# --- _apply_effects sans notification ---

func test_no_notification_when_no_notifications_defined() -> void:
	_ctrl._variables = {"score": "0"}
	var effect = VariableEffectScript.new()
	effect.variable = "score"
	effect.operation = "set"
	effect.value = "5"
	_ctrl._apply_effects([effect])
	assert_eq(_received_notifications.size(), 0)


# --- _apply_effects avec notification qui correspond ---

func test_notification_emitted_when_variable_changes() -> void:
	var n = StoryNotification.new()
	n.pattern = "*_affinity"
	n.message = "Souvenir"
	_story.notifications.append(n)
	_ctrl._variables = {"mme_girard_affinity": "0"}
	var effect = VariableEffectScript.new()
	effect.variable = "mme_girard_affinity"
	effect.operation = "increment"
	effect.value = "1"
	_ctrl._apply_effects([effect])
	assert_eq(_received_notifications.size(), 1)
	assert_eq(_received_notifications[0], "Souvenir")


# --- _apply_effects : pas de signal si la valeur ne change pas ---

func test_no_notification_when_value_unchanged() -> void:
	var n = StoryNotification.new()
	n.pattern = "score"
	n.message = "Score modifié"
	_story.notifications.append(n)
	_ctrl._variables = {"score": "5"}
	var effect = VariableEffectScript.new()
	effect.variable = "score"
	effect.operation = "set"
	effect.value = "5"  # même valeur
	_ctrl._apply_effects([effect])
	assert_eq(_received_notifications.size(), 0)


# --- _apply_effects : plusieurs notifications pour un même effet ---

func test_multiple_notifications_for_same_variable() -> void:
	var n1 = StoryNotification.new()
	n1.pattern = "*_affinity"
	n1.message = "Souvenir A"
	var n2 = StoryNotification.new()
	n2.pattern = "mme_*"
	n2.message = "Souvenir B"
	_story.notifications.append(n1)
	_story.notifications.append(n2)
	_ctrl._variables = {"mme_girard_affinity": "0"}
	var effect = VariableEffectScript.new()
	effect.variable = "mme_girard_affinity"
	effect.operation = "set"
	effect.value = "10"
	_ctrl._apply_effects([effect])
	assert_eq(_received_notifications.size(), 2)


# --- _apply_effects : nouvelle variable créée ---

func test_notification_emitted_for_new_variable() -> void:
	var n = StoryNotification.new()
	n.pattern = "new_var"
	n.message = "Créée !"
	_story.notifications.append(n)
	_ctrl._variables = {}
	var effect = VariableEffectScript.new()
	effect.variable = "new_var"
	effect.operation = "set"
	effect.value = "1"
	_ctrl._apply_effects([effect])
	assert_eq(_received_notifications.size(), 1)


# --- _apply_effects : pas de notification pour les variables non modifiées ---

func test_no_notification_for_unchanged_other_variables() -> void:
	var n = StoryNotification.new()
	n.pattern = "score"
	n.message = "Score modifié"
	_story.notifications.append(n)
	_ctrl._variables = {"score": "5", "health": "100"}
	var effect = VariableEffectScript.new()
	effect.variable = "health"
	effect.operation = "set"
	effect.value = "90"
	_ctrl._apply_effects([effect])
	assert_eq(_received_notifications.size(), 0)


# --- _apply_effects : pas de signal si _story est null ---

func test_no_crash_when_story_is_null() -> void:
	_ctrl._story = null
	_ctrl._variables = {"score": "0"}
	var effect = VariableEffectScript.new()
	effect.variable = "score"
	effect.operation = "set"
	effect.value = "5"
	_ctrl._apply_effects([effect])
	assert_eq(_received_notifications.size(), 0)
