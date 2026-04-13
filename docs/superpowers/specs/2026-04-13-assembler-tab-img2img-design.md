# Assembler Tab — img2img avec contrôle denoise

**Date :** 2026-04-13
**Contexte :** L'onglet Décliner utilise `WorkflowType.CREATION` qui démarre depuis un latent vide (`EmptyFlux2LatentImage`). Avec CFG=1.0 (défaut), le prompt est ignoré ; avec CFG>3, les couleurs dérivent. La solution est un nouvel onglet "Assembler" avec un workflow img2img dédié qui démarre depuis l'image source, préservant les couleurs tout en permettant les changements structurels (pose, inclinaison de tête, etc.).

## Problème racine

- **CREATION** : latent de départ = bruit pur → les couleurs ne sont pas ancrées dans l'image source
- **CFGGuider à 1.0** : `output = positive × 1 − negative × 0 = positive` sans amplification du texte → le prompt de changement est silencieux
- **Solution** : partir du latent encodé de l'image source + SplitSigmas pour contrôle du denoise, comme le fait déjà `_build_expression_workflow`

## Décision : Décliner reste intact

L'onglet Décliner n'est pas modifié. Le nouvel onglet "Assembler" coexiste avec lui pour les cas où on veut des modifications structurelles avec préservation des couleurs.

---

## Section 1 — `WorkflowType.ASSEMBLER` dans `comfyui_client.gd`

### Enum
```gdscript
enum WorkflowType { CREATION = 0, EXPRESSION = 1, OUTPAINT = 2, UPSCALE = 3, ENHANCE = 4,
    UPSCALE_ENHANCE = 5, BLINK = 6, INPAINT = 7, LORA_CREATE_FLUX = 8, ILLUSTRIOUS = 9,
    ASSEMBLER = 10 }
```

### Builder `_build_assembler_workflow`

Signature :
```gdscript
func _build_assembler_workflow(
    filename: String, prompt_text: String, seed: int,
    remove_background: bool, cfg: float, steps: int, denoise: float,
    negative_prompt: String, megapixels: float, loras: Array
) -> Dictionary
```

Étapes :
1. `var wf = EXPRESSION_WORKFLOW_TEMPLATE.duplicate(true)`
2. **Supprimer nœuds YOLO** : `wf.erase("99")`, `wf.erase("100")`, `wf.erase("101")`, `wf.erase("102")`, `wf.erase("103")`
3. **Rewire BiRefNet** : `wf["106"]["inputs"]["image"] = ["75:65", 0]` (VAEDecode → BiRefNet directement)
4. **img2img** : `wf["75:64"]["inputs"]["latent_image"] = ["75:79:78", 0]`
5. **SplitSigmas** (même pattern qu'Expression) :
   ```gdscript
   var split_step = max(1, roundi(steps * (1.0 - denoise)))
   wf["split_sigmas"] = { "class_type": "SplitSigmas", "inputs": { "sigmas": ["75:62", 0], "step": split_step } }
   wf["75:64"]["inputs"]["sigmas"] = ["split_sigmas", 1]
   wf.erase("75:66")
   ```
6. **BiRefNet conditionnel** : si `not remove_background` → `wf["9"]["inputs"]["images"] = ["75:65", 0]` + `wf.erase("106")`
7. Paramètres standards : image, texte, seed, cfg, steps, megapixels, negative prompt, LoRAs

### Dispatch dans `build_workflow`
```gdscript
if workflow_type == WorkflowType.ASSEMBLER:
    return _build_assembler_workflow(filename, prompt_text, seed, _remove_background,
        cfg, steps, denoise, negative_prompt, megapixels, loras)
```

---

## Section 2 — `ai_studio_assembler_tab.gd`

Nouveau fichier `plugins/ai_studio/ai_studio_assembler_tab.gd`, calqué sur `ai_studio_decliner_tab.gd`.

### Différences vs Décliner

| Élément | Décliner | Assembler |
|---|---|---|
| Tab name | `"Décliner"` | `"Assembler"` |
| CFG défaut | 1.0 | 3.0 |
| Slider Denoise | absent | 0.05–1.0, step 0.05, défaut 0.5 |
| CheckBox "Supprimer le fond" | absent (toujours actif) | présente, cochée par défaut |
| Section "Image 2 pour Klein" | présente | absente |
| WorkflowType | CREATION | ASSEMBLER |
| Paramètre `remove_background` | `true` hardcodé | depuis la checkbox |
| Paramètre `denoise` | 0.5 hardcodé | depuis le slider |

### Placement du slider Denoise
Entre le slider Steps et le slider Megapixels.

### Placement de la CheckBox
Juste avant le bouton Générer, dans la même VBox.

### Appel `generate()`
```gdscript
_client.generate(
    config, _source_image_path, _prompt_input.text,
    _remove_background_cb.button_pressed,  # remove_background depuis checkbox
    cfg_value, steps_value,
    ComfyUIClient.WorkflowType.ASSEMBLER,
    _denoise_slider.value,                 # denoise depuis slider
    neg_prompt, 80, _megapixels_slider.value,
    _get_selected_loras()
)
```

---

## Section 3 — `ai_studio_dialog.gd`

Ajouts symétriques aux autres onglets :

```gdscript
const AssemblerTab = preload("res://plugins/ai_studio/ai_studio_assembler_tab.gd")
var _assembler_tab: RefCounted = null
```

Position dans le `for tab in [...]` : juste après `_decl_tab`.

Méthodes à mettre à jour :
- `setup()` : `_assembler_tab.setup(story_base_path, has_story)`
- `_on_close()` : `_assembler_tab.cancel_generation()`
- `_update_all_generate_buttons()` : `_assembler_tab.update_generate_button()`
- `_update_cfg_hints()` : ajouter `_assembler_tab` dans le `for tab in [...]` existant (liste explicite, pas auto-découverte)

---

## Critères d'acceptance

1. L'onglet "Assembler" apparaît dans le dialog AI Studio après "Décliner"
2. Avec denoise=0.5 et CFG=3, une demande de changement de pose modifie la pose tout en préservant les couleurs
3. La checkbox "Supprimer le fond" active/désactive BiRefNet
4. L'onglet Décliner fonctionne exactement comme avant (aucune régression)
5. Les LORAs sont sélectionnables dans Assembler
6. Le hint CFG s'affiche correctement si negative prompt non vide et CFG < 3
