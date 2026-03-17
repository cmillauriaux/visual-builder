# Système de plugins in-game

## Résumé

Système de plugins extensible pour le runtime du jeu (game.gd), permettant à des plugins tiers d'intercepter et modifier les événements de jeu, d'afficher des éléments UI, et de s'intégrer dans le menu Options.

## Architecture

### Classe de base : VBGamePlugin

Chaque plugin in-game est un script GDScript qui étend `VBGamePlugin` (RefCounted). Il fournit :

- **Identité** : `get_plugin_name()`, `get_plugin_description()`
- **Configuration** : `is_configurable()` — si `true`, un toggle apparaît dans les options ; si `false`, le plugin est toujours actif
- **Lifecycle** : `on_game_ready(ctx)`, `on_game_cleanup(ctx)`
- **Hooks événementiels** : `on_before_chapter`, `on_after_chapter`, `on_before_scene`, `on_after_scene`, `on_before_sequence`, `on_after_sequence`
- **Pipeline de transformation** : `on_before_dialogue(ctx, character, text) -> Dictionary`, `on_before_choice(ctx, choices) -> Array` — chaînés entre plugins pour permettre des modifications cumulatives
- **Hooks post-événement** : `on_after_dialogue`, `on_after_choice`
- **Contributions UI** : `get_toolbar_buttons()`, `get_overlay_panels()`, `get_options_controls()`

### GamePluginContext

Contexte riche passé à chaque hook :

- `story`, `story_base_path` — story courante
- `current_chapter`, `current_scene`, `current_sequence` — navigation courante
- `current_dialogue_index` — index du dialogue en cours
- `variables: Dictionary` — référence directe aux variables (lecture/écriture)
- `game_node: Control` — nœud principal du jeu (pour popups/overlays)
- `settings: RefCounted` — GameSettings

### GamePluginManager

- Scanne `res://plugins/*/game_plugin.gd` et `res://game_plugins/*/game_plugin.gd`
- Gère l'état activé/désactivé (persisté dans GameSettings)
- Dispatch les hooks aux plugins actifs uniquement
- Pipeline : les hooks de transformation sont chaînés (sortie du plugin N = entrée du plugin N+1)
- Injecte les contributions UI (toolbar, overlays, options)

### Contributions UI

Trois types :

1. **GameToolbarButton** — Boutons dans la barre au-dessus du dialogue (alignés à gauche)
2. **GameOverlayPanelDef** — Panneaux sur les côtés (left, right, top). Le "top" est sous le bouton menu, sans recouvrir le dialogue
3. **GameOptionsControlDef** — Contrôles personnalisés dans la section "Plugins" du menu Options

### Persistance

- L'état activé/désactivé est stocké dans `game_settings.gd` via `game_plugins_enabled: Dictionary` (plugin_name → bool)
- Sérialisé en JSON dans la section `[plugins]` du ConfigFile

## Découverte des plugins

Convention : chaque plugin est dans un sous-dossier avec un fichier `game_plugin.gd` :
- `res://plugins/censure/game_plugin.gd`
- `res://game_plugins/mon_plugin/game_plugin.gd`

Le plugin doit étendre `VBGamePlugin` et retourner un nom non-vide via `get_plugin_name()`.

## Intégration dans le jeu

### game.gd

1. Instancie `GamePluginManager` dans `_ready()`
2. Charge les états activés depuis `GameSettings`
3. Scanne et charge les plugins
4. Connecte les signaux de `StoryPlayController` aux dispatchers du manager
5. Passe le manager au `GamePlayController` pour le pipeline dialogue/choix

### game_play_controller.gd

- `on_play_dialogue_changed()` : avant d'afficher, appelle `pipeline_before_dialogue()` puis `dispatch_on_after_dialogue()`
- `on_choice_display_requested()` : avant d'afficher, appelle `pipeline_before_choice()`

### game_ui_builder.gd

Construit 4 containers pour les plugins :
- `_plugin_toolbar` (HBoxContainer, au-dessus du dialogue, aligné à gauche)
- `_plugin_overlay_left` (VBoxContainer, bord gauche)
- `_plugin_overlay_right` (VBoxContainer, bord droit)
- `_plugin_overlay_top` (HBoxContainer, sous le bouton menu)

### options_menu.gd

Nouvelle section "Plugins" avec :
- Pour chaque plugin configurable : un toggle activé/désactivé
- Pour chaque plugin (actif) : ses contrôles personnalisés via `get_options_controls()`

## Plugin d'exemple : Censure

### Comportement

- Maintient une liste de mots interdits
- Dans `on_before_dialogue`, remplace les mots par `*****` (insensible à la casse)
- Affiche une bulle rouge "Censuré" en haut à droite pendant 3 secondes quand une censure est appliquée
- Expose un toggle dans les options pour activer/désactiver la censure
- `is_configurable()` retourne `false` (toujours chargé), mais gère son propre toggle interne

### Fichiers

- `plugins/censure/game_plugin.gd` — Implémentation
- `specs/plugins/censure/test_censure_plugin.gd` — Tests

## Critères d'acceptation

- [ ] VBGamePlugin est chargeable et fournit des hooks par défaut (no-op)
- [ ] GamePluginManager scanne et charge les plugins depuis les deux répertoires
- [ ] Les plugins configurables peuvent être activés/désactivés depuis les options
- [ ] L'état activé/désactivé est persisté entre les sessions
- [ ] Le pipeline dialogue transforme correctement le texte (chaînage multi-plugins)
- [ ] Le pipeline choix transforme correctement les textes
- [ ] Les hooks événementiels sont appelés au bon moment
- [ ] Les containers UI (toolbar, overlays) affichent les contributions des plugins
- [ ] Le plugin Censure remplace les mots interdits par des étoiles
- [ ] Le plugin Censure affiche une bulle rouge temporaire lors d'une censure
- [ ] Le plugin Censure expose un toggle dans les options
- [ ] Les plugins inactifs ne reçoivent aucun hook
- [ ] Scan résilient : pas de crash si les répertoires n'existent pas
