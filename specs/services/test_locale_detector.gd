extends GutTest


# --- resolve_language ---

func test_resolve_returns_detected_when_available():
	var result = LocaleDetector.resolve_language("en", ["fr", "en"], "fr")
	assert_eq(result, "en")


func test_resolve_returns_detected_when_exact_match():
	var result = LocaleDetector.resolve_language("fr", ["fr", "en"], "fr")
	assert_eq(result, "fr")


func test_resolve_fallback_to_en_when_detected_not_available():
	var result = LocaleDetector.resolve_language("de", ["fr", "en"], "fr")
	assert_eq(result, "en")


func test_resolve_fallback_to_default_when_no_en():
	var result = LocaleDetector.resolve_language("de", ["fr", "ja"], "fr")
	assert_eq(result, "fr")


func test_resolve_fallback_to_en_when_detected_empty():
	var result = LocaleDetector.resolve_language("", ["fr", "en"], "fr")
	assert_eq(result, "en")


func test_resolve_fallback_to_default_when_detected_empty_and_no_en():
	var result = LocaleDetector.resolve_language("", ["fr"], "fr")
	assert_eq(result, "fr")


func test_resolve_single_language_returns_default():
	var result = LocaleDetector.resolve_language("en", ["fr"], "fr")
	assert_eq(result, "fr")


func test_resolve_detected_is_default():
	var result = LocaleDetector.resolve_language("ja", ["ja", "en"], "ja")
	assert_eq(result, "ja")


func test_resolve_en_is_default_and_detected_unavailable():
	var result = LocaleDetector.resolve_language("de", ["en", "fr"], "en")
	assert_eq(result, "en")


# --- detect_locale ---

func test_detect_locale_returns_string():
	var result = LocaleDetector.detect_locale()
	assert_typeof(result, TYPE_STRING)


func test_detect_locale_length_two_or_empty():
	var result = LocaleDetector.detect_locale()
	assert_true(result == "" or result.length() == 2,
		"detect_locale doit retourner un code 2 lettres ou une chaîne vide, reçu: '%s'" % result)


func test_detect_locale_lowercase():
	var result = LocaleDetector.detect_locale()
	if result != "":
		assert_eq(result, result.to_lower(),
			"Le code locale doit être en minuscules")


# --- _detect_desktop_locale ---

func test_detect_desktop_locale_returns_string() -> void:
	var result = LocaleDetector._detect_desktop_locale()
	assert_typeof(result, TYPE_STRING)

func test_detect_desktop_locale_two_chars_or_empty() -> void:
	var result = LocaleDetector._detect_desktop_locale()
	assert_true(result == "" or result.length() == 2)




