# 022 — Menu Principal

## Contexte

Le jeu standalone (`game.tscn`) affiche actuellement un simple sélecteur de stories
quand `story_path` est vide. En mode export (story embarquée), il lance directement la story.

On a besoin d'un vrai **menu principal** avec titre, sous-titre, background
(tous paramétrés dans la story), et des options classiques de jeu : nouvelle partie,
charger partie, options (affichage, audio, langue) et quitter.

## Objectif

Créer une scène `main_menu.tscn` + `main_menu.gd` qui :

1. Affiche un écran de menu principal avec background, titre et sous-titre issus de la story
2. Propose les options : Nouvelle partie, Charger partie, Options, Quitter
3. Gère un sous-menu Options complet (résolution, plein écran, audio, langue)
4. Persiste les réglages dans `user://settings.cfg`
5. Applique les réglages au démarrage

## Architecture

### Nouveaux champs du modèle Story

Le modèle `story.gd` reçoit 3 nouveaux champs pour paramétrer le menu :

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `menu_title` | `String` | `""` | Titre affiché sur le menu principal (si vide, utilise `title`) |
| `menu_subtitle` | `String` | `""` | Sous-titre affiché sous le titre |
| `menu_background` | `String` | `""` | Chemin vers l'image de fond du menu (relatif aux assets, ex: `backgrounds/menu_bg.png`) |

Ces champs sont sérialisés/désérialisés dans `story.yaml` via `to_dict()` / `from_dict()`.

### Fichiers créés

| Fichier | Rôle |
|---------|------|
| `src/ui/menu/main_menu.tscn` | Scène du menu principal |
| `src/ui/menu/main_menu.gd` | Contrôleur du menu principal |
| `src/ui/menu/options_menu.gd` | Sous-menu Options |
| `src/ui/menu/game_settings.gd` | Modèle de données des réglages + persistance |

### Fichiers modifiés

| Fichier | Modification |
|---------|-------------|
| `src/models/story.gd` | Ajout de `menu_title`, `menu_subtitle`, `menu_background` |
| `src/persistence/story_saver.gd` | Sérialisation des nouveaux champs |
| `src/game.gd` | Remplacement du story selector par le menu principal |
| `src/controllers/game_ui_builder.gd` | Construction du menu au lieu du story selector |

### Flux de démarrage (révisé)

```
game.gd._ready()
  → GameUIBuilder.build(self)           # Construit l'UI (dont le menu)
  → GamePlayController.setup(self)
  → GameSettings.load_settings()        # Charge et applique les réglages
  → Si story_path défini :
      → Charge la story
      → _show_main_menu(story)          # Affiche le menu avec infos de la story
  → Sinon :
      → _show_story_selector()          # Garde le sélecteur de stories (mode dev)
      → Quand une story est sélectionnée → _show_main_menu(story)
```

### Arborescence UI du menu

```
MainMenu (Control, plein écran)
├── MenuBackground (TextureRect)          ← image de fond depuis story.menu_background
├── Overlay (ColorRect, semi-transparent) ← voile sombre pour lisibilité
├── VBoxContainer (centré)
│   ├── TitleLabel (Label)                ← story.menu_title (ou story.title si vide)
│   ├── SubtitleLabel (Label)             ← story.menu_subtitle
│   ├── Spacer (Control, 60px)
│   ├── NewGameButton (Button)            ← "Nouvelle partie"
│   ├── LoadGameButton (Button)           ← "Charger partie"
│   ├── OptionsButton (Button)            ← "Options"
│   └── QuitButton (Button)              ← "Quitter"
└── OptionsMenu (PanelContainer, caché)
    └── (voir section Options ci-dessous)
```

### Menu principal — MainMenu (`main_menu.gd`)

**Responsabilités :**
- Recevoir une story et afficher son background/titre/sous-titre
- Émettre des signaux pour chaque action du menu
- Gérer l'affichage/masquage du sous-menu Options

**Signaux :**
- `new_game_pressed` — L'utilisateur veut démarrer une nouvelle partie
- `load_game_pressed` — L'utilisateur veut charger une partie
- `quit_pressed` — L'utilisateur veut quitter

**Méthodes :**
- `setup(story, base_path: String)` — Configure le menu avec les données de la story. `base_path` est le chemin du dossier de la story (pour résoudre les chemins relatifs des images).
- `show_menu()` / `hide_menu()` — Affiche/masque le menu

**Comportement des boutons :**

| Bouton | Action |
|--------|--------|
| Nouvelle partie | Émet `new_game_pressed`. `game.gd` lance `StoryPlayController.start_play_story(story)` |
| Charger partie | Émet `load_game_pressed`. Pour cette spec, affiche un message "Fonctionnalité à venir" (implémentation future) |
| Options | Affiche le sous-menu Options |
| Quitter | Émet `quit_pressed`. `game.gd` appelle `get_tree().quit()` |

### Sous-menu Options — OptionsMenu (`options_menu.gd`)

```
OptionsMenu (PanelContainer, centré, 600x500)
├── VBoxContainer
│   ├── TitleBar (HBoxContainer)
│   │   ├── Label "Options"
│   │   └── CloseButton (Button) "✕"
│   ├── HSeparator
│   ├── ScrollContainer
│   │   └── VBoxContainer
│   │       ├── SectionLabel "Affichage"
│   │       ├── ResolutionOption (HBoxContainer)
│   │       │   ├── Label "Résolution"
│   │       │   └── OptionButton [1920x1080, 1600x900, 1280x720, 1024x576]
│   │       ├── FullscreenOption (HBoxContainer)
│   │       │   ├── Label "Plein écran"
│   │       │   └── CheckButton
│   │       ├── HSeparator
│   │       ├── SectionLabel "Audio"
│   │       ├── MusicEnabledOption (HBoxContainer)
│   │       │   ├── Label "Musique"
│   │       │   └── CheckButton
│   │       ├── MusicVolumeOption (HBoxContainer)
│   │       │   ├── Label "Volume musique"
│   │       │   └── HSlider (0–100, step 1)
│   │       ├── FxEnabledOption (HBoxContainer)
│   │       │   ├── Label "Effets sonores"
│   │       │   └── CheckButton
│   │       ├── FxVolumeOption (HBoxContainer)
│   │       │   ├── Label "Volume effets"
│   │       │   └── HSlider (0–100, step 1)
│   │       ├── HSeparator
│   │       ├── SectionLabel "Langue"
│   │       └── LanguageOption (HBoxContainer)
│   │           ├── Label "Langue"
│   │           └── OptionButton [Français, English]
│   └── ApplyButton (Button) "Appliquer"
```

**Responsabilités :**
- Afficher les réglages actuels depuis `GameSettings`
- Permettre la modification
- Sauvegarder et appliquer les changements via `GameSettings`

**Comportement :**
- À l'ouverture, les contrôles reflètent les valeurs de `GameSettings`
- Le bouton "Appliquer" sauvegarde et applique tous les changements
- Le bouton "✕" ferme le panneau sans appliquer (annule les modifications)
- Le slider de volume est grisé quand l'audio correspondant est désactivé

### Modèle de réglages — GameSettings (`game_settings.gd`)

Singleton (autoload ou static) qui gère la persistance et l'application des réglages.

**Propriétés :**

| Propriété | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `resolution` | `Vector2i` | `Vector2i(1920, 1080)` | Résolution de la fenêtre |
| `fullscreen` | `bool` | `false` | Mode plein écran |
| `music_enabled` | `bool` | `true` | Musique activée |
| `music_volume` | `int` | `80` | Volume musique (0–100) |
| `fx_enabled` | `bool` | `true` | Effets sonores activés |
| `fx_volume` | `int` | `80` | Volume effets (0–100) |
| `language` | `String` | `"fr"` | Code langue (fr, en) |

**Méthodes :**
- `load_settings()` — Charge depuis `user://settings.cfg` (ConfigFile). Si le fichier n'existe pas, utilise les défauts.
- `save_settings()` — Sauvegarde dans `user://settings.cfg`
- `apply_settings()` — Applique les réglages au runtime :
  - Résolution → `DisplayServer.window_set_size(resolution)`
  - Plein écran → `DisplayServer.window_set_mode(FULLSCREEN ou WINDOWED)`
  - Volumes → `AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume / 100.0))`
  - Mute → `AudioServer.set_bus_mute(bus_idx, !enabled)`
  - Langue → `TranslationServer.set_locale(language)`

**Format `user://settings.cfg` :**
```ini
[display]
resolution_x=1920
resolution_y=1080
fullscreen=false

[audio]
music_enabled=true
music_volume=80
fx_enabled=true
fx_volume=80

[general]
language=fr
```

### Résolutions disponibles

| Label | Résolution |
|-------|-----------|
| 1920×1080 (Full HD) | `Vector2i(1920, 1080)` |
| 1600×900 | `Vector2i(1600, 900)` |
| 1280×720 (HD) | `Vector2i(1280, 720)` |
| 1024×576 | `Vector2i(1024, 576)` |

### Bus audio

Le projet doit avoir 3 bus audio configurés :
- `Master` — Bus principal (toujours présent dans Godot)
- `Music` — Bus pour la musique de fond
- `FX` — Bus pour les effets sonores

Si les bus n'existent pas encore, `GameSettings.apply_settings()` les ignore sans erreur
(les bus seront créés quand le système audio sera implémenté).

### Langues

Pour cette spec, les langues supportées sont :
- `fr` — Français (défaut)
- `en` — English

L'internationalisation complète (traduction des textes de l'UI) est hors scope de cette spec.
Seul le réglage est persisté pour être utilisé ultérieurement.

### Intégration dans game.gd

Le flux de `game.gd` est modifié :

```gdscript
# Quand une story est chargée (directement ou via sélecteur) :
func _show_main_menu(story) -> void:
    _main_menu.setup(story, _current_story_path)
    _main_menu.show_menu()

# Connexion des signaux du menu :
_main_menu.new_game_pressed.connect(_on_new_game)
_main_menu.load_game_pressed.connect(_on_load_game)
_main_menu.quit_pressed.connect(_on_quit)

func _on_new_game() -> void:
    _main_menu.hide_menu()
    _play_ctrl.start_story(_current_story)

func _on_load_game() -> void:
    # Placeholder pour la spec future
    _show_info("Fonctionnalité à venir")

func _on_quit() -> void:
    get_tree().quit()
```

Quand le jeu se termine (play_finished), on retourne au menu principal au lieu du sélecteur.

### Chargement du background du menu

Le background du menu utilise `TextureLoader` (existant) pour charger l'image :

```gdscript
func setup(story, base_path: String) -> void:
    _title_label.text = story.menu_title if story.menu_title != "" else story.title
    _subtitle_label.text = story.menu_subtitle

    if story.menu_background != "":
        var tex = TextureLoader.load_texture(story.menu_background, base_path)
        if tex:
            _background.texture = tex
            _background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
```

## Critères d'acceptation

### Modèle Story
- [x] `story.gd` contient les champs `menu_title`, `menu_subtitle`, `menu_background`
- [x] `to_dict()` et `from_dict()` sérialisent les nouveaux champs
- [x] Les valeurs par défaut sont des chaînes vides (rétrocompatible)

### Menu principal
- [x] Le menu affiche le background de la story (ou fond noir si non défini)
- [x] Le menu affiche le titre (menu_title, ou title en fallback)
- [x] Le menu affiche le sous-titre
- [x] Le bouton "Nouvelle partie" lance la lecture de la story
- [x] Le bouton "Charger partie" affiche un message placeholder
- [x] Le bouton "Options" ouvre le sous-menu Options
- [x] Le bouton "Quitter" ferme l'application
- [x] Après la fin d'une partie, on revient au menu principal

### Options
- [x] Le sous-menu Options affiche toutes les catégories : Affichage, Audio, Langue
- [x] On peut changer la résolution parmi les valeurs proposées
- [x] On peut activer/désactiver le plein écran
- [x] On peut activer/désactiver la musique et régler son volume
- [x] On peut activer/désactiver les FX et régler leur volume
- [x] Les sliders de volume sont grisés quand l'audio correspondant est désactivé
- [x] On peut changer la langue
- [x] "Appliquer" sauvegarde et applique les réglages
- [x] "✕" ferme sans appliquer (annule les modifications)

### Persistance des réglages
- [x] Les réglages sont sauvegardés dans `user://settings.cfg`
- [x] Les réglages sont chargés et appliqués au démarrage
- [x] Si le fichier n'existe pas, les valeurs par défaut sont utilisées

### Intégration
- [x] `game.gd` utilise le menu principal au lieu du sélecteur direct
- [x] En mode story embarquée (`story_path` défini), le menu s'affiche directement
- [x] En mode sélecteur (`story_path` vide), le sélecteur de stories s'affiche d'abord, puis le menu après sélection
- [x] Aucune régression sur le mode play existant

### Configuration du menu dans l'éditeur
- [x] Un dialogue `MenuConfigDialog` permet d'éditer `menu_title`, `menu_subtitle`, `menu_background`
- [x] Le dialogue est accessible depuis le PopupMenu du breadcrumb (option "Configurer le menu")
- [x] Le dialogue est accessible depuis un bouton "Menu" dans la toolbar
- [x] Le bouton "Menu" est visible aux niveaux chapters, scenes, sequences
- [x] Le bouton "Parcourir..." ouvre un `ImagePickerDialog` en mode BACKGROUND
- [x] Le bouton "✕" vide le champ background
- [x] La confirmation met à jour les champs de la story

### Tests
- [x] Les tests GUT couvrent `GameSettings` (load, save, apply)
- [x] Les tests GUT couvrent `MainMenu` (setup, signaux, affichage)
- [x] Les tests GUT couvrent `OptionsMenu` (modification, apply, cancel)
- [x] Les tests GUT couvrent les nouveaux champs de `Story`
- [x] Les tests GUT couvrent `MenuConfigDialog` (structure, setup, signal, clear)
- [x] Les tests GUT passent
