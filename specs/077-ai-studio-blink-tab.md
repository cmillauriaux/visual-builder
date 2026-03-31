# 077 — Onglet Blink dans le Studio IA

## Résumé

Nouvel onglet "Blink" dans le Studio IA permettant de générer des images de personnages les yeux fermés (_blink) à partir de plusieurs images sources. Les images blink sont référencées dans un manifest YAML et animées automatiquement en preview et en jeu (clignement périodique toutes les ~5s).

## Contexte / Motivation

Les personnages de visual novels paraissent figés car ils ne clignent jamais des yeux. En générant des variantes "yeux fermés" via le workflow Expression de ComfyUI et en les animant automatiquement, on donne vie aux personnages sans travail manuel supplémentaire pour le créateur.

## Spécification

### Onglet "Blink" dans le Studio IA

7ème onglet (après Upscale+Enhance) dans le `TabContainer` de `ai_studio_dialog.gd`.

#### Sélection multi-image

- Bouton **"Galerie..."** ouvre une fenêtre de sélection avec checkboxes sur chaque image
- Les images sélectionnées s'affichent dans un GridContainer (4 colonnes) avec preview 96×96, nom de fichier et bouton ✕ pour retirer
- Compteur dynamique "(N sélectionnée(s))"

#### Paramètres ComfyUI

Mêmes sliders que l'onglet Expressions :
- **CFG** : 1.0–30.0, step 0.5, défaut 1.0
- **Steps** : 1–50, step 1, défaut 4
- **Denoise** : 0.1–1.0, step 0.05, défaut 0.55
- **Mégapixels** : 0.5–4.0, step 0.5, défaut 2.0
- **Zone visage** : 10–200, step 5, défaut 10

#### Génération

- Utilise le workflow `WorkflowType.EXPRESSION` de ComfyUI
- Prompt fixe : "keep the same person, close both eyes gently as in a natural blink, adjust eyelids only, keep all colors and details of the original image, keep exactly the same eye color undertone, light color correction only"
- Traitement séquentiel via `BlinkQueueService`

#### Résultats

- Grille 4 colonnes avec preview 128×128, nom de fichier, statut coloré
- Double-clic : preview plein écran via `ImagePreviewPopup`
- Clic droit : menu contextuel "Régénérer" / "Supprimer"

#### Sauvegarde

- Images sauvegardées sous `{source}_blink.png` dans `assets/foregrounds/`
- Met à jour automatiquement `blink_manifest.yaml` via `BlinkManifestService`

### Manifest Blink

Fichier `assets/foregrounds/blink_manifest.yaml` dans le dossier de la story :

```yaml
blinks:
  hero_smile.png: hero_smile_blink.png
  hero_sad.png: hero_sad_blink.png
```

Service `BlinkManifestService` : `load_manifest()`, `save_manifest()`, `get_blink_for()`, `set_blink()`.

### Animation Blink

Composant `ForegroundBlinkPlayer` (Node avec Timer + Tween) attaché à chaque foreground ayant un blink :

- **Intervalle** : 5s ± 1s (variation aléatoire pour désynchroniser les personnages)
- **Animation** (~0.45s) : fade out 75ms → swap texture blink → fade in 75ms → hold 150ms → fade out 75ms → swap texture normale → fade in 75ms
- Intégré dans `sequence_visual_editor.gd` (fonctionne en preview éditeur ET en jeu)

### Export PCK

- `pck_chapter_builder.gd` inclut les images blink à côté de leurs sources dans les chapter PCK
- `blink_manifest.yaml` est inclus dans le core PCK (pas dans les chapter PCK)

## Fichiers créés / modifiés

| Fichier | Action |
|---------|--------|
| `plugins/ai_studio/ai_studio_blink_tab.gd` | Créé |
| `src/services/blink_queue_service.gd` | Créé |
| `src/services/blink_manifest_service.gd` | Créé |
| `src/ui/visual/foreground_blink_player.gd` | Créé |
| `plugins/ai_studio/ai_studio_dialog.gd` | Modifié |
| `src/ui/sequence/sequence_visual_editor.gd` | Modifié |
| `src/export/pck_chapter_builder.gd` | Modifié |

## Critères d'acceptation

- [x] L'onglet "Blink" apparaît dans le Studio IA
- [x] La galerie multi-sélection permet de choisir plusieurs images sources
- [x] La génération utilise le workflow Expression avec le prompt blink
- [x] Les paramètres CFG, steps, denoise, megapixels, face_box_size sont exposés
- [x] Les images générées sont nommées `{source}_blink.png`
- [x] Le `blink_manifest.yaml` est créé/mis à jour lors de la sauvegarde
- [x] En preview (éditeur), les foregrounds avec blink clignent automatiquement toutes les ~5s
- [x] En jeu, les foregrounds avec blink clignent automatiquement toutes les ~5s
- [x] Les personnages multiples ne clignent pas tous au même instant (variation aléatoire)
- [x] L'animation de blink dure ~0.45s (4 × fade 75ms + hold 150ms)
- [x] Le PCK builder inclut les images blink et le manifest
- [x] Double-clic sur un résultat ouvre la preview plein écran
- [x] Clic droit permet de régénérer ou supprimer un résultat

## Tests requis

- `specs/services/blink_queue_service/test_blink_queue_service.gd` — queue, prompt, nommage (31 tests)
- `specs/services/blink_manifest_service/test_blink_manifest_service.gd` — manifest CRUD (23 tests)
- `specs/ui/visual/foreground_blink_player/test_foreground_blink_player.gd` — animation, timing, cleanup (30 tests)
- `specs/plugins/ai_studio_blink_tab/test_ai_studio_blink_tab.gd` — UI, galerie, génération (27 tests)
