# Spec 052 — Transparence configurable de la boite de dialogue

## Contexte

Dans les visual novels, les joueurs souhaitent pouvoir ajuster l'opacite de la boite de dialogue pour mieux voir les arriere-plans et les sprites. C'est une option standard du genre. Actuellement, le panneau de dialogue a une opacite fixe a 100%.

## Objectif

Permettre au joueur de configurer l'opacite du fond de la boite de dialogue via un slider dans les options d'affichage. Le texte reste a 100% d'opacite — seul le panneau de fond est affecte. Le reglage est persiste dans `user://settings.cfg` et applique immediatement.

## Architecture

### Fichiers modifies

| Fichier | Modification |
|---------|-------------|
| `src/ui/menu/game_settings.gd` | Ajout propriete `dialogue_opacity: int` (0-100, defaut 80), persistence section `[display]` |
| `src/ui/menu/options_menu.gd` | Ajout slider "Opacite dialogue" dans la section Affichage |
| `src/controllers/game_ui_builder.gd` | StyleBoxFlat sur `_play_overlay` pour controler l'alpha du fond |
| `src/controllers/game_play_controller.gd` | Ajout `set_dialogue_opacity()` pour modifier l'alpha du StyleBox |
| `src/game.gd` | Propagation du setting au controleur dans `_ready()` et `_on_options_applied()` |
| `specs/ui/menu/test_game_settings.gd` | Tests unitaires pour la nouvelle propriete |
| `specs/ui/menu/test_options_menu.gd` | Tests unitaires pour le slider |

### Fichiers crees

| Fichier | Role |
|---------|------|
| `specs/052-dialogue-opacity.md` | Cette specification |

## Details techniques

### Approche StyleBoxFlat

Pour rendre uniquement le fond transparent sans affecter le texte :
- Creer un `StyleBoxFlat` avec `bg_color` ayant un canal alpha variable
- Assigner au PanelContainer via `add_theme_stylebox_override("panel", stylebox)`
- Modifier `stylebox.bg_color.a` quand le setting change
- Les enfants (Label, RichTextLabel) ne sont pas affectes car on ne touche pas au `modulate` du container

### Propagation du setting

Identique au pattern `typewriter_speed` : le setting est lu dans `game.gd._ready()` et `_on_options_applied()`, puis passe au controleur via `set_dialogue_opacity()`.

### Slider

Le slider va de 0 (transparent) a 100 (opaque), pas de 1. La valeur est convertie en float (0.0 a 1.0) lors de l'application au StyleBox.

## Criteres d'acceptation

- [ ] Slider d'opacite dans les options d'affichage (0% a 100%)
- [ ] Valeur par defaut a 80%
- [ ] Seul le fond du panneau de dialogue est affecte, le texte reste a 100%
- [ ] Persistance dans `user://settings.cfg` section `[display]`
- [ ] Application immediate sans redemarrage du jeu
- [ ] Les tests GUT passent
