extends GutTest

## Diagnostic : pourquoi les foregrounds n'apparaissent pas dans la timeline.

var DialogueTimelineItemScript = load("res://src/ui/sequence/dialogue_timeline_item.gd")
var DialogueScript = load("res://src/models/dialogue.gd")
var ForegroundScript = load("res://src/models/foreground.gd")
const TextureLoaderScript = preload("res://src/ui/shared/texture_loader.gd")

func _create_dlg() -> RefCounted:
	var dlg = DialogueScript.new()
	dlg.character = "Test"
	dlg.text = "Hello"
	return dlg

func _create_fg(image: String = "res://icon.svg", anchor_bg := Vector2(0.5, 0.5), anchor_fg := Vector2(0.5, 1.0), s := 1.0) -> RefCounted:
	var fg = ForegroundScript.new()
	fg.image = image
	fg.anchor_bg = anchor_bg
	fg.anchor_fg = anchor_fg
	fg.scale = s
	return fg


func test_step1_fg_images_populated_after_setup() -> void:
	gut.p("=== STEP 1: _fg_images rempli par setup() ===")
	var fg = _create_fg()
	var item = DialogueTimelineItemScript.new()
	item.setup(0, _create_dlg(), false, 1, "", [fg])

	gut.p("  AVANT add_child: _fg_images.size() = %d" % item._fg_images.size())
	assert_eq(item._fg_images.size(), 1, "_fg_images doit avoir 1 entrée")
	if item._fg_images.size() > 0:
		gut.p("  _fg_images[0] = %s" % str(item._fg_images[0]))

	add_child_autofree(item)
	await get_tree().process_frame

	gut.p("  APRÈS _ready: _fg_images.size() = %d" % item._fg_images.size())
	assert_eq(item._fg_images.size(), 1, "_fg_images doit rester intact après _ready")


func test_step2_texture_loading() -> void:
	gut.p("=== STEP 2: TextureLoader ===")
	gut.p("  base_dir = '%s'" % TextureLoaderScript.base_dir)

	var tex = TextureLoaderScript.load_texture("res://icon.svg")
	gut.p("  load_texture('res://icon.svg') → %s" % ("OK size=%s" % str(tex.get_size()) if tex else "NULL"))
	assert_not_null(tex, "icon.svg devrait charger")


func test_step3_preview_bg_has_fg_children() -> void:
	gut.p("=== STEP 3: _preview_bg enfants après _ready ===")
	var fg = _create_fg()
	var item = DialogueTimelineItemScript.new()
	item.setup(0, _create_dlg(), false, 1, "", [fg])
	add_child_autofree(item)
	await get_tree().process_frame

	assert_not_null(item._preview_bg, "_preview_bg ne doit pas être null")
	assert_not_null(item._preview_tex, "_preview_tex ne doit pas être null")

	var count = item._preview_bg.get_child_count()
	gut.p("  _preview_bg.get_child_count() = %d" % count)
	gut.p("  Attendu: _preview_tex(0) + _badge_label(1) + fg_rect(2) = 3")
	for i in range(count):
		var child = item._preview_bg.get_child(i)
		var info = "    [%d] %s class=%s pos=%s size=%s vis=%s" % [
			i, child.name, child.get_class(), str(child.position), str(child.size), str(child.visible)]
		if child is TextureRect:
			info += " tex=%s" % ("SET(%s)" % str(child.texture.get_size()) if child.texture else "NULL")
		gut.p(info)

	assert_eq(count, 3, "_preview_bg devrait avoir 3 enfants (bg_tex + badge + 1 fg_rect)")


func test_step4_fg_rect_position_visible() -> void:
	gut.p("=== STEP 4: Position/taille du fg_rect ===")
	var fg = _create_fg("res://icon.svg", Vector2(0.5, 0.8), Vector2(0.5, 1.0), 0.5)
	var item = DialogueTimelineItemScript.new()
	item.setup(0, _create_dlg(), false, 1, "res://icon.svg", [fg])
	add_child_autofree(item)
	await get_tree().process_frame

	if item._preview_bg.get_child_count() <= 2:
		fail_test("Pas de fg_rect trouvé dans _preview_bg")
		return

	var fg_rect = item._preview_bg.get_child(2)
	gut.p("  fg_rect pos=%s size=%s" % [str(fg_rect.position), str(fg_rect.size)])
	gut.p("  fg_rect min_size=%s" % str(fg_rect.custom_minimum_size))
	gut.p("  preview_bg size=%s" % str(item._preview_bg.size))

	var pw = 110.0
	var ph = 55.0
	var vis = (fg_rect.position.x + fg_rect.size.x > 0 and fg_rect.position.x < pw
		and fg_rect.position.y + fg_rect.size.y > 0 and fg_rect.position.y < ph)
	gut.p("  Partiellement visible dans 110x55? %s" % str(vis))
	assert_true(vis, "fg_rect devrait être visible dans le preview")


func test_step5_real_math_dustnbones() -> void:
	gut.p("=== STEP 5: Maths avec valeurs réelles DustNBones ===")
	# bg=1376x768, fg_tex=784x1312, scale=0.672, anchor_bg=(1.2,1.41), anchor_fg=(0.5,1.0)
	var bg_size = Vector2(1376, 768)
	var fg_tex_size = Vector2(784, 1312)
	var fg_scale = 0.672
	var anchor_bg = Vector2(1.20453, 1.40745)
	var anchor_fg = Vector2(0.5, 1.0)
	var canvas_ref = Vector2(1920, 1080)
	var preview_size = Vector2(110, 55)

	var fg_canvas_size = fg_tex_size * fg_scale
	var canvas_pos = anchor_bg * bg_size - anchor_fg * fg_canvas_size
	gut.p("  fg_canvas_size = %s" % str(fg_canvas_size))
	gut.p("  canvas_pos = %s" % str(canvas_pos))

	var preview_pos = canvas_pos * (preview_size / canvas_ref)
	var fg_preview_sz = fg_canvas_size * (preview_size.x / canvas_ref.x)
	gut.p("  preview_pos = %s" % str(preview_pos))
	gut.p("  fg_preview_sz = %s" % str(fg_preview_sz))

	var right = preview_pos.x + fg_preview_sz.x
	var bottom = preview_pos.y + fg_preview_sz.y
	gut.p("  Preview rect: (%.1f, %.1f) → (%.1f, %.1f)" % [preview_pos.x, preview_pos.y, right, bottom])
	var vis = preview_pos.x < preview_size.x and preview_pos.y < preview_size.y and right > 0 and bottom > 0
	gut.p("  Visible? %s" % str(vis))


func test_step6_two_foregrounds() -> void:
	gut.p("=== STEP 6: 2 foregrounds ===")
	var fg1 = _create_fg("res://icon.svg", Vector2(0.3, 0.5))
	var fg2 = _create_fg("res://icon.svg", Vector2(0.7, 0.5))
	var item = DialogueTimelineItemScript.new()
	item.setup(0, _create_dlg(), false, 2, "", [fg1, fg2])
	add_child_autofree(item)
	await get_tree().process_frame

	assert_eq(item._fg_images.size(), 2)
	if item._preview_bg:
		var count = item._preview_bg.get_child_count()
		gut.p("  _preview_bg children = %d (attendu: 4)" % count)
		assert_eq(count, 4, "tex_bg + badge + 2 fg_rects = 4")


func test_step7_real_external_texture_loading() -> void:
	gut.p("=== STEP 7: Chargement de vraies textures externes ===")
	var story_dir = "/Users/cedric/Stories/DustNBones"
	var fg_path = "assets/foregrounds/Jessy_profile_calm.png"
	var bg_path = "assets/backgrounds/bacgrkound_wasteland.png"

	# Sauvegarder et restaurer base_dir
	var old_base_dir = TextureLoaderScript.base_dir
	TextureLoaderScript.base_dir = story_dir

	gut.p("  base_dir = '%s'" % TextureLoaderScript.base_dir)

	# Tester le chargement du background
	var bg_tex = TextureLoaderScript.load_texture(bg_path)
	gut.p("  BG load_texture('%s') → %s" % [bg_path, "OK size=%s" % str(bg_tex.get_size()) if bg_tex else "NULL"])
	assert_not_null(bg_tex, "Background devrait charger")

	# Tester le chargement du foreground
	var fg_tex = TextureLoaderScript.load_texture(fg_path)
	gut.p("  FG load_texture('%s') → %s" % [fg_path, "OK size=%s" % str(fg_tex.get_size()) if fg_tex else "NULL"])
	assert_not_null(fg_tex, "Foreground devrait charger")

	TextureLoaderScript.base_dir = old_base_dir


func test_step8_real_data_full_pipeline() -> void:
	gut.p("=== STEP 8: Pipeline complète avec données réelles ===")
	var story_dir = "/Users/cedric/Stories/DustNBones"
	var fg_path = "assets/foregrounds/Jessy_profile_calm.png"
	var bg_path = "assets/backgrounds/bacgrkound_wasteland.png"

	var old_base_dir = TextureLoaderScript.base_dir
	TextureLoaderScript.base_dir = story_dir

	var fg = _create_fg(fg_path, Vector2(0.5, 0.8), Vector2(0.5, 1.0), 0.5)
	var item = DialogueTimelineItemScript.new()
	item.setup(0, _create_dlg(), false, 1, bg_path, [fg])
	add_child_autofree(item)
	await get_tree().process_frame

	gut.p("  _fg_images.size() = %d" % item._fg_images.size())
	assert_eq(item._fg_images.size(), 1)

	var count = item._preview_bg.get_child_count()
	gut.p("  _preview_bg children = %d" % count)
	for i in range(count):
		var child = item._preview_bg.get_child(i)
		var info = "    [%d] class=%s pos=%s size=%s" % [
			i, child.get_class(), str(child.position), str(child.size)]
		if child is TextureRect:
			info += " tex=%s" % ("SET(%s)" % str(child.texture.get_size()) if child.texture else "NULL")
		gut.p(info)

	assert_eq(count, 3, "Devrait avoir bg_tex + badge + fg_rect avec vraies textures")

	TextureLoaderScript.base_dir = old_base_dir


func test_step9_integration_seq_editor_timeline() -> void:
	gut.p("=== STEP 9: Intégration SequenceEditor + DialogueTimeline ===")
	var SequenceEditorScript = load("res://src/ui/sequence/sequence_editor.gd")
	var DialogueTimelineScript = load("res://src/ui/sequence/dialogue_timeline.gd")

	var old_base_dir = TextureLoaderScript.base_dir
	TextureLoaderScript.base_dir = "/Users/cedric/Stories/DustNBones"

	# Créer une séquence comme DustNBones
	var seq = SequenceModel.new()
	seq.background = "assets/backgrounds/bacgrkound_wasteland.png"

	# Foreground au niveau séquence
	var seq_fg = ForegroundScript.new()
	seq_fg.image = "assets/foregrounds/Jessy_profile_calm.png"
	seq_fg.anchor_bg = Vector2(0.5, 0.8)
	seq_fg.anchor_fg = Vector2(0.5, 1.0)
	seq_fg.scale = 0.5
	seq.foregrounds = [seq_fg]

	# Dialogue 0: a ses propres foregrounds
	var dlg0 = DialogueScript.new()
	dlg0.character = "Jessy"
	dlg0.text = "Premier dialogue"
	var dlg0_fg = ForegroundScript.new()
	dlg0_fg.image = "assets/foregrounds/Jessy_profile_calm.png"
	dlg0_fg.anchor_bg = Vector2(0.5, 0.8)
	dlg0_fg.anchor_fg = Vector2(0.5, 1.0)
	dlg0_fg.scale = 0.5
	dlg0.foregrounds = [dlg0_fg]
	seq.dialogues.append(dlg0)

	# Dialogue 1: hérite (foregrounds vide)
	var dlg1 = DialogueScript.new()
	dlg1.character = "Jessy"
	dlg1.text = "Dialogue hérité"
	seq.dialogues.append(dlg1)

	# Dialogue 2: hérite aussi
	var dlg2 = DialogueScript.new()
	dlg2.character = "Jessy"
	dlg2.text = "Encore hérité"
	seq.dialogues.append(dlg2)

	# Créer le SequenceEditor
	var seq_editor = SequenceEditorScript.new()
	add_child_autofree(seq_editor)
	seq_editor.load_sequence(seq)

	# Vérifier get_effective_foregrounds pour chaque dialogue
	for i in range(3):
		var eff = seq_editor.get_effective_foregrounds(i)
		gut.p("  dlg[%d] foregrounds.size()=%d effective.size()=%d inherited=%s" % [
			i, seq.dialogues[i].foregrounds.size(), eff.size(),
			str(seq_editor.is_dialogue_inheriting(i))])
		assert_gt(eff.size(), 0, "dlg[%d] devrait avoir des foregrounds effectifs" % i)

	# Créer le DialogueTimeline
	var timeline = DialogueTimelineScript.new()
	add_child_autofree(timeline)
	await get_tree().process_frame

	timeline.setup(seq_editor)
	await get_tree().process_frame
	await get_tree().process_frame

	# Vérifier chaque item de la timeline
	gut.p("  Timeline items: %d" % timeline._items.size())
	assert_eq(timeline._items.size(), 3)

	for i in range(timeline._items.size()):
		var item = timeline._items[i]
		var fg_count = item._fg_images.size()
		var child_count = item._preview_bg.get_child_count() if item._preview_bg else -1
		gut.p("  item[%d]: _fg_images=%d, _preview_bg.children=%d" % [i, fg_count, child_count])
		assert_gt(fg_count, 0, "item[%d] devrait avoir des _fg_images" % i)
		assert_gt(child_count, 2, "item[%d] devrait avoir des fg_rects dans _preview_bg" % i)

		# Détailler les enfants du preview
		if item._preview_bg:
			for j in range(child_count):
				var child = item._preview_bg.get_child(j)
				var info = "    item[%d] child[%d]: class=%s pos=%s size=%s" % [
					i, j, child.get_class(), str(child.position), str(child.size)]
				if child is TextureRect:
					info += " tex=%s" % ("SET" if child.texture else "NULL")
				gut.p(info)

	TextureLoaderScript.base_dir = old_base_dir
