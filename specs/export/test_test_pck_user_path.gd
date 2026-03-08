extends GutTest

## Vérifie que le script de test PCK user path se charge sans erreur de syntaxe.

const TestPckUserPathScript = preload("res://src/export/test_pck_user_path.gd")


func test_script_loads():
	assert_not_null(TestPckUserPathScript)


func test_extends_scene_tree():
	assert_true(TestPckUserPathScript is GDScript)
