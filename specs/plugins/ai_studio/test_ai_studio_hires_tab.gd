extends GutTest

const HiResTab = preload("res://plugins/ai_studio/ai_studio_hires_tab.gd")


func test_has_required_public_methods() -> void:
	var tab := HiResTab.new()
	assert_true(tab.has_method("initialize"))
	assert_true(tab.has_method("build_tab"))
	assert_true(tab.has_method("update_generate_button"))
	assert_true(tab.has_method("update_cfg_hint"))
	assert_true(tab.has_method("cancel_generation"))
	assert_true(tab.has_method("setup"))


func test_compute_backup_path_simple() -> void:
	# Fonction pure testable sans UI
	assert_eq(
		HiResTab._compute_backup_path("/story/assets/foregrounds/perso_001.png"),
		"/story/assets/foregrounds/perso_001_original.png"
	)


func test_compute_backup_path_with_underscores() -> void:
	assert_eq(
		HiResTab._compute_backup_path("/path/to/char_happy_v2.png"),
		"/path/to/char_happy_v2_original.png"
	)


func test_compute_backup_path_at_root() -> void:
	assert_eq(
		HiResTab._compute_backup_path("/img.png"),
		"//img_original.png"
	)


func test_cancel_generation_safe_when_no_client() -> void:
	# cancel_generation() ne doit pas crasher si aucun client actif
	var tab := HiResTab.new()
	# Simuler initialize minimal pour éviter null ref
	tab._url_input = LineEdit.new()
	tab._token_input = LineEdit.new()
	tab._neg_input = TextEdit.new()
	tab.cancel_generation()  # Ne doit pas lever d'erreur
	assert_null(tab._client)  # Le client reste null si aucune génération en cours
	tab._url_input.queue_free()
	tab._token_input.queue_free()
	tab._neg_input.queue_free()


func test_update_generate_button_disabled_when_no_source() -> void:
	var tab := HiResTab.new()
	var url_input := LineEdit.new()
	url_input.text = "http://localhost:8188"
	var token_input := LineEdit.new()
	var neg_input := TextEdit.new()
	tab._url_input = url_input
	tab._token_input = token_input
	tab._neg_input = neg_input
	var btn := Button.new()
	tab._generate_btn = btn
	tab._source_image_path = ""  # Pas de source
	tab.update_generate_button()
	assert_true(btn.disabled)
	url_input.queue_free()
	token_input.queue_free()
	neg_input.queue_free()
	btn.queue_free()


func test_update_generate_button_disabled_when_no_url() -> void:
	var tab := HiResTab.new()
	var url_input := LineEdit.new()
	url_input.text = ""  # Pas d'URL
	var token_input := LineEdit.new()
	var neg_input := TextEdit.new()
	tab._url_input = url_input
	tab._token_input = token_input
	tab._neg_input = neg_input
	var btn := Button.new()
	tab._generate_btn = btn
	tab._source_image_path = "/some/image.png"
	tab.update_generate_button()
	assert_true(btn.disabled)
	url_input.queue_free()
	token_input.queue_free()
	neg_input.queue_free()
	btn.queue_free()


func test_update_generate_button_enabled_when_url_and_source() -> void:
	var tab := HiResTab.new()
	var url_input := LineEdit.new()
	url_input.text = "http://localhost:8188"
	var token_input := LineEdit.new()
	var neg_input := TextEdit.new()
	tab._url_input = url_input
	tab._token_input = token_input
	tab._neg_input = neg_input
	var btn := Button.new()
	btn.disabled = true
	tab._generate_btn = btn
	tab._source_image_path = "/some/image.png"
	tab.update_generate_button()
	assert_false(btn.disabled)
	url_input.queue_free()
	token_input.queue_free()
	neg_input.queue_free()
	btn.queue_free()
