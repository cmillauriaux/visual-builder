# SPDX-License-Identifier: AGPL-3.0-only
extends GutTest

const LoraBasesPanel = preload("res://plugins/ai_studio/lora_bases_panel.gd")

var panel: LoraBasesPanel

func before_each() -> void:
	panel = LoraBasesPanel.new()

func after_each() -> void:
	panel = null

# ── BASE_SLOTS const ─────────────────────────────────────────────

func test_base_slots_has_six_entries() -> void:
	assert_eq(LoraBasesPanel.BASE_SLOTS.size(), 6)

func test_base_slots_keys() -> void:
	var keys = LoraBasesPanel.BASE_SLOTS.map(func(s): return s["key"])
	assert_has(keys, "closeup")
	assert_has(keys, "portrait")
	assert_has(keys, "three_quarter")
	assert_has(keys, "profile")
	assert_has(keys, "buste")
	assert_has(keys, "full_body")

func test_base_slots_all_have_prompt() -> void:
	for slot in LoraBasesPanel.BASE_SLOTS:
		assert_true(slot["prompt"].length() > 0, "slot %s has empty prompt" % slot["key"])

# ── get_bases() initial state ────────────────────────────────────

func test_get_bases_returns_all_six_keys() -> void:
	var bases = panel.get_bases()
	assert_eq(bases.size(), 6)
	assert_has(bases, "closeup")
	assert_has(bases, "full_body")

func test_get_bases_initial_image_is_null() -> void:
	var bases = panel.get_bases()
	for key in bases:
		assert_null(bases[key]["image"], "initial image should be null for %s" % key)

func test_get_bases_initial_path_is_empty() -> void:
	var bases = panel.get_bases()
	for key in bases:
		assert_eq(bases[key]["path"], "")

# ── Fallback getters (before build() is called) ──────────────────

func test_get_keyword_returns_empty_before_build() -> void:
	assert_eq(panel.get_keyword(), "")

func test_get_source_paths_returns_empty_array() -> void:
	assert_eq(panel.get_source_paths().size(), 0)

func test_get_first_source_path_returns_empty_string() -> void:
	assert_eq(panel.get_first_source_path(), "")

func test_get_denoise_fallback_before_build() -> void:
	assert_eq(panel.get_denoise(), 0.55)

func test_get_steps_fallback_before_build() -> void:
	assert_eq(panel.get_steps(), 20)

func test_get_cfg_fallback_before_build() -> void:
	assert_eq(panel.get_cfg(), 3.5)

# ── get_slot_prompt() ────────────────────────────────────────────

func test_get_slot_prompt_closeup() -> void:
	var prompt = panel.get_slot_prompt("closeup")
	assert_true("close-up" in prompt, "closeup prompt should contain 'close-up'")

func test_get_slot_prompt_full_body() -> void:
	var prompt = panel.get_slot_prompt("full_body")
	assert_true("full body" in prompt, "full_body prompt should contain 'full body'")

func test_get_slot_prompt_unknown_key_returns_empty() -> void:
	assert_eq(panel.get_slot_prompt("nonexistent"), "")
