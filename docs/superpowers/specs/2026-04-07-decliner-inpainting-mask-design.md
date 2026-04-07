# Design — Masque inpainting dans l'onglet Décliner

**Date** : 2026-04-07  
**Statut** : Approuvé

## Objectif

Permettre à l'utilisateur de définir une zone rectangulaire sur l'image source dans l'onglet "Décliner" du plugin AI Studio. Cette zone est transmise au workflow ComfyUI comme masque d'inpainting : seule la zone sélectionnée est régénérée, le reste de l'image est préservé pixel pour pixel.

---

## UI

### Section "Masque Inpainting" dans `ai_studio_decliner_tab.gd`

Ajoutée entre le sélecteur d'image source et la section prompt. Composée de :

1. **Checkbox / header** — "MASQUE INPAINTING" (désactivé par défaut)
2. **Aperçu interactif de l'image source** — le `TextureRect` existant devient interactif quand le masque est activé :
   - Clic + glisser dessine un rectangle (coin haut-gauche → coin bas-droit)
   - Le rectangle est affiché en superposition (bordure bleue en pointillés, fond bleu semi-transparent)
   - Poignées de coin visibles
3. **Affichage des coordonnées** — `x: N  y: N  l: N  h: N` (en pixels dans l'espace de l'image source, pas du preview)
4. **Bouton "Effacer"** — remet le masque à null
5. **Slider "Fondu"** — 0–100, défaut 15 — contrôle le `GrowMask` + `ImpactGaussianBlurMask` pour adoucir les bords du masque

Quand aucun masque n'est défini, le bouton Générer utilise le workflow `CREATION` existant (comportement inchangé). Quand un masque est défini, le workflow bascule automatiquement sur `INPAINT`.

---

## Génération du masque PNG côté GDScript

Dans `ai_studio_decliner_tab.gd`, au moment de la génération :

1. Charger l'image source pour obtenir ses dimensions réelles (`width`, `height`)
2. Créer une `Image` noire de mêmes dimensions (`FORMAT_L8`)
3. Remplir le rectangle en blanc (`fill_rect`)
4. Encoder en PNG bytes (`save_png_to_buffer`)
5. Passer les bytes en tant que `mask_bytes` au client ComfyUI

Les coordonnées du rectangle (stockées dans l'espace du preview) sont remises à l'échelle des dimensions réelles de l'image source avant la génération du PNG.

---

## Workflow : nouveau `WorkflowType.INPAINT`

### Nouveau type dans `comfyui_client.gd`

```gdscript
enum WorkflowType {
    CREATION = 0,
    EXPRESSION = 1,
    OUTPAINT = 2,
    UPSCALE = 3,
    ENHANCE = 4,
    UPSCALE_ENHANCE = 5,
    BLINK = 6,
    INPAINT = 7,   # nouveau
}
```

### Template de workflow `INPAINT_WORKFLOW_TEMPLATE`

Basé sur `WORKFLOW_TEMPLATE` (CREATION), avec les nœuds supplémentaires suivants (IDs distincts pour éviter les collisions) :

| Node ID | Class | Rôle |
|---------|-------|------|
| `ip:mask_input` | `LoadImage` | Charge le PNG masque uploadé |
| `ip:grow` | `GrowMask` | Expansion du masque (slider Fondu) |
| `ip:blur` | `ImpactGaussianBlurMask` | Adoucissement des bords |
| `ip:noise_mask` | `SetLatentNoiseMask` | Applique le masque au latent |
| `ip:composite` | `ImageCompositeMasked` | Recolle le résultat sur l'image originale |

**Paramètres dynamiques** (injectés par `_build_inpaint_workflow`) :
- `mask_filename` — nom du fichier masque uploadé dans ComfyUI
- `mask_feather` (0–100) → `GrowMask.expand` et `ImpactGaussianBlurMask` (kernel/sigma proportionnels, comme Blink)
- `denoise` → `SplitSigmas.step` (comme CREATION)

### Méthode `_build_inpaint_workflow`

Signature :
```gdscript
func _build_inpaint_workflow(
    filename: String,
    mask_filename: String,
    prompt_text: String,
    seed: int,
    remove_background: bool,
    cfg: float,
    steps: int,
    denoise: float,
    mask_feather: int,
    megapixels: float,
    loras: Array
) -> Dictionary
```

### Upload du masque

Même mécanique que l'image source :
- **Local ComfyUI** : multipart upload vers `/upload/image`, récupère le filename retourné
- **RunPod** : base64 dans le champ `images` du payload

La signature de `generate()` dans `comfyui_client.gd` est étendue avec des paramètres optionnels :
```gdscript
func generate(
    source_image_path: String,
    prompt: String,
    ...,
    mask_bytes: PackedByteArray = PackedByteArray(),
    mask_feather: int = 15
) -> void
```

---

## Comportement si le masque est absent

`mask_bytes` vide → workflow `CREATION` standard (aucun changement de comportement existant).

---

## Fichiers modifiés

| Fichier | Modification |
|---------|-------------|
| `plugins/ai_studio/ai_studio_decliner_tab.gd` | Section Masque UI + logique dessin rectangle + génération PNG masque |
| `src/services/comfyui_client.gd` | `WorkflowType.INPAINT`, `INPAINT_WORKFLOW_TEMPLATE`, `_build_inpaint_workflow()`, extension de `generate()` |

---

## Hors scope

- Masque non-rectangulaire (pinceau libre)
- Import d'un fichier masque externe
- Persistance du masque entre sessions
- Undo/redo du dessin de masque
