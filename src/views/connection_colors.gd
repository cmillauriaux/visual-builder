extends RefCounted

## Mappe les types de connexion vers leurs couleurs d'affichage.

static func get_color(type: String) -> Color:
	match type:
		"chapter":   return Color(0.4, 0.6, 1.0)
		"scene":     return Color(0.4, 1.0, 0.6)
		"sequence":  return Color(1.0, 0.8, 0.4)
		"condition": return Color(0.8, 0.4, 1.0)
		"ending":    return Color(1.0, 0.4, 0.4)
	return Color.WHITE
