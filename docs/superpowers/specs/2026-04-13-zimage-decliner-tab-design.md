# Design : Onglet "Décliner - Zimage" (remplace Assembler)

**Date :** 2026-04-13
**Statut :** Approuvé

## Objectif

Remplacer l'onglet "Assembler" dans le plugin AI Studio par un onglet "Décliner - Zimage" qui utilise le modèle Zimage Turbo bf16 (architecture AuraFlow) pour générer des variations d'images en mode img2img, avec suppression de fond automatique via BiRefNet.

## Composants touchés

| Fichier | Changement |
|---|---|
| `plugins/ai_studio/ai_studio_assembler_tab.gd` | Remplacé par `ai_studio_zimage_decliner_tab.gd` |
| `src/services/comfyui_client.gd` | + `ZIMAGE_DECLINER = 11` dans l'enum + `_build_zimage_decliner_workflow()` |
| `plugins/ai_studio/ai_studio_dialog.gd` | Remplace toutes les références à `AssemblerTab` par `ZimageDecl​inerTab` |

## Workflow ComfyUI (`WorkflowType.ZIMAGE_DECLINER`)

**Base :** `UPSCALE_ENHANCE_WORKFLOW_TEMPLATE` (contient déjà Zimage Turbo bf16).

**Modifications du template :**
- Supprimer les nœuds upscale : `87:76` (UpscaleModelLoader), `87:79` (ImageUpscaleWithModel), `87:81` (ImageScaleBy)
- Garder `87:78` (`ImageScaleToTotalPixels`, depuis `["77", 0]`) pour contrôle des mégapixels
- Rewire `87:80` (VAEEncode) : `"pixels"` depuis `["87:78", 0]` (au lieu de `["87:81", 0]`)
- KSampler `87:69` : `denoise` injecté dynamiquement (range 0.05–1.0)
- Ajouter un nœud BiRefNet (`"zd:birefnet"`) après `87:65` (VAEDecode) :
  ```json
  {
    "class_type": "BiRefNetRMBG",
    "inputs": {
      "model": "BiRefNet-general",
      "mask_blur": 0,
      "mask_offset": 0,
      "invert_output": false,
      "refine_foreground": true,
      "background": "Alpha",
      "background_color": "#222222",
      "image": ["87:65", 0]
    }
  }
  ```
- SaveImage `9` : `"images"` depuis `["zd:birefnet", 0]`

**Paramètres dynamiques injectés :**
- `77.inputs.image` → filename de l'image source uploadée
- `87:67.inputs.text` → prompt positif
- `87:71.inputs.text` → prompt négatif
- `87:69.inputs.seed` → seed aléatoire
- `87:69.inputs.steps` → steps
- `87:69.inputs.cfg` → CFG
- `87:69.inputs.denoise` → valeur du slider Denoise
- `87:78.inputs.megapixels` → mégapixels

## UI de l'onglet

Identique à `ai_studio_decliner_tab.gd`, avec les différences suivantes :

**Retiré :**
- Section LORAs (incompatible avec l'architecture AuraFlow de Zimage)
- Image source 2 (était spécifique à Klein IP-Adapter)

**Ajouté :**
- Slider **Denoise** (range 0.05–1.0, step 0.05, défaut 0.2)

**Valeurs par défaut des sliders :**

| Contrôle | Défaut |
|---|---|
| CFG | 1.0 |
| Steps | 5 |
| Denoise | 0.2 |
| Mégapixels | 1.0 |

**Suppression de fond :** toujours activée (pas de checkbox), hardcodée dans le workflow.

**Nom de l'onglet :** `"Décliner - Zimage"` (valeur du `scroll.name`).

## Signature d'appel `_client.generate`

```gdscript
_client.generate(
    config,
    _source_image_path,
    _prompt_input.text,
    true,                          # remove_background (ignoré, BiRefNet dans le workflow)
    _cfg_slider.value,
    int(_steps_slider.value),
    ComfyUIClient.WorkflowType.ZIMAGE_DECLINER,
    _denoise_slider.value,
    neg_prompt,
    80,                            # face_box_size (ignoré)
    _megapixels_slider.value,
    []                             # pas de LORAs
)
```

## Non-objectifs

- Pas de support LoRA pour Zimage Turbo (architecture incompatible avec Klein)
- Pas de deuxième image source
- Pas de checkbox "Supprimer le fond" (toujours actif)
