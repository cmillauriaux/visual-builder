extends RefCounted

## Construit un Theme Godot utilisant les textures Kenney UI Pack Adventure
## (style brun/beige aventure). Appliqué au noeud racine Game pour que
## tous les enfants héritent automatiquement du style.

const ASSETS_PATH = "res://assets/ui/kenney/"

# Couleurs
const COLOR_TEXT_DARK = Color("#3D2B1F")
const COLOR_TEXT_SECONDARY = Color("#6B4E37")
const COLOR_TEXT_WHITE = Color("#FFFFFF")
const COLOR_BUTTON_TEXT = Color("#3D2B1F")
const COLOR_SEPARATOR = Color("#6B4E37")

# Marges NinePatch (pour textures Double 2x)
const PANEL_MARGIN = { "left": 18, "right": 18, "top": 18, "bottom": 20 }
const PANEL_CONTENT_MARGIN = 24
const BUTTON_MARGIN = { "left": 18, "right": 18, "top": 12, "bottom": 16 }
const BUTTON_CONTENT_H = 20
const BUTTON_CONTENT_V = 8
const SCROLLBAR_MARGIN = { "left": 8, "right": 8, "top": 16, "bottom": 16 }


static func create_theme() -> Theme:
	var theme = Theme.new()
	_setup_button(theme)
	_setup_option_button(theme)
	_setup_panel_container(theme)
	_setup_label(theme)
	_setup_rich_text_label(theme)
	_setup_check_button(theme)
	_setup_separator(theme)
	_setup_slider(theme)
	_setup_scrollbar(theme)
	return theme


## Applique le style "danger" (bouton rouge) à un bouton spécifique.
static func apply_danger_style(button: Button) -> void:
	var tex = load(ASSETS_PATH + "button_red.png")
	if tex == null:
		return
	button.add_theme_stylebox_override("normal", _make_button_stylebox(tex, Color(1, 1, 1, 1)))
	button.add_theme_stylebox_override("hover", _make_button_stylebox(tex, Color(1.15, 1.15, 1.15, 1)))
	button.add_theme_stylebox_override("pressed", _make_button_stylebox(tex, Color(0.85, 0.85, 0.85, 1)))
	button.add_theme_stylebox_override("disabled", _make_button_stylebox(tex, Color(0.7, 0.7, 0.7, 0.6)))
	button.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT_WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9, 1))


## Applique le style "close" (bouton rouge avec X) à un bouton spécifique.
static func apply_close_style(button: Button) -> void:
	var tex = load(ASSETS_PATH + "button_red_close.png")
	if tex == null:
		return
	button.add_theme_stylebox_override("normal", _make_button_stylebox(tex, Color(1, 1, 1, 1)))
	button.add_theme_stylebox_override("hover", _make_button_stylebox(tex, Color(1.15, 1.15, 1.15, 1)))
	button.add_theme_stylebox_override("pressed", _make_button_stylebox(tex, Color(0.85, 0.85, 0.85, 1)))
	button.add_theme_stylebox_override("disabled", _make_button_stylebox(tex, Color(0.7, 0.7, 0.7, 0.6)))
	button.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT_WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9, 1))


## Applique le style panel_brown_dark à un PanelContainer spécifique.
static func apply_dark_panel_style(panel: PanelContainer) -> void:
	var tex = load(ASSETS_PATH + "panel_brown_dark.png")
	if tex == null:
		return
	panel.add_theme_stylebox_override("panel", _make_panel_stylebox(tex))


# --- Privé : setup par type de contrôle ---

static func _setup_button(theme: Theme) -> void:
	var tex = load(ASSETS_PATH + "button_brown.png")
	if tex == null:
		return
	theme.set_stylebox("normal", "Button", _make_button_stylebox(tex, Color(1, 1, 1, 1)))
	theme.set_stylebox("hover", "Button", _make_button_stylebox(tex, Color(1.15, 1.15, 1.15, 1)))
	theme.set_stylebox("pressed", "Button", _make_button_stylebox(tex, Color(0.85, 0.85, 0.85, 1)))
	theme.set_stylebox("disabled", "Button", _make_button_stylebox(tex, Color(0.7, 0.7, 0.7, 0.6)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", COLOR_BUTTON_TEXT)
	theme.set_color("font_hover_color", "Button", COLOR_BUTTON_TEXT)
	theme.set_color("font_pressed_color", "Button", Color("#5C3A1E"))
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.4, 0.3, 0.5))
	theme.set_font_size("font_size", "Button", 16)


static func _setup_option_button(theme: Theme) -> void:
	var tex = load(ASSETS_PATH + "button_brown.png")
	if tex == null:
		return
	theme.set_stylebox("normal", "OptionButton", _make_button_stylebox(tex, Color(1, 1, 1, 1)))
	theme.set_stylebox("hover", "OptionButton", _make_button_stylebox(tex, Color(1.15, 1.15, 1.15, 1)))
	theme.set_stylebox("pressed", "OptionButton", _make_button_stylebox(tex, Color(0.85, 0.85, 0.85, 1)))
	theme.set_stylebox("disabled", "OptionButton", _make_button_stylebox(tex, Color(0.7, 0.7, 0.7, 0.6)))
	theme.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	theme.set_color("font_color", "OptionButton", COLOR_BUTTON_TEXT)
	theme.set_color("font_hover_color", "OptionButton", COLOR_BUTTON_TEXT)
	theme.set_color("font_pressed_color", "OptionButton", Color("#5C3A1E"))
	theme.set_font_size("font_size", "OptionButton", 16)


static func _setup_panel_container(theme: Theme) -> void:
	var tex = load(ASSETS_PATH + "panel_brown.png")
	if tex == null:
		return
	theme.set_stylebox("panel", "PanelContainer", _make_panel_stylebox(tex))


static func _setup_label(theme: Theme) -> void:
	theme.set_color("font_color", "Label", COLOR_TEXT_DARK)
	theme.set_font_size("font_size", "Label", 16)


static func _setup_rich_text_label(theme: Theme) -> void:
	theme.set_color("default_color", "RichTextLabel", COLOR_TEXT_DARK)
	theme.set_font_size("normal_font_size", "RichTextLabel", 16)


static func _setup_check_button(theme: Theme) -> void:
	var unchecked = load(ASSETS_PATH + "checkbox_brown_empty.png")
	var checked = load(ASSETS_PATH + "checkbox_brown_checked.png")
	if unchecked:
		theme.set_icon("unchecked", "CheckButton", unchecked)
	if checked:
		theme.set_icon("checked", "CheckButton", checked)
	theme.set_color("font_color", "CheckButton", COLOR_TEXT_DARK)
	theme.set_font_size("font_size", "CheckButton", 16)


static func _setup_separator(theme: Theme) -> void:
	var style = StyleBoxLine.new()
	style.color = COLOR_SEPARATOR
	style.thickness = 2
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	theme.set_stylebox("separator", "HSeparator", style)


static func _setup_slider(theme: Theme) -> void:
	# Grabber (le curseur)
	var grabber_style = StyleBoxFlat.new()
	grabber_style.bg_color = Color("#8B6914")
	grabber_style.set_corner_radius_all(8)
	grabber_style.content_margin_left = 8
	grabber_style.content_margin_right = 8
	grabber_style.content_margin_top = 8
	grabber_style.content_margin_bottom = 8

	# Slider track
	var slider_style = StyleBoxFlat.new()
	slider_style.bg_color = Color("#C4A882")
	slider_style.set_corner_radius_all(4)
	slider_style.content_margin_top = 4
	slider_style.content_margin_bottom = 4

	theme.set_stylebox("slider", "HSlider", slider_style)
	theme.set_stylebox("grabber_area", "HSlider", slider_style)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_style)

	# Grabber icon
	theme.set_constant("grabber_offset", "HSlider", 0)


static func _setup_scrollbar(theme: Theme) -> void:
	# Style pour la barre de défilement verticale
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color("#C4A882")
	bg_style.set_corner_radius_all(4)
	bg_style.content_margin_left = 4
	bg_style.content_margin_right = 4

	var grabber_style = StyleBoxFlat.new()
	grabber_style.bg_color = Color("#8B6914")
	grabber_style.set_corner_radius_all(4)
	grabber_style.content_margin_left = 4
	grabber_style.content_margin_right = 4

	var grabber_hover = StyleBoxFlat.new()
	grabber_hover.bg_color = Color("#A07B1A")
	grabber_hover.set_corner_radius_all(4)
	grabber_hover.content_margin_left = 4
	grabber_hover.content_margin_right = 4

	theme.set_stylebox("scroll", "VScrollBar", bg_style)
	theme.set_stylebox("grabber", "VScrollBar", grabber_style)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber_hover)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber_hover)


## Applique un style thématique (brun aventure) à un TabContainer.
static func apply_tab_container_style(tab: TabContainer) -> void:
	# --- Fond de la zone de contenu ---
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#2A1D14")
	panel_style.set_corner_radius_all(0)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	tab.add_theme_stylebox_override("panel", panel_style)

	# --- Onglet sélectionné ---
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color("#C4A882")
	selected.corner_radius_top_left = 5
	selected.corner_radius_top_right = 5
	selected.content_margin_left = 16
	selected.content_margin_right = 16
	selected.content_margin_top = 8
	selected.content_margin_bottom = 8
	tab.add_theme_stylebox_override("tab_selected", selected)

	# --- Onglet non sélectionné ---
	var unselected := StyleBoxFlat.new()
	unselected.bg_color = Color("#5C3A1E")
	unselected.corner_radius_top_left = 5
	unselected.corner_radius_top_right = 5
	unselected.content_margin_left = 16
	unselected.content_margin_right = 16
	unselected.content_margin_top = 8
	unselected.content_margin_bottom = 8
	tab.add_theme_stylebox_override("tab_unselected", unselected)

	# --- Onglet survolé ---
	var hovered := StyleBoxFlat.new()
	hovered.bg_color = Color("#7A4E2A")
	hovered.corner_radius_top_left = 5
	hovered.corner_radius_top_right = 5
	hovered.content_margin_left = 16
	hovered.content_margin_right = 16
	hovered.content_margin_top = 8
	hovered.content_margin_bottom = 8
	tab.add_theme_stylebox_override("tab_hovered", hovered)

	# --- Couleurs du texte des onglets ---
	tab.add_theme_color_override("font_selected_color", COLOR_TEXT_DARK)
	tab.add_theme_color_override("font_unselected_color", Color("#E8D5B5"))
	tab.add_theme_color_override("font_hovered_color", Color("#F0E4CC"))

	# --- Taille de police ---
	tab.add_theme_font_size_override("font_size", 16)


## Applique un style coloré personnalisé à un bouton de lien externe.
static func apply_link_style(button: Button, color: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = BUTTON_CONTENT_H
	normal.content_margin_right = BUTTON_CONTENT_H
	normal.content_margin_top = BUTTON_CONTENT_V
	normal.content_margin_bottom = BUTTON_CONTENT_V
	button.add_theme_stylebox_override("normal", normal)

	var hover = normal.duplicate()
	hover.bg_color = color.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover)

	var pressed = normal.duplicate()
	pressed.bg_color = color.darkened(0.15)
	button.add_theme_stylebox_override("pressed", pressed)

	button.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT_WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9, 1))


# --- Helpers pour construire les StyleBoxTexture ---

static func _make_button_stylebox(tex: Texture2D, modulate: Color) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = BUTTON_MARGIN.left
	style.texture_margin_right = BUTTON_MARGIN.right
	style.texture_margin_top = BUTTON_MARGIN.top
	style.texture_margin_bottom = BUTTON_MARGIN.bottom
	style.content_margin_left = BUTTON_CONTENT_H
	style.content_margin_right = BUTTON_CONTENT_H
	style.content_margin_top = BUTTON_CONTENT_V
	style.content_margin_bottom = BUTTON_CONTENT_V
	style.modulate_color = modulate
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return style


static func _make_panel_stylebox(tex: Texture2D) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = PANEL_MARGIN.left
	style.texture_margin_right = PANEL_MARGIN.right
	style.texture_margin_top = PANEL_MARGIN.top
	style.texture_margin_bottom = PANEL_MARGIN.bottom
	style.content_margin_left = PANEL_CONTENT_MARGIN
	style.content_margin_right = PANEL_CONTENT_MARGIN
	style.content_margin_top = PANEL_CONTENT_MARGIN
	style.content_margin_bottom = PANEL_CONTENT_MARGIN
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return style
