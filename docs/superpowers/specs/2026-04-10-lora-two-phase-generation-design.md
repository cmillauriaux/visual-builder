# LORA Generator — Two-Phase Generation Design

**Date:** 2026-04-10  
**Scope:** Redesign of `plugins/ai_studio/ai_studio_lora_generator_tab.gd`

---

## Problem

The current LORA Generator uses original source photos as the img2img source for every variation (expressions, angles, outfits, contexts). This causes inconsistency: full body shots may have different shoes than other full body shots, hairstyle may vary between generations, etc.

## Solution: Two-Phase Workflow

### Phase 1 — Base Images

Generate (or import) a small set of canonical reference images — one per framing type. These become the authoritative visual description of the character for each shot type.

**6 fixed base slots:**

| Slot | Framing | Auto-mapped from captions containing |
|------|---------|---------------------------------------|
| Close-up | Very tight face | `close-up` |
| Portrait | Head + shoulders | (default fallback) |
| 3/4 | Three-quarter view | `three-quarter` |
| Profil | Side / over-shoulder | `looking over shoulder`, `profile` |
| Buste | Upper body / waist up | `upper body`, `waist up` |
| Corps entier | Full body | `full body` |

Each slot can be:
- **Generated** via img2img from user-uploaded source photos (same ComfyUI pipeline as today). If multiple source photos are uploaded, the first one is used for generation; the user can re-generate individual slots after swapping the source.
- **Imported** from disk (pick an existing PNG/JPG via FileDialog)

Each slot has its own prompt (pre-filled with a sensible default, editable).

### Phase 2 — Variations (Dataset)

Generate the 100 dataset variations using the **base images as sources** instead of the original source photos. Each variation is automatically mapped to a base slot by keyword detection in its caption.

**Mapping priority (first match wins):**
1. `close-up` → Close-up
2. `full body` → Corps entier
3. `upper body` OR `waist up` → Buste
4. `three-quarter` → 3/4
5. `looking over shoulder` OR `profile` → Profil
6. _(default)_ → Portrait

If the required base slot is empty, variations that depend on it remain blocked (shown as "⏳ en attente — base manquante").

---

## UI Structure

Single tab, two vertical sections in the left panel. The right panel shows a shared results grid.

### Left Panel

```
┌─────────────────────────────┐
│  ① BASES DE RÉFÉRENCE       │
│  ──────────────────────     │
│  Keyword : [mychar_v1     ] │
│                             │
│  [Close-up ✓] [Portrait ✓]  │
│  [3/4      ] [Profil     ]  │
│  [Buste ⏳ ] [Corps      ]  │
│                             │
│  Sources pour génération :  │
│  [img][img][+]              │
│                             │
│  Denoise [0.65] Steps [20]  │
│  [⚡ GÉNÉRER TOUTES LES BASES] │
│                             │
│  ② DÉCLINAISONS             │
│  ──────────────────────     │
│  Variations prédéfinies :   │
│  [Tout] [Aucun]             │
│  ☐ 001 portrait ...  [Portrait] │
│  ☑ 004 closeup ...   [Close-up] │
│  …                          │
│                             │
│  Denoise [0.55] Steps [20]  │
│  [⚡ GÉNÉRER LES DÉCLINAISONS] │
└─────────────────────────────┘
```

### Right Panel (shared grid)

- **Base images** displayed in a fixed top row (6 cells, one per slot), with a colored `BASE <slot>` badge and green border. Empty slots show a placeholder.
- **Variations** displayed below the bases, one card per selected variation, with the auto-detected slot badge in its color.
- Status indicators: ✓ (completed), ⏳ (generating), … (pending), ✗ (failed), `BASE MANQUANTE` (blocked)
- Top bar: count label, "Charger dossier" button, "Sauvegarder tout" button

### Base Slot Widget (6 of them, in a 2-column grid)

Each slot shows:
- Thumbnail (or empty placeholder)
- Slot name + status text
- `📂 Importer` button
- `⚡ Générer` button (uses source photos + slot prompt via img2img)

Clicking a slot thumbnail calls the existing `show_preview_fn` to display the full image.

---

## Data Model Changes

### New: `_bases` dictionary

```gdscript
var _bases: Dictionary = {
    "closeup":    {"image": null, "path": ""},
    "portrait":   {"image": null, "path": ""},
    "three_quarter": {"image": null, "path": ""},
    "profile":    {"image": null, "path": ""},
    "buste":      {"image": null, "path": ""},
    "full_body":  {"image": null, "path": ""},
}
```

### Updated: `LoraTrainingQueueService.build_queue()`

New signature:
```gdscript
func build_queue(bases: Dictionary, keyword: String, variations: Array) -> void
```

For each variation, the source image is `bases[_detect_base(variation_value)]["path"]` instead of the original user-uploaded source.

`_detect_base(caption: String) -> String` applies the mapping priority above.

### Unchanged

- Item structure (`source_image_path`, `keyword`, `variation_prompt`, `status`, `image`, `caption`)
- Save/load folder logic (PNG + TXT pairs)
- ComfyUI generation pipeline
- Custom variations support

---

## Generation Parameters

Phase 1 and Phase 2 have **independent** Denoise / Steps / CFG sliders. Rationale: base image generation typically needs lower denoise (faithfulness to source), while variations can afford higher denoise (more creative freedom within the style established by the base).

Default values:
- Phase 1: Denoise 0.55, Steps 20, CFG 3.5
- Phase 2: Denoise 0.65, Steps 20, CFG 3.5

---

## Refactoring Scope

`ai_studio_lora_generator_tab.gd` is currently 865 lines and will grow significantly. Split into:

- **`ai_studio_lora_generator_tab.gd`** — orchestration only (initialize, build_tab, public API)
- **`lora_bases_panel.gd`** — Phase 1 UI + generation logic for the 6 base slots
- **`lora_variations_panel.gd`** — Phase 2 UI (variation list, checkboxes, generate button)

`lora_training_queue_service.gd` gets the `build_queue` signature update and a new `_detect_base()` helper.

---

## Out of Scope

- Manual override of the auto-detected base per variation (auto-only for now)
- Adding/removing/renaming base slots (6 fixed slots)
- Using multiple source images per base slot in Phase 2 (one base per slot)
