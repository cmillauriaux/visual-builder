# Chapter Transition Loading Overlay — Design Spec

## Problème

Lors d'une transition inter-chapitres (signal `redirect_chapter`), le jeu affiche un écran noir pendant le chargement du PCK du prochain chapitre. L'overlay in-game existant (`_loading_overlay`) utilise un fond `ColorRect(0, 0, 0, 0.7)` semi-transparent. Comme les scènes du chapitre précédent ont été libérées avant le chargement, il n'y a rien derrière l'overlay — le résultat est un écran noir total pendant plusieurs minutes.

En comparaison, le flux "Nouvelle partie" affiche l'image `menu_background` de la story en fond + la progression du téléchargement ("Téléchargement... 42%" / "Chargement..."), ce qui est visuellement cohérent et informatif.

## Solution

Afficher l'image `story.menu_background` comme fond de l'overlay in-game pendant les transitions inter-chapitres, avec le même style de progression que le menu.

## Composants concernés

- `src/controllers/game_ui_builder.gd` — construction de l'overlay
- `src/game.gd` — déclaration de la variable, initialisation de l'image
- `specs/game/test_game_ui_builder.gd` — test unitaire du builder

## Changements

### 1. `game.gd` — déclaration de variable

Ajouter dans le bloc des variables d'overlay (à côté de `_loading_overlay` et `_loading_overlay_label`) :

```gdscript
var _loading_overlay_bg: TextureRect
```

### 2. `game_ui_builder.gd` — `_build_loading_overlay()`

Remplacer le `ColorRect` semi-transparent par :

1. Un `TextureRect` en plein écran (`STRETCH_KEEP_ASPECT_COVERED`, ancré `PRESET_FULL_RECT`) comme fond — référence exposée via `game._loading_overlay_bg`
2. Un `ColorRect(0, 0, 0, 0.7)` par-dessus comme scrim (même opacité que l'ancien fond noir, assure un fallback correct si aucune image n'est définie)
3. Le `Label` existant dans son `CenterContainer` reste inchangé

```gdscript
# Avant
var bg := ColorRect.new()
bg.color = Color(0, 0, 0, 0.7)
game._loading_overlay.add_child(bg)

# Après
var bg := TextureRect.new()
bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
game._loading_overlay_bg = bg
game._loading_overlay.add_child(bg)

var scrim := ColorRect.new()
scrim.color = Color(0, 0, 0, 0.7)
scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
game._loading_overlay.add_child(scrim)

# puis add_child(center_container) comme avant
```

Note : avec `texture = null`, le `TextureRect` est transparent → le scrim seul s'affiche (fond noir à 70%, comportement identique à l'existant). Pas de régression pour les stories sans image.

### 3. `game.gd` — `_setup_loading_overlay_image(story: StoryModel)`

Nouvelle fonction appelée dans `_load_story_and_show_menu()` juste après l'assignation de `_current_story`. Elle charge `story.menu_background` via `TextureLoader` (le même utilitaire que `main_menu.gd` lignes 237-243), dont `base_dir` est déjà positionné sur le dossier de la story à ce moment.

```gdscript
func _setup_loading_overlay_image(story: StoryModel) -> void:
    if _loading_overlay_bg == null:
        return
    if story.menu_background.is_empty():
        _loading_overlay_bg.texture = null
        return
    _loading_overlay_bg.texture = TextureLoader.load_texture(story.menu_background)
```

L'image est définie une seule fois au chargement de la story, pas à chaque transition. Elle n'est pas rechargée lors de `_reload_i18n()` (l'image ne change pas avec la langue).

`_setup_loading_overlay_image()` doit également être appelée dans `_on_load_from_save_menu()` et `_on_quickload()` (les deux autres sites où `_current_story` est réassigné lors du chargement d'une sauvegarde d'une story différente). Dans ces paths, `TextureLoader.base_dir` est aussi repositionné sur le nouveau chemin de story, donc l'appel est sûr.

### 4. Ce qu'on ne change pas

- `_on_chapter_loading_started()` et `_on_chapter_loading_finished()` dans `game.gd` — déjà correctement connectés aux signaux `chapter_download_progress` et `chapter_mounting_started`
- Le flux "Nouvelle partie" (`_preload_chapter_with_ui()`, `main_menu.gd`) — inchangé
- `story_play_controller.gd` — inchangé

## Comportement attendu après le fix

| Phase | Texte affiché | Fond |
|-------|--------------|------|
| Téléchargement HTTP | "Téléchargement... 42%" | `menu_background` + scrim |
| Montage PCK | "Chargement..." | `menu_background` + scrim |
| Aucune image définie | "Téléchargement..." / "Chargement..." | Noir (fallback : texture null = transparent sur noir) |

## Tests

### Unitaire — `specs/game/test_game_ui_builder.gd`

Ajouter `func test_builds_loading_overlay_bg()` vérifiant qu'après `GameUIBuilder.build(game)` :
- `game._loading_overlay_bg` est non-null et est de type `TextureRect`
- `game._loading_overlay_bg.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED`
- `game._loading_overlay.get_child(0) is TextureRect` (ordre de rendu : image en premier)
- `game._loading_overlay.get_child(1) is ColorRect` (scrim par-dessus)

### Manuel

- Vérifier que l'overlay affiche l'image `menu_background` pendant une transition `redirect_chapter`
- Vérifier que la progression ("Téléchargement... X%") s'affiche correctement
- Vérifier le cas dégradé : story sans `menu_background` (champ vide) → fond noir (scrim seul, comportement identique à l'existant)
- Vérifier que le flux "Nouvelle partie" est inchangé
