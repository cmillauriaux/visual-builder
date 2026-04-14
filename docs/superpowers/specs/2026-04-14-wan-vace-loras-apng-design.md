# WAN VACE — LORAs dynamiques + Export APNG transparent

## Goal

Ajouter deux fonctionnalités à l'onglet WAN VACE : (1) sélection dynamique de LORAs depuis le serveur, (2) export APNG avec transparence BiRefNet sur les frames de sortie.

---

## Partie 1 — LORAs dynamiques

### UI (ai_studio_wan_vace_tab.gd)

Même pattern que l'onglet Create :

- `_loras_vbox: VBoxContainer` — liste des LORAs ajoutés (rows dynamiques)
- `_lora_option: OptionButton` — "Ajouter un LoRA…" + items du serveur
- Bouton "⟳" → appelle `_refresh_loras()` qui utilise `get_available_loras` (déjà dans `comfyui_client.gd`)
- Sélectionner un item → ajoute une row : `[nom tronqué] [HSlider 0.0–2.0, défaut 1.0] [×]`
- `×` retire la row et l'entrée de `_selected_loras`
- `_selected_loras: Array` de `{"name": String, "strength": float}` (même structure que Create tab)
- Cache local (`user://comfyui_discovery_cache_wan.cfg`) pour pré-remplir entre sessions

### generate_sequence

Nouveau paramètre en fin de signature :
```gdscript
func generate_sequence(
    ...
    fps: int = 8,
    loras: Array = [],
    transparent_output: bool = false
) -> void
```

Instance vars ajoutées : `var _loras: Array = []` et `var _transparent_output: bool = false`.

### Injection LORAs dans les workflows

**WAN VACE / VACE-Pose** (`_build_wan_vace_workflow`) :

`LoraLoaderModelOnly` chaînés depuis `wv:model`, la sortie finale alimente `wv:sampler["model"]`.
```
wv:model → wv:lora_0 → wv:lora_1 → ... → wv:sampler["model"]
```
Chaque nœud :
```gdscript
"wv:lora_%d" % i: {
    "class_type": "LoraLoaderModelOnly",
    "inputs": {
        "model": ["wv:model", 0] if i == 0 else ["wv:lora_%d" % (i-1), 0],
        "lora_name": lora["name"],
        "strength_model": lora["strength"]
    }
}
```
Si loras non vide : `wf["wv:sampler"]["inputs"]["model"] = ["wv:lora_%d" % (loras.size()-1), 0]`

**WAN I2V** (`_build_wan_i2v_workflow`) :

Deux chaînes séparées, une par UNET (high + low) :
```
i2v:unet_high → i2v:lora_high_0 → ... → i2v:sampler1["model"]
i2v:unet_low  → i2v:lora_low_0  → ... → i2v:sampler2["model"]
```
Chaque nœud (pour suffixe `sfx` = `"high"` ou `"low"`, unet_key = `"i2v:unet_high"` ou `"i2v:unet_low"`) :
```gdscript
"i2v:lora_%s_%d" % [sfx, i]: {
    "class_type": "LoraLoaderModelOnly",
    "inputs": {
        "model": [unet_key, 0] if i == 0 else ["i2v:lora_%s_%d" % [sfx, i-1], 0],
        "lora_name": lora["name"],
        "strength_model": lora["strength"]
    }
}
```
Si loras non vide :
```gdscript
wf["i2v:sampler1"]["inputs"]["model"] = ["i2v:lora_high_%d" % (loras.size()-1), 0]
wf["i2v:sampler2"]["inputs"]["model"] = ["i2v:lora_low_%d" % (loras.size()-1), 0]
```

`_do_prompt_sequence` passe `_loras` à chaque builder.

---

## Partie 2 — Export APNG avec transparence

### Transparence sortie

Nouvelle checkbox **"Fond transparent (sortie)"** dans la section paramètres.

Quand cochée, les builders ajoutent un nœud `BiRefNetRMBG` **après** le décodeur vidéo.

**VACE :** `wv:birefnet_out` → `["wv:decode", 0]`, puis `"9"["images"] = ["wv:birefnet_out", 0]`

Distinct du `wv:birefnet` existant qui traite l'image source (inchangé).

**I2V :** nœud `i2v:birefnet_out` → `["i2v:decode", 0]`, puis `"9"["images"] = ["i2v:birefnet_out", 0]`

Paramètres BiRefNet identiques :
```gdscript
{
    "class_type": "BiRefNetRMBG",
    "inputs": {
        "model": "BiRefNet-general",
        "mask_blur": 0, "mask_offset": 0,
        "invert_output": false, "refine_foreground": true,
        "background": "Alpha", "background_color": "#222222",
        "image": [decode_node_id, 0]
    }
}
```

### Service ApngBuilder (src/services/apng_builder.gd)

```gdscript
class_name ApngBuilder

## Assemble frames RGBA en APNG. Retourne PackedByteArray (fichier APNG).
## frames: Array[Image], fps: int (>0), loops: int (0 = infini)
static func build(frames: Array, fps: int, loops: int = 0) -> PackedByteArray
```

**Algorithme :**
1. Pour chaque frame : `image.save_png_to_buffer()` → PNG bytes
2. Parser chaque PNG pour extraire : IHDR (frame 0 seulement) + IDAT chunks
3. Assembler APNG :
   - Signature PNG (8 bytes)
   - IHDR (du frame 0)
   - Chunk `acTL` : `num_frames` (uint32 BE) + `num_plays` (uint32 BE)
   - Pour chaque frame i :
     - Chunk `fcTL` : seq_num, width, height, x=0, y=0, delay_num=1, delay_den=fps, dispose_op=0, blend_op=0
     - Chunk `IDAT` (si i==0) ou `fdAT` (si i>0, préfixé du seq_num uint32 BE)
   - Chunk `IEND`
4. CRC32 calculé pour chaque chunk (utilise `HashingContext` avec algo CRC32)

**Parsing PNG :** itère les chunks (4B len + 4B type + data + 4B CRC). Collecte tous les chunks `IDAT` par frame.

### UI après génération (ai_studio_wan_vace_tab.gd)

Après `_selected_cell_vbox`, nouvelle section **`_export_panel`** (VBoxContainer, visible quand `_generated_images` non vide) :

```
── Export ──────────────────────────────
Frames : [SpinBox _range_start] → [SpinBox _range_end]   (1..N)
[Exporter frames]   [Exporter APNG]
```

- `_range_start`, `_range_end` : SpinBox, mis à jour à chaque génération (max = N frames)
- "Exporter frames" → FileDialog dossier → sauvegarde frames[start-1..end-1] comme PNG numérotés
- "Exporter APNG" → FileDialog fichier `.apng` → `ApngBuilder.build(frames[start-1..end-1], fps)` → `FileAccess.store_buffer`

### Fichiers modifiés / créés

| Fichier | Action |
|---------|--------|
| `src/services/apng_builder.gd` | Créer |
| `src/services/comfyui_client.gd` | Modifier : `generate_sequence` + builders |
| `plugins/ai_studio/ai_studio_wan_vace_tab.gd` | Modifier : UI LORAs + transparence + export panel |
| `specs/services/test_comfyui_client_wan_vace.gd` | Modifier : tests LORAs + transparence |
| `specs/services/test_apng_builder.gd` | Créer |

---

## Tests

**test_comfyui_client_wan_vace.gd (nouveaux) :**
- `test_build_wan_i2v_workflow_with_loras` — vérifie `i2v:lora_high_0`, `i2v:lora_low_0`, modèle du sampler1/sampler2 pointent sur la dernière LORA
- `test_build_wan_vace_workflow_with_loras` — vérifie `wv:lora_0`, modèle du sampler pointe sur la dernière LORA
- `test_build_wan_i2v_workflow_no_loras_no_lora_nodes` — sans LORA, aucun nœud `lora_` dans le workflow
- `test_build_wan_i2v_workflow_transparent_output` — vérifie `i2v:birefnet_out`, node 9 pointe sur `i2v:birefnet_out`
- `test_build_wan_vace_workflow_transparent_output` — vérifie `wv:birefnet_out` distinct de `wv:birefnet` (source)

**test_apng_builder.gd :**
- `test_build_returns_non_empty_bytes` — APNG non vide avec 2 frames
- `test_build_starts_with_png_signature` — premiers 8 bytes = `\x89PNG\r\n\x1a\n`
- `test_build_contains_actl_chunk` — bytes contiennent "acTL"
- `test_build_single_frame_produces_valid_png` — 1 frame → APNG lisible comme PNG standard
