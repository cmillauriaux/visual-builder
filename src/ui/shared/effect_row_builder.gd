# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Factory pour créer les lignes d'effets variables dans l'UI.

const VariableEffectScript = preload("res://src/models/variable_effect.gd")

static func create_effect_row(
	effect,
	variable_names: Array,
	on_var_changed: Callable,
	on_op_changed: Callable,
	on_value_changed: Callable,
	on_delete: Callable
) -> HBoxContainer:
	var row = HBoxContainer.new()

	# Variable edit
	var var_edit = LineEdit.new()
	var_edit.text = effect.variable
	var_edit.placeholder_text = TranslationServer.translate("Variable...")
	var_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var_edit.tooltip_text = ", ".join(variable_names) if variable_names.size() > 0 else ""
	var_edit.text_changed.connect(on_var_changed)
	row.add_child(var_edit)

	# Operation dropdown
	var op_dropdown = OptionButton.new()
	for lbl in VariableEffectScript.OPERATION_LABELS:
		op_dropdown.add_item(lbl)
	var op_idx = VariableEffectScript.VALID_OPERATIONS.find(effect.operation)
	if op_idx < 0:
		op_idx = 0
	op_dropdown.selected = op_idx
	op_dropdown.item_selected.connect(func(idx): on_op_changed.call(VariableEffectScript.VALID_OPERATIONS[idx]))
	row.add_child(op_dropdown)

	# Value edit (hidden for delete)
	var value_edit = LineEdit.new()
	value_edit.text = effect.value
	value_edit.placeholder_text = TranslationServer.translate("Valeur...")
	value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_edit.visible = effect.operation != "delete"
	value_edit.text_changed.connect(on_value_changed)
	row.add_child(value_edit)

	# Delete button
	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.pressed.connect(on_delete)
	row.add_child(delete_btn)

	return row