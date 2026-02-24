extends RefCounted

## Presse-papiers interne pour copier/coller les paramètres de positionnement d'un foreground.
## Stocke scale, anchor_bg, anchor_fg, flip_h, flip_v.

var data = null  # null = pas de données copiées

func has_data() -> bool:
	return data != null

func copy_from(fg) -> void:
	data = {
		"scale": fg.scale,
		"anchor_bg": Vector2(fg.anchor_bg.x, fg.anchor_bg.y),
		"anchor_fg": Vector2(fg.anchor_fg.x, fg.anchor_fg.y),
		"flip_h": fg.flip_h,
		"flip_v": fg.flip_v,
	}

func paste_to(fg) -> bool:
	if not has_data():
		return false
	fg.scale = data.scale
	fg.anchor_bg = Vector2(data.anchor_bg.x, data.anchor_bg.y)
	fg.anchor_fg = Vector2(data.anchor_fg.x, data.anchor_fg.y)
	fg.flip_h = data.flip_h
	fg.flip_v = data.flip_v
	return true
