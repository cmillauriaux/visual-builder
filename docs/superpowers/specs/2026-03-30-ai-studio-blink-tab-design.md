# Design : Onglet Blink dans le Studio IA

## Contexte

Les personnages de visual novels paraissent figés car ils ne clignent jamais des yeux. L'objectif est de permettre aux créateurs de générer des variantes "yeux fermés" (_blink) de leurs images de personnages, puis de jouer automatiquement une animation de clignement en jeu et en preview pour donner vie aux personnages.

Le TODO.md mentionne déjà "Générer des images 'blink'" comme tâche à réaliser.

## Décisions de design

| Question | Décision |
|----------|----------|
| Découverte des _blink en jeu | Manifest YAML (`blink_manifest.yaml`) |
| Animation | Swap instantané (fade 75ms → hold 150ms → fade 75ms) |
| Timing | Fixe global (~5s ± random, durée 0.5s total) |
| Paramètres ComfyUI | Exposés (mêmes sliders que l'onglet Expressions) |

## Spécification

### 1. Onglet "Blink" dans le Studio IA

Nouvel onglet (index 6, 7ème tab) dans le `TabContainer` de `ai_studio_dialog.gd`.

#### UI

```
VBoxContainer
  HBoxContainer                      # Section galerie
    Label "Images sources :"
    Button "Galerie..."              # Ouvre le picker multi-sélection
    Label "(0 sélectionnée(s))"      # Compteur dynamique
  ScrollContainer                    # Preview des images sélectionnées
    GridContainer (4 colonnes)
      [Panel: TextureRect 96×96 + Label filename + Button ✕]  # Par image
  HSeparator
  HBoxContainer                      # Paramètres
    VBoxContainer
      Label "CFG :" + HSlider (1.0–30.0, step 0.5, défaut 1.0) + Label valeur
      Label "Steps :" + HSlider (1–50, step 1, défaut 4) + Label valeur
      Label "Denoise :" + HSlider (0.1–1.0, step 0.05, défaut 0.55) + Label valeur
      Label "Megapixels :" + HSlider (0.5–4.0, step 0.5, défaut 2.0) + Label valeur
      Label "Face Box Size :" + HSlider (10–200, step 5, défaut 10) + Label valeur
  HSeparator
  HBoxContainer                      # Actions
    Button "Générer les blinks"      # Désactivé si aucune image sélectionnée
    Button "Annuler"                 # Visible uniquement pendant la génération
    Label statut                     # "X/Y générés"
    ProgressBar
  HSeparator
  ScrollContainer                    # Résultats
    GridContainer (4 colonnes)
      [Panel: TextureRect source 64×64 → TextureRect blink 128×128 + Label + status]
  HBoxContainer
    Button "Tout sauvegarder"        # Sauvegarde les blinks générés
    Button "Aperçu"                  # Preview plein écran navigable
```

#### Galerie multi-sélection

Le bouton "Galerie..." ouvre une fenêtre de sélection identique à celle existante dans `ai_studio_dialog._open_gallery_source_picker()`, mais avec multi-sélection activée (checkboxes sur chaque image). L'utilisateur coche les images voulues puis valide.

#### Interactions

- **Double-clic** sur un résultat : preview plein écran via `ImagePreviewPopup`
- **Clic droit** : menu contextuel "Régénérer" / "Supprimer"
- **Bouton Aperçu** : `ImagePreviewPopup` en mode collection avec navigation ◀/▶

### 2. BlinkQueueService

Nouveau service `src/services/blink_queue_service.gd` (similaire à `ExpressionQueueService`).

```gdscript
extends RefCounted

enum ItemStatus { PENDING, GENERATING, COMPLETED, FAILED }

var _items: Array = []    # [{source_path, blink_filename, prompt, status, image}]
var _cancelled: bool = false
```

**Différence clé avec ExpressionQueueService** : itère sur N images sources avec 1 prompt fixe (au lieu de 1 image × N prompts).

#### Méthodes

- `build_queue(source_paths: Array) -> void` — construit la file à partir des chemins sources
- `get_items() / get_total() / get_next_pending_index()` — navigation dans la file
- `mark_generating(index) / mark_completed(index, image) / mark_failed(index, error)` — gestion d'état
- `cancel() / is_cancelled()` — annulation
- `get_completed_count() / get_done_count() / get_completed_items()` — statistiques
- `reset_item(index) / remove_item(index)` — régénération / suppression

#### Prompt

```
keep the same person, close both eyes gently as in a natural blink, adjust eyelids only, keep all colors and details of the original image, keep exactly the same eye color undertone, light color correction only
```

#### Convention de nommage

Pour une image source `hero_smile.png`, le blink sera `hero_smile_blink.png`. Le suffixe `_blink` est ajouté avant l'extension :

```gdscript
static func _build_blink_filename(source_path: String) -> String:
    var base = source_path.get_file().get_basename()  # "hero_smile"
    return base + "_blink.png"
```

### 3. Manifest Blink

#### Fichier

`assets/foregrounds/blink_manifest.yaml` dans le dossier de la story.

```yaml
blinks:
  hero_smile.png: hero_smile_blink.png
  hero_sad.png: hero_sad_blink.png
  npc_neutral.png: npc_neutral_blink.png
```

Les clés et valeurs sont des noms de fichiers relatifs à `assets/foregrounds/`.

#### Service

Nouveau `src/services/blink_manifest_service.gd` :

```gdscript
extends RefCounted
class_name BlinkManifestService

const MANIFEST_FILENAME = "blink_manifest.yaml"

static func load_manifest(story_base_path: String) -> Dictionary
static func save_manifest(story_base_path: String, manifest: Dictionary) -> void
static func get_blink_for(story_base_path: String, image_filename: String) -> String
    # Retourne le nom du fichier blink ou "" si non trouvé
static func set_blink(story_base_path: String, source_filename: String, blink_filename: String) -> void
    # Ajoute/met à jour une entrée et sauvegarde
```

**Mise à jour du manifest** : automatique lors du "Tout sauvegarder" dans l'onglet Blink.

### 4. Animation Blink en jeu et preview

#### Composant ForegroundBlinkPlayer

Nouveau `src/ui/visual/foreground_blink_player.gd` :

```gdscript
extends Node

## Gère l'animation de clignement pour un foreground individuel.

const BLINK_INTERVAL_BASE := 5.0      # Intervalle moyen entre blinks (secondes)
const BLINK_INTERVAL_RANDOM := 1.0    # Variation aléatoire ± (secondes)
const BLINK_FADE_DURATION := 0.075    # Durée du fade in/out (secondes)
const BLINK_HOLD_DURATION := 0.15     # Durée yeux fermés (secondes)

var _texture_rect: TextureRect        # Le TextureRect du foreground
var _normal_texture: Texture2D        # Texture yeux ouverts
var _blink_texture: Texture2D         # Texture yeux fermés
var _timer: Timer
var _is_blinking: bool = false
```

#### Logique

1. Au démarrage : charge la texture blink, crée un Timer avec intervalle aléatoire
2. Quand le Timer expire :
   - Tween : `modulate:a` de 1.0 → 0.0 en 75ms
   - Swap texture vers `_blink_texture`
   - Tween : `modulate:a` de 0.0 → 1.0 en 75ms
   - Attendre 150ms (hold)
   - Tween : `modulate:a` de 1.0 → 0.0 en 75ms
   - Swap texture vers `_normal_texture`
   - Tween : `modulate:a` de 0.0 → 1.0 en 75ms
3. Recalculer le prochain intervalle avec variation aléatoire
4. Si l'image du foreground change (transition de dialogue), mettre à jour `_normal_texture` et `_blink_texture` (ou désactiver si le nouveau foreground n'a pas de blink)
5. Nettoyage : arrêter le timer et tween quand le foreground est supprimé

#### Intégration dans sequence_visual_editor.gd

Dans `_update_single_fg_visual(fg)`, après le chargement de la texture (ligne ~478) :
1. Charger le manifest blink (cache en mémoire, rechargé une fois par séquence)
2. Si le foreground a un blink, créer/attacher un `ForegroundBlinkPlayer` au wrapper
3. Si le foreground n'a pas/plus de blink, supprimer le player existant

#### Intégration dans game_play_controller.gd

Dans `_prepare_opening_visuals()` et `_update_preview()` :
1. Après le chargement des foregrounds, vérifier le manifest
2. Créer un `ForegroundBlinkPlayer` pour chaque foreground avec blink

### 5. Export PCK

#### Modification de `pck_chapter_builder.gd`

Dans `_collect_sequence_assets()` (ligne 326), après la collecte des foregrounds :

```gdscript
# Ajouter les images blink référencées dans le manifest
var blink_manifest = BlinkManifestService.load_manifest(story_base_path)
for fg in sequence.foregrounds:
    if fg.image != "":
        var fg_filename = fg.image.get_file()
        var blink_filename = blink_manifest.get("blinks", {}).get(fg_filename, "")
        if blink_filename != "":
            var blink_path = fg.image.get_base_dir().path_join(blink_filename)
            assets.append(blink_path)
```

Même logique pour les foregrounds de dialogue.

Le fichier `blink_manifest.yaml` lui-même doit être inclus dans le **core PCK** (ajouté aux `menu_assets` ou à un nouveau groupe "shared assets" dans `_collect_menu_assets()`).

### 6. Fichiers créés / modifiés

| Fichier | Action |
|---------|--------|
| `plugins/ai_studio/ai_studio_blink_tab.gd` | **Créer** — onglet Blink UI + logique de génération |
| `src/services/blink_queue_service.gd` | **Créer** — file d'attente de génération blink |
| `src/services/blink_manifest_service.gd` | **Créer** — lecture/écriture du manifest YAML |
| `src/ui/visual/foreground_blink_player.gd` | **Créer** — animation de clignement |
| `plugins/ai_studio/ai_studio_dialog.gd` | **Modifier** — ajouter l'onglet Blink au TabContainer |
| `src/ui/sequence/sequence_visual_editor.gd` | **Modifier** — intégrer ForegroundBlinkPlayer |
| `src/controllers/game_play_controller.gd` | **Modifier** — intégrer ForegroundBlinkPlayer |
| `src/export/pck_chapter_builder.gd` | **Modifier** — inclure blink images + manifest dans les PCK |
| `specs/077-ai-studio-blink-tab.md` | **Créer** — spécification Markdown |

### 7. Tests

| Fichier test | Couverture |
|-------------|-----------|
| `specs/services/blink_queue_service/test_blink_queue_service.gd` | Queue : build, iterate, mark, cancel, nommage |
| `specs/services/blink_manifest_service/test_blink_manifest_service.gd` | Manifest : load, save, get_blink_for, set_blink |
| `specs/ui/visual/foreground_blink_player/test_foreground_blink_player.gd` | Animation : timing, swap, cleanup |
| `specs/plugins/ai_studio_blink_tab/test_ai_studio_blink_tab.gd` | UI : galerie multi-sélection, génération, sauvegarde |
| `specs/export/pck_chapter_builder/test_pck_chapter_builder.gd` | **Modifier** — vérifier inclusion des blink images |

### 8. Critères d'acceptation

- [ ] L'onglet "Blink" apparaît en 7ème position dans le Studio IA
- [ ] La galerie multi-sélection permet de choisir plusieurs images sources
- [ ] La génération utilise le workflow Expression avec le prompt blink spécifique
- [ ] Les paramètres CFG, steps, denoise, megapixels, face_box_size sont exposés
- [ ] Les images générées sont nommées `{source}_blink.png`
- [ ] Le `blink_manifest.yaml` est créé/mis à jour lors de la sauvegarde
- [ ] En preview (éditeur), les foregrounds avec blink clignent automatiquement toutes les ~5s
- [ ] En jeu, les foregrounds avec blink clignent automatiquement toutes les ~5s
- [ ] Les personnages multiples ne clignent pas tous au même instant (variation aléatoire)
- [ ] L'animation de blink dure ~0.45s (4 × fade 75ms + hold 150ms)
- [ ] Le PCK builder inclut les images blink et le manifest dans les PCK de chapitre
- [ ] Les tests couvrent tous les services, le player, et l'intégration PCK
- [ ] Double-clic sur un résultat ouvre la preview plein écran
- [ ] Clic droit permet de régénérer ou supprimer un résultat
