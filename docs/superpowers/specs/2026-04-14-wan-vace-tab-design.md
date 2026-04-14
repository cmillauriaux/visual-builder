# Design : Onglet Wan VACE — Séquence de poses multi-personnages

**Date** : 2026-04-14  
**Statut** : Approuvé

## Contexte

Flux Kontext (Flux2.klein) est incapable de générer des variations d'interaction entre personnages (ex : deux personnages qui s'embrassent depuis une image où ils sont face à face). Wan VACE, étant un modèle vidéo natif, peut générer une séquence temporellement cohérente à partir d'une image de référence et d'un prompt textuel, ce qui permet de décomposer un mouvement en plusieurs frames.

## Objectif

Ajouter un onglet "Wan VACE" dans l'AI Studio permettant de :
- Partir d'une image de référence (personnages assemblés)
- Décrire une interaction via un prompt textuel
- Générer une séquence de N frames extraites régulièrement depuis une vidéo Wan VACE
- Optionnellement contraindre la pose via DWPose + ControlNet

## Décisions de design

| Question | Décision |
|----------|----------|
| Un onglet ou deux (sans/avec pose) ? | Un seul onglet avec toggle |
| Variations indépendantes ou séquence temporelle ? | Séquence uniquement |
| Contrôle de la séquence | Durée (sec) + Nombre de frames à extraire |
| Pose de référence | Image → DWPose estimation → aperçu squelette avant génération |
| Suppression de fond | Toggle (pas toujours actif) |

---

## Section 1 — Architecture

### Nouveaux `WorkflowType` dans `comfyui_client.gd`

```gdscript
enum WorkflowType {
    # ... existants 0-11 ...
    WAN_VACE = 12,                # Séquence sans pose
    WAN_VACE_POSE = 13,           # Séquence avec DWPose ControlNet
    WAN_VACE_DWPOSE_PREVIEW = 14  # Estimation squelette uniquement
}
```

### Nouveaux builders dans `comfyui_client.gd`

- `_build_wan_vace_workflow(frames_to_extract: int, duration_sec: float) -> Dictionary`
- `_build_wan_vace_pose_workflow(frames_to_extract: int, duration_sec: float, controlnet_strength: float) -> Dictionary`
- `_build_wan_vace_dwpose_preview_workflow() -> Dictionary`

### Nouvelle méthode `generate_sequence()`

Signature (ajoutée en parallèle de `generate()`, sans modifier les onglets existants) :

```gdscript
func generate_sequence(
    config: ComfyUIConfig,
    source_image_path: String,
    prompt_text: String,
    remove_background: bool,
    cfg: float,
    steps: int,
    workflow_type: WorkflowType,
    denoise: float,
    negative_prompt: String,
    frames_to_extract: int,
    duration_sec: float,
    second_image_path: String = "",   # image de pose (mode WAN_VACE_POSE)
    controlnet_strength: float = 0.7
) -> void
```

Signaux émis : `sequence_completed(images: Array[Image])`, `generation_progress(step, total, preview)`, `generation_failed(error)`.

Le client récupère toutes les images depuis `/history/{prompt_id}` (le workflow génère N SaveImage nommés `frame_001` … `frame_N`), les trie par nom, et émet `sequence_completed`.

---

## Section 2 — UI de l'onglet

**Fichier** : `plugins/ai_studio/ai_studio_wan_vace_tab.gd`

### Layout (VBoxContainer vertical)

```
┌─ Label : "Wan VACE — Séquence de poses" ────────────────┐
│                                                           │
│  [Image source]                                           │
│  TextureRect (aperçu) + bouton picker + bouton galerie    │
│                                                           │
│  ╔═ Toggle ══════════════════════════════════════════╗   │
│  ║  ○ Sans pose    ● Avec pose                       ║   │
│  ╚════════════════════════════════════════════════════╝   │
│                                                           │
│  [Panneau pose — visible si "Avec pose"]                  │
│  TextureRect (aperçu image de pose)                       │
│  + bouton picker image de pose                            │
│  + bouton "Estimer la pose"                               │
│  + TextureRect aperçu squelette DWPose                    │
│  + Slider ControlNet strength (0.3–1.0, défaut 0.7)      │
│                                                           │
│  [Prompt]  TextEdit multiligne                            │
│                                                           │
│  Steps          [────●──] 20  (1–50)                      │
│  CFG             [──●────]  7  (1–10)                     │
│  Denoise        [─────●─] 0.85 (0.5–1.0)                 │
│  Durée (sec)    [──●────]  3  (1–8)                      │
│  Frames         [───●───]  6  (4–12)                      │
│  ☑ Fond transparent                                       │
│                                                           │
│  [Générer]  [Annuler]   "Frame 3 / 6…"  ProgressBar      │
│                                                           │
│  ┌──────────────── Résultats ──────────────────────────┐  │
│  │  [img1] [img2] [img3] [img4] [img5] [img6]          │  │
│  │  [💾]   [💾]   [💾]   [💾]   [💾]   [💾]           │  │
│  └─────────────────────────────────────────────────────┘  │
│  Clic sur une image → aperçu agrandi + champ nom + [💾]   │
└───────────────────────────────────────────────────────────┘
```

### Règles d'activation

| Bouton | Conditions |
|--------|-----------|
| "Estimer la pose" | Image de pose sélectionnée |
| "Générer" | URL ComfyUI configurée **ET** prompt non vide **ET** image source sélectionnée **ET** (mode pose → squelette estimé) |

### Grille résultats

`HFlowContainer` dans un `ScrollContainer`. Chaque cellule : `VBoxContainer` avec `TextureRect` (150×150) et bouton "Sauvegarder". Clic sur cellule → image agrandie dans panneau en-dessous + champ nom + bouton "Sauvegarder".

---

## Section 3 — Flux de génération

### Flow "Estimer la pose"

```gdscript
_on_estimate_pose_pressed():
    _client.generate(config, _pose_image_path, "", false,
                     1.0, 1, WorkflowType.WAN_VACE_DWPOSE_PREVIEW,
                     1.0, neg_prompt, ...)
    # signal generation_completed(skeleton_image)
    → _pose_skeleton_preview.texture = ImageTexture.create_from_image(skeleton_image)
    → _pose_estimated = true
    → update_generate_button()
```

### Flow "Générer"

```gdscript
_on_generate_pressed():
    _set_inputs_enabled(false)
    _clear_result_grid()
    _client.generate_sequence(
        config, _source_image_path, _prompt_input.text,
        _remove_bg_check.button_pressed,
        _cfg_slider.value, int(_steps_slider.value),
        WorkflowType.WAN_VACE or WAN_VACE_POSE,
        _denoise_slider.value, neg_prompt,
        int(_frames_slider.value), _duration_slider.value,
        _pose_image_path,          # "" si mode sans pose
        _strength_slider.value     # ignoré si mode sans pose
    )

# signal sequence_completed(images: Array[Image])
_on_sequence_completed(images):
    for i in images.size():
        _add_result_cell(images[i], i)
    _set_inputs_enabled(true)

# signal generation_progress(step, total, preview)
_on_generation_progress(step, total, preview):
    _progress_bar.value = float(step) / float(total)
    _status_label.text = "Frame %d / %d…" % [step, total]
```

---

## Section 4 — Composition des workflows ComfyUI

### Workflow `WAN_VACE` (sans pose)

```
[CheckpointLoader]  wan2.1-vace-14b.safetensors
    ↓ model, clip, vae
[CLIPTextEncode]  prompt  ──┐
[CLIPTextEncode]  neg     ──┤
                             ↓
[LoadImage]  source_image → [WanVideoVACEEncode]
    (image de référence)      (strength, num_frames = duration×16)
                             ↓ vace_embeds
                    [WanVideoSampler]
                      (steps, cfg, seed, scheduler=unipc,
                       num_frames = round(duration_sec × 16) arrondi au multiple de 4 valide)
                             ↓ latents
                    [VAEDecode]  → image batch (toutes les frames)
                             ↓
     [si remove_bg] [BiRefNetRemoveBackground]  (batch)
                             ↓
              [SaveImage]  output_path="frame_"
                (ComfyUI numérote automatiquement : frame_00001.png … frame_0000N.png)

# Le client ComfyUI récupère TOUS les outputs du node SaveImage depuis
# /history/{prompt_id}, les trie par nom, puis sélectionne
# frames à indices réguliers : 0, total/N, 2×total/N, …
# → retourne exactement `frames_to_extract` images
```

### Workflow `WAN_VACE_POSE` (avec pose)

Même graphe que `WAN_VACE`, avec ajout :

```
[LoadImage]  pose_image → [DWPoseEstimator]  → skeleton
                             ↓
                    [WanFunControlNetLoader]
                      wan_fun_control.safetensors
                             ↓
                    [ControlNetApply]  (strength = controlnet_strength)
                             ↑
                    injecté dans WanVideoSampler
```

### Workflow `WAN_VACE_DWPOSE_PREVIEW`

```
[LoadImage]  pose_image → [DWPoseEstimator] → [SaveImage] "skeleton"
```

### Fichiers JSON standalone (référence / debug ComfyUI UI)

- `docs/comfyui/wan_vace_no_pose.json`
- `docs/comfyui/wan_vace_with_pose.json`

Construits à partir des mêmes templates que les builders GDScript.

---

## Modèles requis

| Modèle | Chemin ComfyUI | Source |
|--------|---------------|--------|
| `wan2.1-vace-14b.safetensors` (ou GGUF Q4) | `models/wan/` | HuggingFace Wan-AI/Wan2.1-VACE-14B |
| `wan_fun_control.safetensors` | `models/controlnet/` | Compatible wan_fun_control |
| BiRefNet (déjà présent) | `models/BiRefNet/` | — |

## Custom nodes requis (ComfyUI-Manager)

- `ComfyUI-WanVideoWrapper` ou `ComfyUI-WanVideo` — fournit `WanVideoVACEEncode`, `WanVideoSampler`
- `comfyui_controlnet_aux` — fournit `DWPoseEstimator`
- `ComfyUI-WanFunControlNet` — fournit `WanFunControlNetLoader`
- `ComfyUI-BiRefNet-Hugo` (déjà présent)

## Paramètres clés

| Paramètre | Plage | Défaut | Notes |
|-----------|-------|--------|-------|
| Steps | 1–50 | 20 | Wan recommande 20–30 pour qualité |
| CFG | 1–10 | 7.0 | Plus élevé que Flux |
| Denoise | 0.5–1.0 | 0.85 | 0.85 = forte transformation tout en gardant l'identité |
| Durée (sec) | 1–8 | 3 | × 16 = nombre de frames générées |
| Frames à extraire | 4–12 | 6 | Extraites régulièrement depuis la vidéo |
| ControlNet strength | 0.3–1.0 | 0.7 | 0.6–0.8 recommandé |

## Fichiers à créer/modifier

| Fichier | Action |
|---------|--------|
| `plugins/ai_studio/ai_studio_wan_vace_tab.gd` | Créer |
| `plugins/ai_studio/ai_studio_dialog.gd` | Modifier (enregistrer l'onglet) |
| `src/services/comfyui_client.gd` | Modifier (3 WorkflowTypes, 3 builders, `generate_sequence()`) |
| `docs/comfyui/wan_vace_no_pose.json` | Créer |
| `docs/comfyui/wan_vace_with_pose.json` | Créer |
