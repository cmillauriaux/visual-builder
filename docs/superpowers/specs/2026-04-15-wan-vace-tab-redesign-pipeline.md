# WAN VACE Tab — Redesign Pipeline Génération / Sélection / Export

**Goal:** Refactoriser l'onglet Wan VACE en un pipeline en 5 sections progressives : générer une fois toutes les frames brutes, puis sélectionner / sous-échantillonner / appliquer BiRefNet / exporter sans relancer la génération.

**Architecture:** Machine d'état (IDLE → GENERATING → FRAMES_READY → BG_PROCESSING → FRAMES_READY) ; sections 2–5 révélées progressivement après génération. Nouveau `apply_birefnet()` dans `ComfyUIClient` pour le traitement batch post-génération.

**Tech Stack:** GDScript 4.6, GUT 9.3.0, ComfyUI API (BiRefNetRMBG node), ApngBuilder existant.

---

## Section 1 — Génération

Paramètres identiques à aujourd'hui **sauf** :
- `_remove_bg_check` supprimé — la génération produit toujours des frames brutes (pas de BiRefNet pendant la génération)
- `_transparent_output_check` supprimé — idem
- `_debug_save_video_check` conservé
- `generate_sequence()` appelé avec `remove_background=false`, `transparent_output=false`

Contenu conservé : source image, mode toggle (sans pose / avec pose), panneau pose, prompt, CFG (défaut 4.0), steps, denoise, durée, FPS, LORAs, [Générer] / [Annuler], status, progress bar.

## Section 2 — Résultats

Apparaît après la génération (`FRAMES_READY`).

- **Preview animation** : `TextureRect` + `Timer` auto-démarré au FPS de génération, affiche la boucle de toutes les frames générées
- **Label** : "N frames générées"
- **Grille** : `HFlowContainer` de miniatures (toutes les frames générées), clic → agrandit dans la preview

## Section 3 — Sélection

Apparaît avec la section 2.

- **SpinBox "Début"** : 1 .. total_frames, défaut 1
- **SpinBox "Fin"** : 1 .. total_frames, défaut total_frames
- **SpinBox "N frames"** : 1 .. (fin - début + 1), défaut `min(8, total_frames)`
- La preview animation se met à jour **live** pour afficher uniquement les N frames sous-échantillonnées

**Algorithme de sous-échantillonnage** (indices 0-based) :
```
si N == 1 : [début-1]
sinon     : pour i in range(N) : round((début-1) + i * (fin-début) / (N-1))
```
Résultat : première frame = début, dernière frame = fin, le reste réparti uniformément.

`_selected_frames: Array` — cache des N frames résultantes (mis à jour à chaque changement de spinbox).

## Section 4 — Fond transparent

Apparaît avec la section 2.

- **Bouton** "Appliquer BiRefNet sur sélection"
- **Label de progression** : "X/N frames traitées..." (mis à jour à chaque frame)
- Pendant le traitement : état `BG_PROCESSING`, bouton désactivé, section 1 désactivée

**Implémentation :**
- Nouveau `WorkflowType.BIREFNET_ONLY` dans `ComfyUIClient`
- Nouveau `func apply_birefnet(config, image: Image) -> void` — upload + workflow minimal → émet `generation_completed(image)` ou `generation_failed(error)`
- Nouveau `_build_birefnet_workflow(source_filename: String) -> Dictionary` :
  ```
  LoadImage → BiRefNetRMBG (model=BiRefNet-general, background=Alpha) → SaveImage
  ```
- Le tab appelle `apply_birefnet` séquentiellement sur chaque frame de `_selected_frames`
- Chaque résultat remplace la frame correspondante dans `_selected_frames` **et** dans la grille (thumbnail mis à jour) + preview relancée

## Section 5 — Export

Apparaît dès qu'il y a des frames générées (`FRAMES_READY` ou `BG_PROCESSING`).

```
Préfixe [ LineEdit ]  [→ foregrounds/]
Nom APNG [ LineEdit ]  [→ animations/]
```

- **→ foregrounds/** : exporte `_selected_frames` sous `assets/foregrounds/<préfixe>_001.png`, `_002.png`, etc. Invalide le cache galerie.
- **→ animations/** : exporte `_selected_frames` en APNG via `ApngBuilder.build(frames, fps)` sous `assets/animations/<nom>.apng`. Le FPS utilisé est `_fps_slider.value`.

## Machine d'état

| État | Sections visibles | Actions possibles |
|---|---|---|
| `IDLE` | 1 | Générer |
| `GENERATING` | 1 (inputs désactivés) | Annuler |
| `FRAMES_READY` | 1–5 | Tout |
| `BG_PROCESSING` | 1 (désactivée) + 2–5 (export désactivé) | Annuler BiRefNet |

## Fichiers modifiés

- **Modifier** : `plugins/ai_studio/ai_studio_wan_vace_tab.gd` — refactor complet des sections, machine d'état, `_selected_frames`, sous-échantillonnage
- **Modifier** : `src/services/comfyui_client.gd` — `WorkflowType.BIREFNET_ONLY`, `apply_birefnet()`, `_build_birefnet_workflow()`
- **Modifier** : `specs/services/test_comfyui_client.gd` — tests pour `_build_birefnet_workflow`

## Critères d'acceptation

- [ ] La génération produit toujours des frames brutes (sans BiRefNet intégré)
- [ ] Toutes les frames générées s'affichent dans la grille après génération
- [ ] La preview animation démarre automatiquement au bon FPS
- [ ] Les spinboxes Début/Fin/N frames sous-échantillonnent correctement (premier = début, dernier = fin)
- [ ] La preview se met à jour live quand les spinboxes changent
- [ ] BiRefNet batch traite les N frames sélectionnées séquentiellement et remplace en place
- [ ] La progression BiRefNet est affichée (X/N)
- [ ] Export APNG respecte le FPS de génération
- [ ] Export foregrounds crée les fichiers dans `assets/foregrounds/`
