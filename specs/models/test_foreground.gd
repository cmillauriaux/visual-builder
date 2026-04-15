extends GutTest

const Foreground = preload("res://src/models/foreground.gd")

# Tests pour le modèle Foreground

func test_create_foreground():
	var fg = Foreground.new()
	fg.fg_name = "Héros"
	fg.image = "personnage-a.png"
	assert_eq(fg.fg_name, "Héros")
	assert_eq(fg.image, "personnage-a.png")

func test_default_values():
	var fg = Foreground.new()
	assert_ne(fg.uuid, "", "UUID doit être généré automatiquement")
	assert_eq(fg.fg_name, "")
	assert_eq(fg.image, "")
	assert_eq(fg.z_order, 0)
	assert_eq(fg.opacity, 1.0)
	assert_eq(fg.flip_h, false)
	assert_eq(fg.flip_v, false)
	assert_eq(fg.scale, 1.0)
	assert_eq(fg.anchor_bg, Vector2(0.5, 0.5))
	assert_eq(fg.anchor_fg, Vector2(0.5, 1.0))
	assert_eq(fg.transition_type, "none")
	assert_eq(fg.transition_duration, 0.5)

func test_uuid_is_unique():
	var fg1 = Foreground.new()
	var fg2 = Foreground.new()
	assert_ne(fg1.uuid, fg2.uuid, "Chaque foreground doit avoir un UUID unique")

func test_opacity_clamped():
	var fg = Foreground.new()
	fg.opacity = 1.5
	assert_eq(fg.opacity, 1.0, "L'opacité doit être clampée à 1.0")
	fg.opacity = -0.5
	assert_eq(fg.opacity, 0.0, "L'opacité doit être clampée à 0.0")
	fg.opacity = 0.5
	assert_eq(fg.opacity, 0.5)

func test_scale_positive():
	var fg = Foreground.new()
	fg.scale = 2.0
	assert_eq(fg.scale, 2.0)
	fg.scale = 0.0
	assert_eq(fg.scale, 0.0)

func test_anchor_values():
	var fg = Foreground.new()
	fg.anchor_bg = Vector2(0.5, 0.8)
	fg.anchor_fg = Vector2(0.5, 1.0)
	assert_eq(fg.anchor_bg, Vector2(0.5, 0.8))
	assert_eq(fg.anchor_fg, Vector2(0.5, 1.0))

func test_to_dict():
	var fg = Foreground.new()
	fg.uuid = "fg-001"
	fg.fg_name = "Héros"
	fg.image = "personnage-a.png"
	fg.z_order = 1
	fg.opacity = 0.8
	fg.flip_h = true
	fg.flip_v = false
	fg.scale = 1.5
	fg.anchor_bg = Vector2(0.5, 0.8)
	fg.anchor_fg = Vector2(0.5, 1.0)
	var d = fg.to_dict()
	assert_eq(d["uuid"], "fg-001")
	assert_eq(d["name"], "Héros")
	assert_eq(d["image"], "personnage-a.png")
	assert_eq(d["z_order"], 1)
	assert_almost_eq(d["opacity"], 0.8, 0.001)
	assert_eq(d["flip_h"], true)
	assert_eq(d["flip_v"], false)
	assert_eq(d["scale"], 1.5)
	assert_eq(d["anchor_bg"]["x"], 0.5)
	assert_almost_eq(d["anchor_bg"]["y"], 0.8, 0.001)
	assert_eq(d["anchor_fg"]["x"], 0.5)
	assert_eq(d["anchor_fg"]["y"], 1.0)

func test_from_dict():
	var d = {
		"uuid": "fg-001",
		"name": "Héros",
		"image": "personnage-a.png",
		"z_order": 1,
		"opacity": 0.8,
		"flip_h": true,
		"flip_v": false,
		"scale": 1.5,
		"anchor_bg": {"x": 0.5, "y": 0.8},
		"anchor_fg": {"x": 0.5, "y": 1.0}
	}
	var fg = Foreground.from_dict(d)
	assert_eq(fg.uuid, "fg-001")
	assert_eq(fg.fg_name, "Héros")
	assert_eq(fg.image, "personnage-a.png")
	assert_eq(fg.z_order, 1)
	assert_eq(fg.opacity, 0.8)
	assert_eq(fg.flip_h, true)
	assert_eq(fg.flip_v, false)
	assert_eq(fg.scale, 1.5)
	assert_eq(fg.anchor_bg, Vector2(0.5, 0.8))
	assert_eq(fg.anchor_fg, Vector2(0.5, 1.0))

func test_from_dict_with_defaults():
	var d = {"uuid": "fg-002", "name": "Test"}
	var fg = Foreground.from_dict(d)
	assert_eq(fg.uuid, "fg-002")
	assert_eq(fg.fg_name, "Test")
	assert_eq(fg.z_order, 0)
	assert_eq(fg.opacity, 1.0)
	assert_eq(fg.flip_h, false)
	assert_eq(fg.flip_v, false)
	assert_eq(fg.scale, 1.0)
	assert_eq(fg.transition_type, "none")
	assert_eq(fg.transition_duration, 0.5)

# --- Tests transition_type ---

func test_transition_type_default():
	var fg = Foreground.new()
	assert_eq(fg.transition_type, "none")

func test_transition_type_valid_values():
	var fg = Foreground.new()
	for t in ["none", "fade"]:
		fg.transition_type = t
		assert_eq(fg.transition_type, t)

func test_transition_type_invalid_falls_back():
	var fg = Foreground.new()
	fg.transition_type = "invalid"
	assert_eq(fg.transition_type, "none", "Valeur invalide doit être ignorée")

# --- Tests transition_duration ---

func test_transition_duration_default():
	var fg = Foreground.new()
	assert_eq(fg.transition_duration, 0.5)

func test_transition_duration_clamped_min():
	var fg = Foreground.new()
	fg.transition_duration = 0.01
	assert_eq(fg.transition_duration, 0.1, "Durée minimum = 0.1")

func test_transition_duration_clamped_max():
	var fg = Foreground.new()
	fg.transition_duration = 10.0
	assert_eq(fg.transition_duration, 5.0, "Durée maximum = 5.0")

func test_transition_duration_valid():
	var fg = Foreground.new()
	fg.transition_duration = 1.5
	assert_eq(fg.transition_duration, 1.5)

# --- Tests sérialisation transition ---

func test_to_dict_includes_transition():
	var fg = Foreground.new()
	fg.uuid = "fg-trans"
	fg.transition_type = "fade"
	fg.transition_duration = 1.0
	var d = fg.to_dict()
	assert_eq(d["transition_type"], "fade")
	assert_eq(d["transition_duration"], 1.0)

func test_from_dict_with_transition():
	var d = {
		"uuid": "fg-trans",
		"name": "Test",
		"transition_type": "fade",
		"transition_duration": 2.0
	}
	var fg = Foreground.from_dict(d)
	assert_eq(fg.transition_type, "fade")
	assert_eq(fg.transition_duration, 2.0)

func test_crossfade_falls_back_to_none():
	var fg = Foreground.new()
	fg.transition_type = "crossfade"
	assert_eq(fg.transition_type, "none", "crossfade n'est plus valide, doit retomber sur none")

func test_from_dict_crossfade_falls_back():
	var d = {
		"uuid": "fg-legacy",
		"name": "Legacy",
		"transition_type": "crossfade",
		"transition_duration": 1.0
	}
	var fg = Foreground.from_dict(d)
	assert_eq(fg.transition_type, "none", "crossfade dans les anciennes données doit retomber sur none")

func test_from_dict_transition_defaults():
	var d = {"uuid": "fg-003", "name": "NoTrans"}
	var fg = Foreground.from_dict(d)
	assert_eq(fg.transition_type, "none")
	assert_eq(fg.transition_duration, 0.5)


# --- Tests champs animation ---

func test_anim_default_values():
	var fg = Foreground.new()
	assert_eq(fg.anim_speed, 1.0)
	assert_eq(fg.anim_reverse, false)
	assert_eq(fg.anim_loop, true)
	assert_eq(fg.anim_reverse_loop, false)

func test_anim_speed_clamped_min():
	var fg = Foreground.new()
	fg.anim_speed = 0.0
	assert_eq(fg.anim_speed, 0.1, "anim_speed minimum = 0.1")

func test_anim_speed_clamped_max():
	var fg = Foreground.new()
	fg.anim_speed = 10.0
	assert_eq(fg.anim_speed, 4.0, "anim_speed maximum = 4.0")

func test_anim_speed_valid():
	var fg = Foreground.new()
	fg.anim_speed = 2.0
	assert_eq(fg.anim_speed, 2.0)

func test_to_dict_excludes_anim_fields_for_static_image():
	var fg = Foreground.new()
	fg.image = "assets/foregrounds/hero.png"
	var d = fg.to_dict()
	assert_false(d.has("anim_speed"), "champs anim absents pour PNG statique")
	assert_false(d.has("anim_reverse"))
	assert_false(d.has("anim_loop"))
	assert_false(d.has("anim_reverse_loop"))

func test_to_dict_includes_anim_fields_for_apng():
	var fg = Foreground.new()
	fg.image = "assets/foregrounds/character.apng"
	fg.anim_speed = 2.0
	fg.anim_reverse = true
	fg.anim_loop = false
	fg.anim_reverse_loop = true
	var d = fg.to_dict()
	assert_eq(d["anim_speed"], 2.0)
	assert_eq(d["anim_reverse"], true)
	assert_eq(d["anim_loop"], false)
	assert_eq(d["anim_reverse_loop"], true)

func test_from_dict_anim_fields():
	var d = {
		"uuid": "fg-anim",
		"name": "AnimChar",
		"image": "assets/foregrounds/character.apng",
		"anim_speed": 0.5,
		"anim_reverse": true,
		"anim_loop": false,
		"anim_reverse_loop": true,
	}
	var fg = Foreground.from_dict(d)
	assert_eq(fg.anim_speed, 0.5)
	assert_eq(fg.anim_reverse, true)
	assert_eq(fg.anim_loop, false)
	assert_eq(fg.anim_reverse_loop, true)

func test_from_dict_anim_defaults_when_missing():
	var d = {"uuid": "fg-anim", "name": "AnimChar", "image": "character.apng"}
	var fg = Foreground.from_dict(d)
	assert_eq(fg.anim_speed, 1.0)
	assert_eq(fg.anim_reverse, false)
	assert_eq(fg.anim_loop, true)
	assert_eq(fg.anim_reverse_loop, false)
