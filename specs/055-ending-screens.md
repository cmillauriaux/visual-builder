# 055 — Écrans de fin : Game Over et To Be Continued

## Résumé

Remplace les `AcceptDialog` génériques affichés en fin de partie (`game_over`, `to_be_continued`) par des écrans plein-écran configurables : background, titre, sous-titre, et boutons Patreon / itch.io / Retour au menu principal. La configuration se fait dans `MenuConfigDialog`, au même titre que le menu principal.

## Comportement attendu

### Nouveaux champs du modèle Story

Six nouveaux champs, sérialisés dans un bloc `"screens"` dans le YAML :

| Champ | Type | Défaut |
|-------|------|--------|
| `game_over_title` | `String` | `""` |
| `game_over_subtitle` | `String` | `""` |
| `game_over_background` | `String` | `""` |
| `to_be_continued_title` | `String` | `""` |
| `to_be_continued_subtitle` | `String` | `""` |
| `to_be_continued_background` | `String` | `""` |

Sérialisation dans `story.yaml` :

```yaml
screens:
  game_over:
    title: ""
    subtitle: ""
    background: ""
  to_be_continued:
    title: ""
    subtitle: ""
    background: ""
```

`from_dict()` tolère l'absence du bloc `"screens"` (rétrocompatibilité — valeurs vides par défaut).

### Configuration dans MenuConfigDialog

Deux nouvelles sections après la section "Liens externes", chacune séparée par un `HSeparator` :

**Section "Écran Game Over"** :
- `LineEdit` (read-only) pour le background + bouton `Parcourir...` + bouton `✕`
- Aperçu miniature `TextureRect` (200×112, comme le background du menu)
- `LineEdit` pour le titre (placeholder : `"Game Over"`)
- `LineEdit` pour le sous-titre

**Section "Écran À suivre..."** :
- Même structure que Game Over
- Placeholder titre : `"À suivre..."`

Le bouton `Parcourir...` ouvre un `ImagePickerDialog` en mode `BACKGROUND`.

Le signal `menu_config_confirmed` est étendu avec 6 paramètres supplémentaires :
```
game_over_title, game_over_subtitle, game_over_background,
to_be_continued_title, to_be_continued_subtitle, to_be_continued_background
```

`setup()` pré-remplit les champs depuis la story.

### Composant EndingScreen (`src/ui/menu/ending_screen.gd`)

Nouvelle scène `Control` plein-écran, construite par code (pas de `.tscn`), suivant le pattern de `main_menu.gd` :

```
EndingScreen (Control, plein écran)
├── Background (TextureRect)          ← image configurée ou fond noir
├── Overlay (ColorRect, semi-transparent #000 @ 0.5)
└── CenterContainer (plein écran)
    └── VBoxContainer (centré)
        ├── TitleLabel (Label, font_size 64)
        ├── SubtitleLabel (Label, font_size 24)
        ├── Spacer (60px)
        ├── LoadAutosaveButton ("Charger la dernière sauvegarde", masqué par défaut)
        ├── PatreonButton (masqué si URL vide, couleur #FF424D)
        ├── ItchioButton (masqué si URL vide, couleur #FA5C5C)
        └── BackToMenuButton ("Retour au menu principal")
```

**Méthodes** :
- `build_ui()` — construit l'arborescence (appelé par `GameUIBuilder`)
- `setup(title: String, subtitle: String, background: String, base_path: String, patreon_url: String, itchio_url: String)` — configure l'écran
- `show_screen()` / `hide_screen()` — affiche/masque
- `set_load_autosave_visible(visible: bool)` — affiche/masque le bouton "Charger la dernière sauvegarde"

**Signaux** :
- `back_to_menu_pressed` — émis au clic sur "Retour au menu principal"
- `load_last_autosave_pressed` — émis au clic sur "Charger la dernière sauvegarde"

**Note** : Le bouton `LoadAutosaveButton` est présent dans les deux écrans mais n'est activé (via `set_load_autosave_visible`) que pour l'écran Game Over.

**Comportement des titres** :
- Si `title` est vide : affiche `"Game Over"` (resp. `"À suivre..."`) selon le type d'écran
- Le type est fixé à la construction ou via un paramètre de `setup()`

**Chargement du background** :
- Utilise `TextureLoader.load_texture(base_path.path_join(background))` comme `main_menu.gd`
- Si vide ou introuvable : fond noir (`texture = null`)

### Intégration dans GameUIBuilder

`game_ui_builder.gd` construit deux `EndingScreen` :
- `game._game_over_screen` — titre par défaut `"Game Over"`
- `game._to_be_continued_screen` — titre par défaut `"À suivre..."`

Ajoutés après `_build_main_menu()`.

### Intégration dans GamePlayController

`on_play_finished(reason: String)` modifié :
- `"game_over"` → `_game._game_over_screen.show_screen()` (au lieu de l'AcceptDialog)
- `"to_be_continued"` → `_game._to_be_continued_screen.show_screen()`
- Autres raisons → comportement inchangé (AcceptDialog générique)

### Intégration dans game.gd

**Setup des écrans** (dans `_show_main_menu()` ou `_load_story_and_show_menu()`) :
```gdscript
_game_over_screen.setup(
    story.game_over_title, story.game_over_subtitle,
    story.game_over_background, _current_story_path,
    story.patreon_url, story.itchio_url
)
_to_be_continued_screen.setup(
    story.to_be_continued_title, story.to_be_continued_subtitle,
    story.to_be_continued_background, _current_story_path,
    story.patreon_url, story.itchio_url
)
```

**Connexion des signaux** :
```gdscript
_game_over_screen.back_to_menu_pressed.connect(_on_play_finished_return)
_to_be_continued_screen.back_to_menu_pressed.connect(_on_play_finished_return)
_game_over_screen.load_last_autosave_pressed.connect(_on_game_over_load_autosave)
```

`_on_play_finished_return()` cache les deux écrans avant d'afficher le menu (via `hide_screen()`).

`_on_game_over_load_autosave()` :
```gdscript
func _on_game_over_load_autosave() -> void:
    _game_over_screen.hide_screen()
    var autosaves := GameSaveManager.list_autosaves()
    if autosaves.is_empty():
        return
    var latest_slot: int = autosaves[0]["slot_index"]
    _on_load_slot(-(latest_slot + 2))  # convention slot_index < -1 pour autosave
```

**Visibilité du bouton autosave** : après `setup()`, appeler `_game_over_screen.set_load_autosave_visible(not GameSaveManager.list_autosaves().is_empty())`.

### NavigationController (éditeur)

`_on_menu_config_confirmed()` reçoit et applique les 6 nouveaux paramètres sur la story.

## Critères d'acceptation

### Modèle Story
- [x] `StoryModel` possède les 6 nouvelles propriétés avec `""` comme valeur par défaut
- [x] `to_dict()` sérialise dans un bloc `"screens"` avec sous-blocs `"game_over"` et `"to_be_continued"`
- [x] `from_dict()` restaure les valeurs ; si le bloc `"screens"` est absent, les valeurs sont `""`

### MenuConfigDialog
- [x] Une section "Écran Game Over" est visible avec champs titre, sous-titre, background (Parcourir + ✕ + aperçu)
- [x] Une section "Écran À suivre..." est visible avec la même structure
- [x] `setup()` pré-remplit les 6 champs depuis la story
- [x] `Parcourir...` ouvre `ImagePickerDialog` en mode `BACKGROUND`
- [x] `✕` efface le background et l'aperçu
- [x] Le signal `menu_config_confirmed` inclut les 6 nouveaux paramètres
- [x] `NavigationController._on_menu_config_confirmed()` applique les nouveaux paramètres à la story

### EndingScreen
- [x] `build_ui()` construit l'arborescence : Background, Overlay, TitleLabel, SubtitleLabel, LoadAutosaveButton, PatreonButton, ItchioButton, BackToMenuButton
- [x] `setup()` configure le titre, sous-titre, background, URLs Patreon/itch.io
- [x] Si le titre configuré est vide, le label affiche la valeur par défaut passée à la construction
- [x] Le background est chargé depuis `base_path.path_join(background)` ; fond noir si absent ou invalide
- [x] Le bouton Patreon est masqué si l'URL est vide, visible sinon (couleur `#FF424D`)
- [x] Le bouton itch.io est masqué si l'URL est vide, visible sinon (couleur `#FA5C5C`)
- [x] Un clic sur Patreon appelle `OS.shell_open(patreon_url)`
- [x] Un clic sur itch.io appelle `OS.shell_open(itchio_url)`
- [x] Un clic sur "Retour au menu principal" émet `back_to_menu_pressed`
- [x] `show_screen()` rend l'écran visible, `hide_screen()` le masque
- [x] `set_load_autosave_visible(true)` rend le bouton "Charger la dernière sauvegarde" visible
- [x] `set_load_autosave_visible(false)` masque le bouton "Charger la dernière sauvegarde"
- [x] Un clic sur "Charger la dernière sauvegarde" émet `load_last_autosave_pressed`
- [x] Le bouton "Charger la dernière sauvegarde" est masqué par défaut

### Intégration en jeu
- [x] `GameUIBuilder` construit `_game_over_screen` et `_to_be_continued_screen`
- [x] Quand une story se termine avec `game_over`, l'écran Game Over s'affiche (plus d'AcceptDialog)
- [x] Quand une story se termine avec `to_be_continued`, l'écran To Be Continued s'affiche
- [x] Les autres raisons de fin (`no_ending`, `error`, `stopped`) affichent toujours l'AcceptDialog
- [x] `game.gd` configure les deux écrans via `setup()` lors du chargement de la story
- [x] Cliquer "Retour au menu principal" sur un écran de fin retourne au MainMenu (ou au sélecteur)
- [x] L'écran de fin est masqué avant l'affichage du menu principal
- [x] Sur l'écran Game Over, le bouton "Charger la dernière sauvegarde" est visible si une autosave existe
- [x] Sur l'écran Game Over, le bouton est masqué s'il n'existe aucune autosave
- [x] Cliquer "Charger la dernière sauvegarde" charge la sauvegarde automatique la plus récente et lance la lecture

### Tests
- [x] Tests GUT couvrent `StoryModel` : sérialisation/désérialisation du bloc `"screens"`
- [x] Tests GUT couvrent `EndingScreen` : `build_ui()`, `setup()`, signaux, visibilité des boutons
- [x] Tests GUT couvrent `MenuConfigDialog` : nouveaux champs, signal étendu
- [x] Les tests passent
