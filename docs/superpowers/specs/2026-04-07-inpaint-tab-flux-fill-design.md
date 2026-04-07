# Design — Onglet Inpaint (Flux Fill)

**Date** : 2026-04-07
**Statut** : Approuvé

## Objectif

Créer un onglet dédié "Inpaint" dans le plugin AI Studio permettant de régénérer une zone rectangulaire d'une image source. L'onglet Décliner est simultanément réverté à son état d'origine (sans section masque).

---

## Workflow : `INPAINT_FILL_WORKFLOW_TEMPLATE`

Basé sur `OUTPAINT_WORKFLOW_TEMPLATE` (Flux Fill + InpaintModelConditioning + DifferentialDiffusion + KSampler), en remplaçant `ImagePadForOutpaint` par le chargement direct de l'image source et du masque dessiné par l'utilisateur.

### Nœuds gardés depuis OUTPAINT

| Node | Class | Rôle |
|------|-------|------|
| `3` | KSampler | Sampling principal |
| `8` | VAEDecode | Décodage latent |
| `9` | SaveImage | Sauvegarde résultat |
| `17` | LoadImage | Chargement image source |
| `23` | CLIPTextEncode | Prompt positif |
| `26` | FluxGuidance | Guidance |
| `31` | UNETLoader | flux1-fill-dev.safetensors |
| `32` | VAELoader | ae.safetensors |
| `34` | DualCLIPLoader | clip_l + t5xxl_fp16 |
| `38` | InpaintModelConditioning | Conditioning image+masque |
| `39` | DifferentialDiffusion | Fusion douce |
| `46` | CLIPTextEncode | Prompt négatif (vide par défaut) |

### Nœuds supprimés

- `44` : ImagePadForOutpaint

### Nœuds ajoutés pour le masque

| Node ID | Class | Rôle |
|---------|-------|------|
| `ip:mask` | LoadImage | Charge le PNG masque uploadé |
| `ip:mask_convert` | ImageToMask | Convertit IMAGE → MASK (canal "red") |
| `ip:grow` | GrowMask | Expansion du masque (feather) |
| `ip:blur` | ImpactGaussianBlurMask | Adoucissement des bords |

Câblage : `InpaintModelConditioning.pixels = ["17", 0]`, `InpaintModelConditioning.mask = [final_mask_node, 0]`

### Paramètres dynamiques

- `filename` → node `17` image
- `mask_filename` → node `ip:mask` image
- `prompt_text` → node `23` text
- `seed` → node `3` seed
- `cfg` → node `3` cfg (via FluxGuidance guidance = cfg)
- `steps` → node `3` steps
- `denoise` → node `3` denoise
- `mask_feather` → GrowMask.expand + ImpactGaussianBlurMask params
- `debug_mask` → quand true, `SaveImage` sort `MaskToImage(final_mask_node)` à la place

---

## Fonction `_build_inpaint_workflow` — réécriture complète

La fonction existante (basée sur EXPRESSION_WORKFLOW_TEMPLATE + SetLatentNoiseMask, cassée) est remplacée par une version basée sur `INPAINT_FILL_WORKFLOW_TEMPLATE`.

```gdscript
func _build_inpaint_workflow(
    filename: String,
    mask_filename: String,
    prompt_text: String,
    seed: int,
    cfg: float,
    steps: int,
    denoise: float,
    negative_prompt: String,
    mask_feather: int
) -> Dictionary
```

---

## UI — `ai_studio_inpaint_tab.gd`

Nouvel onglet (`extends RefCounted`, pattern identique aux autres onglets).

### Contrôles

1. **IMAGE SOURCE** — picker fichier + bouton galerie + aperçu interactif (rectangle masque)
2. **MASQUE** — coords label + bouton Effacer + slider Fondu (0–100, défaut 15) + checkbox Debug mask
3. **PROMPT** — TextEdit
4. **Remove background** — CheckBox (défaut : true)
5. **CFG** — HSlider (0.1–10, défaut 1.0)
6. **Steps** — HSlider (1–50, défaut 20)
7. **Denoise** — HSlider (0.1–1.0, défaut 1.0)
8. **Megapixels** — HSlider (0.25–2.0, défaut 1.0) — passé à ImageScaleToTotalPixels si présent, sinon ignoré (Flux Fill travaille à la résolution native)
9. **LoRAs** — liste dynamique (même pattern que Décliner)
10. **Bouton GÉNÉRER**
11. **Aperçu résultat** — TextureRect + ProgressBar + StatusLabel
12. **Champ nom + bouton Sauvegarder + bouton Régénérer**

### Logique masque

Identique à ce qui était dans Décliner :
- `_preview_wrapper` (Control clip_contents) + `_source_preview` (TextureRect) + `_mask_overlay` (Panel bleu)
- `gui_input` sur `_source_preview` → `_handle_mask_input`
- `_display_rect_to_image_rect` pour conversion display → image space
- `build_mask_bytes` (méthode statique de ComfyUIClient) pour générer le PNG

---

## Modifications `ai_studio_decliner_tab.gd`

Revert complet de la section masque ajoutée lors de la session précédente :
- Supprimer vars : `_mask_checkbox`, `_mask_content`, `_mask_coords_label`, `_mask_feather_slider`, `_mask_feather_value_label`, `_mask_clear_btn`, `_mask_debug_checkbox`, `_mask_overlay`, `_preview_wrapper`
- Supprimer vars état : `_mask_rect`, `_mask_drawing`, `_mask_draw_start`, `_source_image_size`
- Supprimer méthodes : `_handle_mask_input`, `_display_rect_to_image_rect`, `_update_mask_overlay`, `_update_mask_coords_label`
- Supprimer section masque dans le builder UI (HSeparator + CheckBox + VBox contenu)
- Reverter `_source_preview` (retirer le wrapper, remettre dans hbox directement)
- Reverter `_on_generate_pressed` (supprimer bloc masque + `_client._debug_mask`)
- Reverter `_set_inputs_enabled` (supprimer `_mask_clear_btn` et `_mask_debug_checkbox`)

---

## Modifications `ai_studio_dialog.gd`

Ajouter `InpaintTab` comme nouvel onglet (après Décliner ou à la fin de la liste).

```gdscript
const InpaintTab = preload("res://plugins/ai_studio/ai_studio_inpaint_tab.gd")
```

---

## Fichiers modifiés

| Fichier | Modification |
|---------|-------------|
| `plugins/ai_studio/ai_studio_inpaint_tab.gd` | NOUVEAU — onglet Inpaint complet |
| `plugins/ai_studio/ai_studio_dialog.gd` | Ajout onglet Inpaint |
| `plugins/ai_studio/ai_studio_decliner_tab.gd` | Revert section masque |
| `src/services/comfyui_client.gd` | `INPAINT_FILL_WORKFLOW_TEMPLATE` + réécriture `_build_inpaint_workflow` |

---

## Hors scope

- Masque non-rectangulaire
- Undo/redo du masque
- Import fichier masque externe
- Inpainting sur image 2 (deuxième source)
