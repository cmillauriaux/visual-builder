extends SceneTree

## Test d'intégration PlayFab — appels HTTP réels (standalone, sans GUT).
## Lance: godot --headless --path . -s specs/services/test_playfab_integration.gd

const TITLE_ID = "F7499"
const TIMEOUT_SEC = 15.0

var _service: Node
var _tests_passed := 0
var _tests_failed := 0


func _init():
	print("\n=== PlayFab Integration Test (TitleID: %s) ===" % TITLE_ID)
	print("Endpoint: Event/WriteEvents (1 event per request)\n")
	var Script = load("res://plugins/playfab_analytics/playfab_analytics_service.gd")
	_service = Script.new()
	_service.name = "PlayFabIntegration"
	root.add_child(_service)
	_service.configure(TITLE_ID, true)
	_run_tests.call_deferred()


func _run_tests():
	await _test_login()
	if _service._logged_in:
		await _test_send_events()
	_print_results()
	quit()


func _test_login():
	print("--- Test 1: Login anonyme ---")
	_service.login_anonymous()
	var elapsed := 0.0
	while not _service._logged_in and elapsed < TIMEOUT_SEC:
		await create_timer(0.1).timeout
		elapsed += 0.1
		if not _service._pending_login and not _service._logged_in:
			break

	if _service._logged_in:
		_pass("Login réussi — Entity ID: %s, Type: %s" % [_service._entity_id, _service._entity_type])
	else:
		_fail("Login échoué après %.1fs" % elapsed)


func _test_send_events():
	print("\n--- Test 2: Envoi de 3 événements (1 requête chacun) ---")

	_service.track_event("integration_test_sequence_entered", {
		"chapter": "chapter_test",
		"scene": "scene_test",
		"sequence": "sequence_test",
		"timestamp": Time.get_datetime_string_from_system(true),
	})
	_service.track_event("integration_test_choice_made", {
		"choice_label": "Option A",
		"sequence": "sequence_test",
		"timestamp": Time.get_datetime_string_from_system(true),
	})
	_service.track_event("integration_test_story_started", {
		"story_name": "integration_test",
		"timestamp": Time.get_datetime_string_from_system(true),
	})

	var queue_size = _service.get_event_queue().size()
	if queue_size == 3:
		_pass("3 événements en queue")
	else:
		_fail("Queue attendue: 3, obtenue: %d" % queue_size)

	# Flush — envoie 3 requêtes HTTP parallèles
	_service.flush()
	_pass("Flush lancé — %d requêtes en cours" % _service._pending_events)

	# Attendre que toutes les requêtes soient terminées
	var elapsed := 0.0
	while _service._pending_events > 0 and elapsed < TIMEOUT_SEC:
		await create_timer(0.1).timeout
		elapsed += 0.1

	if _service._pending_events == 0:
		_pass("Toutes les requêtes terminées en %.1fs" % elapsed)
	else:
		_fail("Timeout — %d requêtes encore en cours" % _service._pending_events)

	if _service.get_event_queue().size() == 0:
		_pass("Queue vidée — 3 événements envoyés")
	else:
		_fail("Queue non vide: %d restants" % _service.get_event_queue().size())

	print("\n  → Vérifiez dans PlayFab PlayStream: https://developer.playfab.com/")
	print("  → Cherchez 3 événements custom.visualbuilder.integration_test_*")


func _pass(msg: String):
	_tests_passed += 1
	print("  ✓ PASS: %s" % msg)


func _fail(msg: String):
	_tests_failed += 1
	print("  ✗ FAIL: %s" % msg)


func _print_results():
	print("\n=== Résultats ===")
	print("  Passés: %d" % _tests_passed)
	print("  Échoués: %d" % _tests_failed)
	if _tests_failed == 0:
		print("  → TOUT OK ✓")
	else:
		print("  → ÉCHECS DÉTECTÉS ✗")
	print("")
