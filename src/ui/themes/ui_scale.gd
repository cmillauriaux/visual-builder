extends RefCounted

## Calcule le facteur d'échelle UI pour maintenir une taille physique constante
## sur tous les écrans (petits écrans, mobile, haute densité de pixels).
##
## Principe : sur un écran 1920×1080 à 96 DPI (référence), scale = 1.0.
## Sur un petit écran ou un écran haute densité, scale > 1.0 pour que les
## éléments UI gardent la même taille physique en millimètres.
##
## Formule : ui_scale = (logical_dpi / 96) / godot_canvas_scale
## où logical_dpi = screen_dpi / screen_scale (pour compenser le HiDPI/Retina)
## où godot_canvas_scale = min(phys_w / 1920, phys_h / 1080)

const DESIGN_WIDTH := 1920.0
const DESIGN_HEIGHT := 1080.0
const REFERENCE_DPI := 96.0
const SCALE_MIN := 0.5
const SCALE_MAX := 5.0

static var _scale: float = -1.0
static var _user_multiplier: float = 1.0


## Retourne le facteur d'échelle UI courant.
## Calculé une seule fois à la première utilisation.
static func get_scale() -> float:
	if _scale < 0.0:
		_scale = _compute_scale()
	return _scale


## Retourne `pixels` multiplié par le facteur d'échelle, arrondi à l'entier le plus proche.
static func scale(pixels: float) -> int:
	return roundi(pixels * get_scale())


## Définit le multiplicateur utilisateur (1.0 = petit, 1.25 = moyen, 1.5 = gros).
## Invalide le cache pour forcer un recalcul.
static func set_user_multiplier(multiplier: float) -> void:
	_user_multiplier = multiplier
	_scale = -1.0


## Retourne le multiplicateur utilisateur courant.
static func get_user_multiplier() -> float:
	return _user_multiplier


## Remet à zéro le cache (utile pour les tests).
static func reset() -> void:
	_scale = -1.0
	_user_multiplier = 1.0


static func _compute_scale() -> float:
	var win_size: Vector2i = DisplayServer.window_get_size()
	# window_get_size() returns logical pixels; screen_get_dpi() returns physical DPI.
	# Divide by screen_get_scale() to get the effective DPI in logical coordinates
	# (avoids double-counting HiDPI/Retina scaling that Godot handles transparently).
	var screen_scale: float = maxf(DisplayServer.screen_get_scale(), 1.0)
	var dpi: float = max(float(DisplayServer.screen_get_dpi()) / screen_scale, REFERENCE_DPI)

	# Si la fenêtre n'a pas encore de taille valide, retourner 1.0
	if win_size.x <= 0 or win_size.y <= 0:
		return 1.0

	# Facteur de scaling interne de Godot (canvas_items + expand) :
	# nombre de pixels physiques par pixel virtuel
	var godot_scale := minf(
		float(win_size.x) / DESIGN_WIDTH,
		float(win_size.y) / DESIGN_HEIGHT
	)
	godot_scale = maxf(godot_scale, 0.01)

	# Pour maintenir la même taille physique qu'à 96 DPI / 1920x1080 :
	var raw_scale := (dpi / REFERENCE_DPI) / godot_scale * _user_multiplier
	return clampf(raw_scale, SCALE_MIN, SCALE_MAX)
