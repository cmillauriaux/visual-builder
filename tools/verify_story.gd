## Vérifie qu'une histoire se charge et passe le vérificateur.
## Usage: godot --headless --path . -s tools/verify_story.gd -- --story-path=stories/mon-histoire
## Si --story-path n'est pas fourni, vérifie toutes les histoires dans stories/

extends SceneTree

const StorySaver = preload("res://src/persistence/story_saver.gd")
const StoryVerifier = preload("res://src/services/story_verifier.gd")


func _init():
	var story_path := _parse_story_path()

	if story_path.is_empty():
		_verify_all_stories()
	else:
		var success = _verify_story(story_path)
		quit(0 if success else 1)


func _parse_story_path() -> String:
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--story-path="):
			var rel_path = arg.substr("--story-path=".length())
			return ProjectSettings.globalize_path("res://" + rel_path)
	return ""


func _verify_all_stories():
	var base_dir = ProjectSettings.globalize_path("res://stories")
	var dir = DirAccess.open(base_dir)
	if dir == null:
		print("❌ Impossible d'ouvrir le répertoire stories/")
		quit(1)
		return

	var all_success := true
	var story_dirs: Array[String] = []

	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			story_dirs.append(base_dir + "/" + entry)
		entry = dir.get_next()
	dir.list_dir_end()

	if story_dirs.is_empty():
		print("Aucune histoire trouvée dans stories/")
		quit(0)
		return

	print("=== Vérification de " + str(story_dirs.size()) + " histoire(s) ===")
	print("")

	for path in story_dirs:
		if not _verify_story(path):
			all_success = false
		print("")

	if all_success:
		print("🏆 Toutes les histoires sont valides!")
	else:
		print("⚠️  Certaines histoires présentent des problèmes.")

	quit(0 if all_success else 1)


func _verify_story(story_path: String) -> bool:
	print("=== Chargement de l'histoire : " + story_path + " ===")
	var story = StorySaver.load_story(story_path)

	if story == null:
		print("❌ ERREUR: Impossible de charger l'histoire depuis : " + story_path)
		return false

	print("✅ Histoire chargée : " + story.title)
	print("   Auteur    : " + story.author)
	print("   Chapitres : " + str(story.chapters.size()))
	var total_scenes := 0
	var total_seqs := 0
	var total_conds := 0
	for ch in story.chapters:
		print("   📖 " + ch.chapter_name + " (" + str(ch.scenes.size()) + " scènes)")
		for sc in ch.scenes:
			total_scenes += 1
			total_seqs += sc.sequences.size()
			if sc.get("conditions") != null:
				total_conds += sc.conditions.size()
			print("      🎬 " + sc.scene_name + " — " + str(sc.sequences.size()) + " séq, " + str(sc.conditions.size() if sc.get("conditions") != null else 0) + " cond")
	print("   Scènes total  : " + str(total_scenes))
	print("   Séquences     : " + str(total_seqs))
	print("   Conditions    : " + str(total_conds))
	print("   Variables     : " + str(story.variables.size()))
	for v in story.variables:
		print("     - " + v.var_name + " = " + v.initial_value)

	print("")
	print("=== Vérification de l'histoire ===")
	var verifier = StoryVerifier.new()
	var report = verifier.verify(story)

	print("Résultat global : " + ("✅ SUCCÈS" if report["success"] else "❌ ÉCHEC"))
	print("Noeuds total    : " + str(report["all_nodes"]))
	print("Noeuds visités  : " + str(report["visited_nodes"]))
	print("Parcours totaux : " + str(report["total_runs"]))

	if report["orphan_nodes"].size() > 0:
		print("⚠️  Noeuds orphelins : " + str(report["orphan_nodes"].size()))
		for orphan in report["orphan_nodes"]:
			print("   - " + orphan["name"] + " (" + orphan["chapter"] + " / " + orphan["scene"] + ")")
	else:
		print("Orphelins       : aucun ✅")

	print("")
	print("=== Détail des parcours ===")
	for run in report["runs"]:
		var status = "✅" if run["is_valid"] else "❌"
		print(status + " Run " + str(run["run_index"]) + " → " + run["ending_reason"] + " (" + str(run["path"].size()) + " étapes)")
		for step in run["path"]:
			var prefix = "  "
			if step["type"] == "choice":
				prefix = "    ↳ "
			var info = " [choix " + str(step.get("choice_index", "")) + "]" if step["type"] == "choice" else ""
			print(prefix + "[" + step["type"] + "] " + step["name"] + info)

	if report["success"]:
		print("")
		print("🏆 L'histoire est valide et peut être jouée!")
	else:
		print("")
		print("⚠️  L'histoire présente des problèmes à corriger.")

	return report["success"]
