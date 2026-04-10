# SPDX-License-Identifier: AGPL-3.0-only
extends GutTest

const LoraVariationsPanel = preload("res://plugins/ai_studio/lora_variations_panel.gd")

var panel: LoraVariationsPanel

func before_each() -> void:
	panel = LoraVariationsPanel.new()

func after_each() -> void:
	panel = null

# ── BADGE_LABELS const ───────────────────────────────────────────

func test_badge_labels_has_six_keys() -> void:
	assert_eq(LoraVariationsPanel.BADGE_LABELS.size(), 6)

func test_badge_labels_has_all_expected_keys() -> void:
	assert_has(LoraVariationsPanel.BADGE_LABELS, "closeup")
	assert_has(LoraVariationsPanel.BADGE_LABELS, "portrait")
	assert_has(LoraVariationsPanel.BADGE_LABELS, "three_quarter")
	assert_has(LoraVariationsPanel.BADGE_LABELS, "profile")
	assert_has(LoraVariationsPanel.BADGE_LABELS, "buste")
	assert_has(LoraVariationsPanel.BADGE_LABELS, "full_body")

# ── BADGE_COLORS const ───────────────────────────────────────────

func test_badge_colors_has_six_keys() -> void:
	assert_eq(LoraVariationsPanel.BADGE_COLORS.size(), 6)

func test_badge_colors_has_all_expected_keys() -> void:
	assert_has(LoraVariationsPanel.BADGE_COLORS, "closeup")
	assert_has(LoraVariationsPanel.BADGE_COLORS, "portrait")
	assert_has(LoraVariationsPanel.BADGE_COLORS, "three_quarter")
	assert_has(LoraVariationsPanel.BADGE_COLORS, "profile")
	assert_has(LoraVariationsPanel.BADGE_COLORS, "buste")
	assert_has(LoraVariationsPanel.BADGE_COLORS, "full_body")

func test_badge_colors_values_are_colors() -> void:
	for key in LoraVariationsPanel.BADGE_COLORS:
		var val = LoraVariationsPanel.BADGE_COLORS[key]
		assert_true(val is Color,
			"BADGE_COLORS[%s] should be a Color" % key)

# ── Fallback getters (before build() is called) ──────────────────

func test_get_selected_variations_returns_empty_before_build() -> void:
	var result = panel.get_selected_variations()
	assert_eq(result.size(), 0)

func test_get_denoise_fallback_before_build() -> void:
	assert_eq(panel.get_denoise(), 0.65)

func test_get_steps_fallback_before_build() -> void:
	assert_eq(panel.get_steps(), 20)

func test_get_cfg_fallback_before_build() -> void:
	assert_eq(panel.get_cfg(), 3.5)
