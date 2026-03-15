extends GutTest

const Contributions = preload("res://src/plugins/contributions.gd")


# --- MenuEntry ---

func test_menu_entry_has_menu_id_field() -> void:
	var entry := Contributions.MenuEntry.new()
	entry.menu_id = "parametres"
	assert_eq(entry.menu_id, "parametres")


func test_menu_entry_has_label_field() -> void:
	var entry := Contributions.MenuEntry.new()
	entry.label = "Studio IA"
	assert_eq(entry.label, "Studio IA")


func test_menu_entry_has_callback_field() -> void:
	var entry := Contributions.MenuEntry.new()
	var cb := func(): pass
	entry.callback = cb
	assert_true(entry.callback.is_valid())


# --- ToolbarItem ---

func test_toolbar_item_has_level_field() -> void:
	var item := Contributions.ToolbarItem.new()
	item.level = "sequence"
	assert_eq(item.level, "sequence")


func test_toolbar_item_has_label_field() -> void:
	var item := Contributions.ToolbarItem.new()
	item.label = "Open AI"
	assert_eq(item.label, "Open AI")


func test_toolbar_item_has_callback_field() -> void:
	var item := Contributions.ToolbarItem.new()
	var cb := func(): pass
	item.callback = cb
	assert_true(item.callback.is_valid())


func test_toolbar_item_icon_is_null_by_default() -> void:
	var item := Contributions.ToolbarItem.new()
	assert_null(item.icon)


# --- DockPanelDef ---

func test_dock_panel_has_title_field() -> void:
	var def := Contributions.DockPanelDef.new()
	def.title = "AI Studio"
	assert_eq(def.title, "AI Studio")


func test_dock_panel_has_position_field() -> void:
	var def := Contributions.DockPanelDef.new()
	def.position = "left"
	assert_eq(def.position, "left")


func test_dock_panel_has_create_panel_field() -> void:
	var def := Contributions.DockPanelDef.new()
	var cb := func(): return null
	def.create_panel = cb
	assert_true(def.create_panel.is_valid())


# --- SequenceTabDef ---

func test_sequence_tab_has_title_field() -> void:
	var def := Contributions.SequenceTabDef.new()
	def.title = "AI"
	assert_eq(def.title, "AI")


func test_sequence_tab_has_create_tab_field() -> void:
	var def := Contributions.SequenceTabDef.new()
	var cb := func(): return null
	def.create_tab = cb
	assert_true(def.create_tab.is_valid())


# --- BackgroundServiceDef ---

func test_background_service_has_service_script_field() -> void:
	var def := Contributions.BackgroundServiceDef.new()
	assert_null(def.service_script)


func test_background_service_setup_callback_is_callable() -> void:
	var def := Contributions.BackgroundServiceDef.new()
	var cb := func(n, c): pass
	def.setup_callback = cb
	assert_true(def.setup_callback.is_valid())


# --- ImagePickerTabDef ---

func test_image_picker_tab_has_label_field() -> void:
	var def := Contributions.ImagePickerTabDef.new()
	assert_eq(def.label, "")


func test_image_picker_tab_label_can_be_set() -> void:
	var def := Contributions.ImagePickerTabDef.new()
	def.label = "IA"
	assert_eq(def.label, "IA")


func test_image_picker_tab_create_tab_is_callable() -> void:
	var def := Contributions.ImagePickerTabDef.new()
	var cb := func(_ctx): return Control.new()
	def.create_tab = cb
	assert_true(def.create_tab.is_valid())
