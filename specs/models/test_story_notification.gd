extends GutTest

## Tests du modèle StoryNotification (pattern glob + message).

const StoryNotification = preload("res://src/models/story_notification.gd")

var _notif: RefCounted

func before_each() -> void:
	_notif = StoryNotification.new()


# --- Champs par défaut ---

func test_default_pattern_is_empty() -> void:
	assert_eq(_notif.pattern, "")

func test_default_message_is_empty() -> void:
	assert_eq(_notif.message, "")


# --- matches() : pattern "*_affinity" ---

func test_matches_wildcard_prefix() -> void:
	_notif.pattern = "*_affinity"
	assert_true(_notif.matches("mme_girard_affinity"))

func test_matches_wildcard_short_prefix() -> void:
	_notif.pattern = "*_affinity"
	assert_true(_notif.matches("mary_affinity"))

func test_matches_wildcard_exact_suffix() -> void:
	_notif.pattern = "*_affinity"
	assert_true(_notif.matches("_affinity"))

func test_no_match_different_suffix() -> void:
	_notif.pattern = "*_affinity"
	assert_false(_notif.matches("score"))

func test_no_match_partial_suffix() -> void:
	_notif.pattern = "*_affinity"
	assert_false(_notif.matches("mme_girard_affinity_extra"))

# --- matches() : pattern exact ---

func test_matches_exact_pattern() -> void:
	_notif.pattern = "score"
	assert_true(_notif.matches("score"))

func test_no_match_exact_different() -> void:
	_notif.pattern = "score"
	assert_false(_notif.matches("score2"))

func test_no_match_exact_prefix() -> void:
	_notif.pattern = "score"
	assert_false(_notif.matches("high_score"))

# --- matches() : pattern "?_?" ---

func test_matches_single_char_wildcard() -> void:
	_notif.pattern = "?_?"
	assert_true(_notif.matches("a_b"))

func test_no_match_single_char_too_long() -> void:
	_notif.pattern = "?_?"
	assert_false(_notif.matches("ab_b"))

# --- matches() : pattern avec caractères regex spéciaux ---

func test_matches_dot_escaped() -> void:
	_notif.pattern = "var.name"
	assert_false(_notif.matches("varXname"))  # le . doit être littéral

func test_matches_dot_literal() -> void:
	_notif.pattern = "var.name"
	assert_true(_notif.matches("var.name"))

func test_matches_plus_escaped() -> void:
	_notif.pattern = "score+"
	assert_false(_notif.matches("scoree"))  # + est littéral
	assert_true(_notif.matches("score+"))

# --- matches() : pattern vide ---

func test_empty_pattern_matches_empty_string() -> void:
	_notif.pattern = ""
	assert_true(_notif.matches(""))

func test_empty_pattern_no_match_nonempty() -> void:
	_notif.pattern = ""
	assert_false(_notif.matches("anything"))

# --- to_dict() ---

func test_to_dict_contains_pattern() -> void:
	_notif.pattern = "*_affinity"
	_notif.message = "Le personnage s'en souviendra"
	var d = _notif.to_dict()
	assert_eq(d["pattern"], "*_affinity")

func test_to_dict_contains_message() -> void:
	_notif.pattern = "*_affinity"
	_notif.message = "Le personnage s'en souviendra"
	var d = _notif.to_dict()
	assert_eq(d["message"], "Le personnage s'en souviendra")

# --- from_dict() ---

func test_from_dict_restores_pattern() -> void:
	var d = {"pattern": "*_affinity", "message": "Souvenir"}
	var n = StoryNotification.from_dict(d)
	assert_eq(n.pattern, "*_affinity")

func test_from_dict_restores_message() -> void:
	var d = {"pattern": "*_affinity", "message": "Souvenir"}
	var n = StoryNotification.from_dict(d)
	assert_eq(n.message, "Souvenir")

func test_from_dict_missing_fields_defaults() -> void:
	var n = StoryNotification.from_dict({})
	assert_eq(n.pattern, "")
	assert_eq(n.message, "")

# --- Round-trip ---

func test_roundtrip_to_and_from_dict() -> void:
	_notif.pattern = "health_*"
	_notif.message = "Santé modifiée"
	var d = _notif.to_dict()
	var n2 = StoryNotification.from_dict(d)
	assert_eq(n2.pattern, _notif.pattern)
	assert_eq(n2.message, _notif.message)
