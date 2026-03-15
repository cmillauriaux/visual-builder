# 066 — Onglet Upscale dans le Studio IA

## Résumé

Nouvel onglet **"Upscale"** (onglet 2) dans le Studio IA permettant d'upscaler ou downscaler une image via le workflow ComfyUI **Ultimate SD Upscale** (tiling avec ESRGAN + diffusion Flux).

## Contexte / Motivation

Les créateurs de visual novels ont besoin de redimensionner intelligemment des images existantes (personnages, fonds) vers des résolutions plus élevées pour l'export. Le workflow Ultimate SD Upscale combine un modèle ESRGAN (4x-UltraSharp, etc.) avec un pass de diffusion tuilé pour ajouter des détails fins.

## Spécification

### Position dans le Studio IA

- 3ème onglet du TabContainer du Studio IA (`ai_studio_dialog.gd`)
- L'URL, le Token et le Negative Prompt partagés (en haut du dialogue) s'appliquent aussi à cet onglet

### Structure de l'onglet

```
ScrollContainer "Upscale"
  VBoxContainer
    Label "Image source :"
    HBoxContainer
      TextureRect (64×64 min, aperçu cliquable → zoom)
      Label (nom de fichier)
      Button "Parcourir..."
      Button "Galerie..."
    Label "Dimension maximale :"
    HBoxContainer
      SpinBox (min=64, max=8192, step=64, défaut=2048, suffix="px")
      Label (feedback live : "→ 2048 × 3072 px (↑4.0×)")
    Label (hint, font_size=11) "Ratio préservé. Valeur inférieure = downscale."
    Label "Modèle d'upscale :"
    OptionButton [4x-UltraSharp.pth / 4x_NMKD-Siax_200k.pth / RealESRGAN_x4plus.pth / RealESRGAN_x4plus_anime_6B.pth]
    HBoxContainer
      Label "Denoise :"
      HSlider (0.0–1.0, step=0.05, défaut=0.35)
      Label valeur
    Label (hint) "0.0 — fidèle / 1.0 — créatif"
    Label "Tile size :"
    HBoxContainer (4 boutons toggle : 256 / 512 / 768 / 1024 px, défaut 512)
    Label "Prompt (optionnel) :"
    TextEdit (min_height=48, placeholder "sharp details, high quality...")
    Button "▲ Upscaler" (désactivé par défaut)
    HSeparator
    TextureRect résultat (200×200 min, cliquable → zoom)
    Label statut
    ProgressBar (indeterminate, visible=false)
    HBoxContainer
      Button "💾 Sauvegarder" (disabled=true)
      Button "↻ Regénérer" (disabled=true)
```

### Activation du bouton "▲ Upscaler"

Activé uniquement quand :
- URL ComfyUI non vide
- Image source sélectionnée

Le prompt est **optionnel**.

### Calcul des dimensions cibles

```
scale = max_dim / max(original_w, original_h)
target_w = round(original_w * scale)
target_h = round(original_h * scale)
```

Le feedback s'affiche dès qu'une image source est sélectionnée :
- `→ target_w × target_h px (↑factor×)` pour upscale
- `→ target_w × target_h px (↓factor×)` pour downscale

### Workflow ComfyUI utilisé

Nécessite le plugin ComfyUI-Ultimate-SD-Upscale.

Nœuds (dans l'ordre de traitement) :
1. `LoadImage` ("1") — source image
2. `UpscaleModelLoader` ("2") — modèle ESRGAN sélectionné
3. `ImageUpscaleWithModel` ("3") — upscale 4× via ESRGAN
4. `ImageScale` ("4") — redimensionnement exact vers target_w × target_h
5. `UNETLoader` ("75:70") — Flux 2 Klein (modèle partagé avec autres workflows)
6. `CLIPLoader` ("75:71") — CLIP partagé
7. `VAELoader` ("75:72") — VAE partagé
8. `CLIPTextEncode` ("13") — prompt utilisateur
9. `ConditioningZeroOut` ("14") — negative par défaut (remplacé par CLIPTextEncode "75:83" si negative_prompt renseigné)
10. `UltimateSDUpscale` ("20") — diffusion tuilée avec denoise et tile_size configurables
11. `SaveImage` ("9") — sortie ComfyUI

Paramètres dynamiques :
- `"1".inputs.image` — filename de l'image uploadée
- `"2".inputs.model_name` — modèle choisi dans l'OptionButton
- `"4".inputs.width` / `"4".inputs.height` — dimensions calculées
- `"13".inputs.text` — prompt (peut être vide)
- `"20".inputs.denoise` — valeur du slider
- `"20".inputs.seed` — aléatoire à chaque génération
- `"20".inputs.tile_width` / `"20".inputs.tile_height` — tile_size choisi
- `"20".inputs.steps` — steps (défaut 4, paramètre de `generate()`)
- `"20".inputs.cfg` — cfg (défaut 1.0, paramètre de `generate()`)

### Routage de sauvegarde

Lors du clic sur "💾 Sauvegarder" :
- Source dans `assets/foregrounds/` → sauvegarde dans `assets/foregrounds/`
- Source dans `assets/backgrounds/` → sauvegarde dans `assets/backgrounds/`
- Source externe → `ConfirmationDialog` "Où sauvegarder ?" avec boutons "Foreground" et "Background"

Le nom de fichier de sortie est `{source_basename}_upscaled.png`, avec résolution de conflit via `_resolve_unique_path()`.

### Annulation

Si une génération est en cours lors de la fermeture du dialogue, elle est annulée (`_cancel_upscale_generation()`).

## Tests

Fichier : `specs/ui/dialogs/test_ai_studio_dialog.gd`

- Le TabContainer a désormais **3 onglets** (index 2 = "Upscale")
- Tous les composants UI sont présents avec les valeurs par défaut correctes
- Le bouton "▲ Upscaler" est désactivé par défaut
- Le bouton s'active quand URL + source sont renseignés
- `_compute_upscale_target()` calcule correctement portrait, paysage, downscale
- Le bouton "Galerie..." est désactivé sans story, activé avec story
