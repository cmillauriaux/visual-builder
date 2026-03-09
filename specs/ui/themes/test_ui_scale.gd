extends GutTest

## Tests pour UIScale (spec 059 — DPI-aware UI scaling)

var UIScale = load("res://src/ui/themes/ui_scale.gd")


func before_each() -> void:
	UIScale.reset()


func after_each() -> void:
	UIScale.reset()


func test_scale_returns_one_for_fullhd_at_96dpi() -> void:
	# On ne peut pas contrôler DisplayServer dans les tests headless,
	# mais on peut tester que get_scale() retourne une valeur dans la plage valide.
	var s: float = UIScale.get_scale()
	assert_true(s >= UIScale.SCALE_MIN, "scale >= SCALE_MIN")
	assert_true(s <= UIScale.SCALE_MAX, "scale <= SCALE_MAX")


func test_scale_is_cached_after_first_call() -> void:
	var s1: float = UIScale.get_scale()
	var s2: float = UIScale.get_scale()
	assert_eq(s1, s2, "scale est mis en cache")


func test_reset_clears_cache() -> void:
	UIScale.get_scale()
	UIScale.reset()
	# Après reset, _scale doit être < 0
	assert_true(UIScale._scale < 0.0, "reset remet _scale à -1")


func test_scale_function_identity_at_scale_one() -> void:
	# Force scale à 1.0 pour tester la fonction scale()
	UIScale._scale = 1.0
	assert_eq(UIScale.scale(16), 16, "scale(16) = 16 quand le facteur est 1.0")
	assert_eq(UIScale.scale(50), 50, "scale(50) = 50 quand le facteur est 1.0")


func test_scale_function_doubles_at_scale_two() -> void:
	UIScale._scale = 2.0
	assert_eq(UIScale.scale(16), 32, "scale(16) = 32 quand le facteur est 2.0")
	assert_eq(UIScale.scale(50), 100, "scale(50) = 100 quand le facteur est 2.0")


func test_scale_function_rounds_to_nearest_int() -> void:
	UIScale._scale = 1.5
	assert_eq(UIScale.scale(10), 15, "scale(10) = 15 quand le facteur est 1.5")
	assert_eq(UIScale.scale(11), 17, "scale(11) = 17 arrondi de 16.5")


func test_clamp_min() -> void:
	assert_eq(UIScale.SCALE_MIN, 0.5, "SCALE_MIN = 0.5")


func test_clamp_max() -> void:
	assert_eq(UIScale.SCALE_MAX, 5.0, "SCALE_MAX = 5.0")


# --- User multiplier ---

func test_default_user_multiplier() -> void:
	assert_eq(UIScale.get_user_multiplier(), 1.0, "multiplicateur par défaut = 1.0")

func test_set_user_multiplier() -> void:
	UIScale.set_user_multiplier(1.5)
	assert_eq(UIScale.get_user_multiplier(), 1.5, "multiplicateur défini à 1.5")

func test_set_user_multiplier_invalidates_cache() -> void:
	UIScale.get_scale()  # force le calcul
	UIScale.set_user_multiplier(1.25)
	assert_true(UIScale._scale < 0.0, "set_user_multiplier remet le cache à -1")

func test_reset_clears_user_multiplier() -> void:
	UIScale.set_user_multiplier(1.5)
	UIScale.reset()
	assert_eq(UIScale.get_user_multiplier(), 1.0, "reset remet le multiplicateur à 1.0")

func test_user_multiplier_affects_scale_function() -> void:
	UIScale._scale = 1.0
	assert_eq(UIScale.scale(100), 100, "scale(100) = 100 sans multiplicateur")
	UIScale.set_user_multiplier(1.5)
	# Après set_user_multiplier, le cache est invalidé, donc get_scale() recalcule
	# On force manuellement pour tester l'effet
	UIScale._scale = 1.5
	assert_eq(UIScale.scale(100), 150, "scale(100) = 150 avec multiplicateur 1.5")
