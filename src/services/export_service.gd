extends RefCounted

## Service gérant l'exécution de l'exportation des histoires vers des jeux standalone.
## Encapsule l'appel au script shell et l'analyse des logs d'erreur.

class_name ExportService

## Résultat d'une tentative d'exportation.
class ExportResult:
	var success: bool = false
	var output_path: String = ""
	var log_path: String = ""
	var error_message: String = ""

	func _init(p_success: bool, p_output_path: String, p_log_path: String, p_error: String = "") -> void:
		success = p_success
		output_path = p_output_path
		log_path = p_log_path
		error_message = p_error


## Exécute l'exportation pour une story donnée.
func export_story(story: RefCounted, platform: String, output_path: String, story_path: String) -> ExportResult:
	if story == null:
		return ExportResult.new(false, output_path, "", "Aucune histoire chargée.")

	var game_name = story.menu_title if story.menu_title != "" else story.title
	var script_path = ProjectSettings.globalize_path("res://scripts/export_story.sh")
	
	# Si story_path est vide (story non sauvegardée), on ne peut pas exporter
	if story_path == "":
		return ExportResult.new(false, output_path, "", "Veuillez sauvegarder l'histoire avant de l'exporter.")

	var args = [story_path, "-p", platform, "-n", game_name, "-o", output_path]
	var output = []
	var exit_code = OS.execute(script_path, args, output, true)
	
	var log_path = output_path + "/export.log"
	
	if exit_code == 0:
		return ExportResult.new(true, output_path, log_path)
	else:
		var error_reason = extract_export_error(log_path)
		return ExportResult.new(false, output_path, log_path, error_reason)


## Analyse le fichier de log pour en extraire la raison précise de l'échec.
func extract_export_error(log_path: String) -> String:
	var file = FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		return "L'export a échoué (log introuvable)."
	
	var content = file.get_as_text()
	file.close()
	
	var lines = content.split("
")
	var reasons := []
	var capture_next := false
	
	for line in lines:
		var stripped = line.strip_edges()
		# Nettoyage des codes ANSI (couleurs terminal)
		var clean = _strip_ansi_codes(stripped)
		
		if clean.find("due to configuration errors:") >= 0:
			capture_next = true
			continue
			
		if capture_next and clean != "" and not clean.begins_with("at:"):
			reasons.append(clean)
			capture_next = false
			
		if clean.find("ERREUR:") >= 0 and clean.find("due to configuration") < 0 and clean.find("Project export") < 0:
			var msg = clean.replace("ERROR:", "").replace("ERREUR:", "").strip_edges()
			if msg != "" and not msg.begins_with("at:"):
				reasons.append(msg)
				
	if reasons.is_empty():
		return "L'export a échoué."
		
	return "
".join(reasons)


func _strip_ansi_codes(text: String) -> String:
	var clean = text
	while clean.find("\u001b[") >= 0:
		var start = clean.find("\u001b[")
		var end = clean.find("m", start)
		if end >= 0:
			clean = clean.substr(0, start) + clean.substr(end + 1)
		else:
			break
	return clean
