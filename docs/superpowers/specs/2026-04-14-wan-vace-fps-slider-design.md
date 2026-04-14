# WAN VACE — Slider FPS

## Goal

Exposer un slider FPS dans l'onglet WAN VACE pour réduire le nombre de frames générées et accélérer la génération.

## Architecture

Trois fichiers touchés :
- `plugins/ai_studio/ai_studio_wan_vace_tab.gd` — ajout du slider UI + passage du fps à `generate_sequence`
- `src/services/comfyui_client.gd` — nouveau paramètre `fps` dans `generate_sequence` + `_build_wan_i2v_workflow` + `_build_wan_vace_workflow`
- `specs/services/test_comfyui_client_wan_vace.gd` — tests num_frames avec fps variable

## Comportement

**Slider :**
- Min: 4, Max: 16, Step: 4 (valeurs possibles : 4 / 8 / 12 / 16 fps)
- Défaut: 8
- Label dynamique affichant la valeur courante (ex. "8 fps")
- Positionné dans la section paramètres, à côté du slider durée

**Calcul num_frames :**
- I2V : `num_frames = clamp(round(duration_sec * fps / 4) * 4, 16, 200)` (multiple de 4)
- VACE : `total_frames = clamp(round(duration_sec * fps / 8) * 8, 16, 128)` (multiple de 8)

**Exemples :**
- 3s @ 8fps → 24 frames (I2V), 24 frames (VACE)
- 3s @ 16fps → 48 frames (inchangé)
- 3s @ 4fps → 16 frames (minimum)

## API

```gdscript
func generate_sequence(
    ...
    fps: int = 8,       # nouveau paramètre, après controlnet_strength
) -> void
```

## Fichiers modifiés

- Create: rien
- Modify: `plugins/ai_studio/ai_studio_wan_vace_tab.gd` (UI + appel)
- Modify: `src/services/comfyui_client.gd` (signature + _build_wan_i2v_workflow + _build_wan_vace_workflow)
- Test: `specs/services/test_comfyui_client_wan_vace.gd`
