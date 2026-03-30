# Toolbar toggle : défaut caché + bouton toggle

**Date** : 2026-03-30
**Scope** : Game play toolbar (Save, Load, Auto, Skip, History)

## Contexte

La barre d'outils de jeu (`_play_buttons_bar`) est actuellement visible par défaut pendant la lecture. L'utilisateur souhaite qu'elle soit **cachée par défaut** et qu'un **petit bouton toggle** en bas à droite permette de l'afficher/masquer rapidement.

Le setting `toolbar_visible` et son option dans le menu existent déjà. Il faut changer le défaut et ajouter le bouton toggle.

## Changements

### 1. Défaut de `toolbar_visible` à `false`

- `GameSettings.toolbar_visible` : initialisation de `true` → `false`
- `GameSettings.load_settings()` : valeur de fallback de `cfg.get_value("display", "toolbar_visible", true)` → `false`

### 2. Bouton toggle en bas à droite

- **Emplacement** : bas à droite de l'écran, juste au-dessus du dialogue overlay
- **Construction** : dans `GameUIBuilder._build_play_buttons_bar()`, créer un `Button` séparé (`_toolbar_toggle_button`) positionné avec `PRESET_BOTTOM_RIGHT`
- **Apparence** : petit bouton discret avec texte `≡` (toolbar cachée) / `×` (toolbar visible), semi-transparent (`self_modulate.a = 0.6`)
- **Z-index** : même niveau que `_play_buttons_bar` (`UI_OVERLAY_Z`)
- **Comportement au clic** :
  1. Toggle `_toolbar_visible` dans `GamePlayController`
  2. Met à jour `_play_buttons_bar.visible`
  3. Met à jour l'icône du bouton toggle
  4. Persiste le changement dans `GameSettings` et sauvegarde
- **Visibilité** : visible dès qu'une séquence est en lecture, même quand la toolbar est cachée
- **Position** : offset pour ne pas chevaucher le dialogue ni les boutons de la toolbar

### 3. Fichiers impactés

| Fichier | Modification |
|---------|-------------|
| `src/ui/menu/game_settings.gd` | Défaut `toolbar_visible = false`, fallback load → `false` |
| `src/controllers/game_ui_builder.gd` | Construire `_toolbar_toggle_button` |
| `src/game.gd` | Déclarer `var _toolbar_toggle_button: Button` |
| `src/controllers/game_play_controller.gd` | Logique toggle + signal du bouton + sync visibilité |
| `specs/ui/menu/test_game_settings.gd` | Adapter les tests au nouveau défaut |
| `specs/game/test_game_play_controller.gd` | Tests du toggle button |
| `specs/ui/menu/test_options_menu.gd` | Adapter si nécessaire |

### 4. Critères d'acceptation

- [ ] `GameSettings.toolbar_visible` vaut `false` par défaut (nouvelle installation)
- [ ] Un bouton toggle apparaît en bas à droite pendant la lecture
- [ ] Cliquer le bouton toggle affiche/masque la `_play_buttons_bar`
- [ ] L'état est persisté dans `settings.cfg` après toggle
- [ ] Le bouton toggle reste visible même quand la toolbar est cachée
- [ ] L'icône du bouton change selon l'état (≡ caché / × visible)
- [ ] L'option existante dans le menu options reste fonctionnelle et synchronisée
- [ ] Si l'utilisateur ouvre les options après un toggle via le bouton, le checkbox reflète l'état courant
- [ ] Tous les tests existants passent (adaptés au nouveau défaut)
