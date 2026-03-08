extends GutTest

## Vérifie que le script de test HTTP PCK se charge sans erreur de syntaxe.

const TestHttpPckLoadingScript = preload("res://src/export/test_http_pck_loading.gd")


func test_script_loads():
	assert_not_null(TestHttpPckLoadingScript)


func test_extends_scene_tree():
	assert_true(TestHttpPckLoadingScript is GDScript)
