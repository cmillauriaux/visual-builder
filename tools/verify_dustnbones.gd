## Vérifie que l'histoire "DustNBones" se charge et passe le vérificateur.
## Usage: godot --headless --path . -s tools/verify_dustnbones.gd

extends SceneTree

const StorySaver = preload("res://src/persistence/story_saver.gd")
const StoryVerifier = preload("res://src/services/story_verifier.gd")


func _init():
	var story_path = "/Users/cedric/Stories/DustNBones"

	print("=== Chargement de l'histoire ===")
	var story = StorySaver.load_story(story_path)

	if story == null:
		print("❌ ERREUR: Impossible de charger l'histoire depuis : " + story_path)
		quit(1)
		return

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
	quit(0 if report["success"] else 1)
