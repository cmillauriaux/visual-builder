# 021 — Mode Jeu Standalone

## Contexte

Le projet contient un éditeur de visual novel (`main.tscn` / `main.gd`) et un mode play intégré.
Pour l'export, on a besoin d'une scène séparée qui ne contient **que** le jeu (lecture d'une story),
sans aucun élément d'éditeur.

## Objectif

Créer une scène `game.tscn` + `game.gd` qui :

1. Charge une story sauvegardée depuis `user://stories/`
2. Lance la lecture complète via `StoryPlayController`
3. Affiche le visuel (background, foregrounds avec transitions) via `SequenceVisualEditor`
4. Gère le typewriter, les dialogues et les choix
5. Affiche un écran de fin quand la lecture est terminée
6. Ne contient **aucune** référence aux composants éditeur (graph views, breadcrumb, toolbar, etc.)

## Architecture

### Fichiers créés

| Fichier | Rôle |
|---------|------|
| `src/game.tscn` | Scène racine du jeu (Control root → `game.gd`) |
| `src/game.gd` | Contrôleur principal du jeu standalone |
| `src/controllers/game_ui_builder.gd` | Construit l'UI du jeu (visuel + overlays) |
| `src/controllers/game_play_controller.gd` | Gère le play en mode jeu (sans éditeur) |

### Fichiers réutilisés (partagés éditeur/jeu)

- `src/models/*` — Tous les modèles de données
- `src/persistence/story_saver.gd` — Chargement de la story
- `src/ui/play/story_play_controller.gd` — Machine à états du play multi-niveaux
- `src/ui/sequence/sequence_editor.gd` — Contrôleur de séquence (play mode)
- `src/ui/sequence/sequence_visual_editor.gd` — Rendu visuel
- `src/ui/visual/foreground_transition.gd` — Transitions foregrounds
- `src/ui/shared/texture_loader.gd` — Chargement des textures

### Flux de démarrage

```
game.gd._ready()
  → GameUIBuilder.build(self)        # Construit l'UI play-only
  → GamePlayController.setup(self)   # Connecte les signaux
  → _show_story_selector()           # Affiche la liste des stories disponibles
    → Utilisateur sélectionne une story
      → StorySaver.load_story(path)
      → StoryPlayController.start_play_story(story)
      → GamePlayController orchestre le play
```

### UI du jeu

```
Game (Control, plein écran)
├── VisualEditor (SequenceVisualEditor)  ← fond noir + background + foregrounds
├── PlayOverlay (PanelContainer)          ← personnage + texte dialogue
├── ChoiceOverlay (PanelContainer)        ← boutons de choix
├── StopButton (Button)                   ← coin haut-droit, retour sélection
├── TypewriterTimer (Timer)               ← animation texte
├── ForegroundTransition (Node)           ← helper transitions
└── StoryPlayController (Node)            ← machine à états
```

### GamePlayController

Version simplifiée de `PlayController` sans :
- Gestion du fullscreen (on est déjà plein écran)
- Références à `vbox`, `left_panel`, `top_bar`, graph views
- Callbacks vers l'éditeur (`load_sequence_editors`, `refresh_current_view`, etc.)

Conserve :
- Gestion du typewriter
- Transitions foregrounds (fade in/out, crossfade, clones)
- Choix et sélection
- Messages de fin

### Chargement de la story

`game.gd` possède une propriété `@export var story_path: String` :

- **Si `story_path` est défini** (dans l'inspecteur Godot ou dans la scène `.tscn`),
  la story est chargée et jouée automatiquement au démarrage. C'est le mode
  d'export : l'histoire est embarquée avec le jeu.
- **Si `story_path` est vide**, un sélecteur affiche les stories disponibles
  dans `user://stories/`.

Pour exporter un jeu lié à une seule histoire :
1. Sauvegarder la story dans `res://story/` (incluse dans l'export)
2. Dans `game.tscn`, définir `story_path = "res://story"`
3. Exporter le projet

## Critères d'acceptation

- [ ] `game.tscn` est une scène indépendante qui se lance sans erreur
- [ ] Le jeu charge une story depuis `user://stories/`
- [ ] Les dialogues s'affichent avec le typewriter
- [ ] Les transitions de foregrounds fonctionnent (fade in/out, crossfade)
- [ ] Les choix s'affichent et sont fonctionnels
- [ ] Un message de fin s'affiche (game over, to be continued, etc.)
- [ ] Aucune référence aux fichiers éditeur (views, editors, navigation, main_ui_builder)
- [ ] Le bouton Stop permet de revenir à la sélection de story
- [ ] Les tests GUT passent

## Configuration export

### Étapes pour exporter un jeu lié à une seule histoire

1. **Sauvegarder la story** dans un dossier sous `res://` (ex: `res://story/`)
   pour qu'elle soit incluse dans l'export.

2. **Configurer `game.tscn`** : ouvrir la scène dans l'éditeur Godot,
   sélectionner le noeud racine `Game`, et dans l'inspecteur définir
   `Story Path` = `res://story` (le chemin vers le dossier contenant `story.yaml`).

3. **Configurer `project.godot`** :
   - Changer `run/main_scene` vers `res://src/game.tscn`

4. **Filtres d'exclusion** dans les Export Presets (Projet > Exporter > Resources) :
   ```
   src/main.tscn, src/main.gd, src/controllers/main_ui_builder.gd,
   src/controllers/navigation_controller.gd, src/controllers/play_controller.gd,
   src/controllers/play_context.gd, src/views/*, src/ui/editors/*,
   src/ui/navigation/*, src/ui/dialogs/*, src/ui/sequence/dialogue_list_panel.gd,
   src/ui/sequence/transition_panel.gd, src/services/comfyui_*,
   specs/*, addons/gut/*
   ```

### Propriété `story_path`

La propriété `@export var story_path: String` sur `game.gd` contrôle le comportement :

| `story_path` | Comportement |
|--------------|-------------|
| `""` (vide) | Affiche un sélecteur de stories depuis `user://stories/` |
| `"res://story"` | Charge et joue directement cette story (mode export) |
| `"user://stories/mon_histoire"` | Charge depuis le dossier utilisateur |

En mode export avec `story_path` défini, le bouton Stop relance la même histoire.
