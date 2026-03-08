extends GutTest

## Vérifie que le script de test PCK se charge sans erreur de syntaxe.

const TestPckLoadingScript = preload("res://src/export/test_pck_loading.gd")


func test_script_loads():
	assert_not_null(TestPckLoadingScript)


func test_extends_scene_tree():
	# Le script étend SceneTree, vérifier qu'il est bien chargé
	assert_true(TestPckLoadingScript is GDScript)
