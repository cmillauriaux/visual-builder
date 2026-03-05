# Spec 048 — Auto-play : avance automatique du texte

## Contexte

L'auto-play est une fonctionnalite essentielle des visual novels. Elle permet aux joueurs de lire confortablement sans avoir a cliquer pour chaque ligne de dialogue. Apres la fin du typewriter, un timer configurable avance automatiquement au dialogue suivant.

## Fonctionnalites

### GameSettings — Delai auto-play

- Nouvelle propriete `auto_play_delay: float` (defaut: `2.0` secondes)
- Persistee dans `settings.cfg` section `[gameplay]`, cle `auto_play_delay`
- Valeurs possibles : `1.0`, `2.0`, `3.0`, `5.0` secondes

### AutoPlayManager

Nouveau service (`src/services/auto_play_manager.gd`) qui encapsule la logique d'auto-avance :

```gdscript
extends RefCounted

signal auto_advance_requested()
signal auto_play_toggled(enabled: bool)

var enabled: bool = false
var delay: float = 2.0

func toggle() -> void
func start_timer() -> void    # Demarre le timer (appele quand le typewriter finit)
func stop_timer() -> void     # Arrete le timer
func reset() -> void          # Desactive et arrete le timer
```

**Comportement :**
- Quand le typewriter termine (`_text_fully_displayed = true`), le controlleur appelle `start_timer()`
- Apres `delay` secondes, emet `auto_advance_requested`
- Le controlleur connecte ce signal pour appeler `advance_play()`
- Se pause automatiquement lors des choix (le controlleur n'appelle pas `start_timer()` quand un choix est affiche)
- Se desactive si le joueur clique/appuie manuellement (le controlleur appelle `reset()` sur input utilisateur)

### Integration PlayController (editeur)

- Ecoute `auto_advance_requested` pour appeler `_sequence_editor_ctrl.advance_play()`
- Apres chaque changement de dialogue, quand le typewriter finit, demarre le timer
- Sur input utilisateur (SPACE), appelle `_auto_play.reset()` pour desactiver
- Pas de bouton UI en mode editeur (l'auto-play est reserve au mode jeu)

### Integration GamePlayController (jeu)

- Memes mecaniques que PlayController
- Bouton toggle "Auto" dans l'overlay de jeu (a cote du menu button)
- Indicateur visuel : le bouton affiche "Auto [ON]" / "Auto [OFF]" avec couleur
- Sur clic du bouton, appelle `_auto_play.toggle()`
- Lors de l'affichage des choix, le timer est arrete
- Lors du stop/cleanup, `_auto_play.reset()`

### UI du bouton Auto (game mode)

```
MenuButton "☰ Menu"  |  AutoButton "Auto"    ← coin haut-droit
```

- Bouton cree dans `game_ui_builder.gd`, stocke sur `game._auto_play_button`
- Position : a gauche du menu button, meme rangee en haut a droite
- Toggle mode : `button_pressed = true` quand auto-play actif
- Couleur : vert quand actif, normal quand inactif
- Visible uniquement pendant le play (meme visibilite que `_menu_button`)

### Detection de la fin du typewriter

Le typewriter se termine dans `sequence_editor.gd:advance_typewriter()` quand `_text_fully_displayed` passe a `true`. Les controlleurs detectent cet etat via `is_text_fully_displayed()` dans `on_typewriter_tick()`.

**Modification de `on_typewriter_tick()`** dans les deux controlleurs :
```gdscript
func on_typewriter_tick() -> void:
    # ... existing typewriter logic ...
    if _sequence_editor_ctrl.is_text_fully_displayed():
        if _auto_play.enabled:
            _auto_play.start_timer()
```

### Option dans le menu pause (settings)

- Le delai auto-play est configurable via `GameSettings.auto_play_delay`
- Pas de UI dans le menu pause pour cette version (configurable uniquement via settings.cfg)

## Architecture

### Fichiers crees

| Fichier | Role |
|---------|------|
| `src/services/auto_play_manager.gd` | Logique auto-play avec timer |
| `specs/048-auto-play.md` | Cette specification |
| `specs/test_auto_play_manager.gd` | Tests unitaires |

### Fichiers modifies

| Fichier | Modification |
|---------|-------------|
| `src/ui/menu/game_settings.gd` | Ajout `auto_play_delay` + persistence |
| `src/controllers/game_play_controller.gd` | Integration auto-play |
| `src/controllers/game_ui_builder.gd` | Bouton Auto |
| `src/game.gd` | Connexion signaux auto-play |

## Criteres d'acceptation

- [ ] Le bouton Auto toggle l'auto-play dans le mode jeu
- [ ] Le delai est configurable (defaut 2s)
- [ ] Le timer attend la fin du typewriter avant de se lancer
- [ ] L'auto-play se met en pause lors des choix
- [ ] Indicateur visuel quand l'auto-play est actif
- [ ] L'auto-play se desactive si le joueur appuie sur SPACE
- [ ] Le delai est persiste dans settings.cfg
- [ ] Les tests GUT passent
