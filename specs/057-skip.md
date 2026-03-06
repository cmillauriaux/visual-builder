# Spec 057 — Skip : passage rapide des contenus déjà joués

## Résumé

Un bouton "Skip" (raccourci clavier : `S`) dans l'overlay de jeu permet de sauter instantanément la séquence en cours et d'atterrir au prochain point de décision ou à la séquence suivante. C'est une **action ponctuelle** (pas un mode persistant comme Auto) : chaque appui saute une séquence. Si la scène courante n'a pas encore été jouée, le bouton est grisé.

## Comportement attendu

### Disponibilité du Skip

- Skip est **disponible** (bouton cliquable) si la **scène courante** est considérée comme "déjà jouée".
- La définition de "déjà jouée" est identique à celle de la spec 056 (menu Chapitres/Scènes) :
  - Toutes les sauvegardes (manuelles 6 slots, automatiques 10 slots, rapide) sont analysées.
  - La "progression maximale" est la paire `(max_chapter_index, max_scene_index)` la plus avancée.
  - Une scène est "déjà jouée" si : `chapter_index < max_chapter_index` OU (`chapter_index == max_chapter_index` ET `scene_index <= max_scene_index`).
- Si aucune sauvegarde n'existe, aucune scène n'est considérée comme déjà jouée → Skip toujours grisé.
- La disponibilité est réévaluée à chaque changement de scène.

### Action Skip (un appui = un saut)

Appuyer sur le bouton ou sur la touche `S` déclenche un saut immédiat :

1. Tous les dialogues restants de la séquence courante sont ignorés.
2. **Si la terminaison est `choices`** : les choix sont affichés immédiatement. Le joueur doit sélectionner un choix manuellement. Le jeu reprend normalement après le choix.
3. **Si la terminaison est `auto_redirect`** : la séquence est abandonnée et la transition vers la séquence cible est déclenchée normalement (transitions visuelles incluses). Le jeu reprend au début de la séquence suivante.
4. **Si aucune terminaison valide** : comportement identique à `advance_play()` en fin de séquence.

Après le saut, le jeu continue son cours normalement — Skip n'est pas un mode persistant. Un nouveau appui est nécessaire pour sauter la séquence suivante.

### Raccourci clavier

- `S` déclenche l'action Skip si le bouton est disponible (non grisé) et que la lecture est en cours.
- `S` n'a aucun effet si le bouton est grisé ou si les choix sont affichés.

### Indicateur visuel

- Bouton disponible : "Skip (S)" — texte standard, cliquable.
- Bouton indisponible : `disabled = true` — grisé automatiquement par Godot.
- Pas d'état "actif" persistant (pas de couleur toggle, pas de "[ON]").

## Architecture

### Intégration GamePlayController

Pas de service dédié (l'action est ponctuelle). La logique est directement dans `GamePlayController` :

- Référence au bouton Skip dans `_skip_button: Button`.
- Méthode `execute_skip()` :
  ```gdscript
  func execute_skip() -> void:
      if not _skip_button or _skip_button.disabled:
          return
      if not _sequence_editor_ctrl.is_playing():
          return
      # Stoppe le typewriter et l'auto-play
      _typewriter_timer.stop()
      if _auto_play:
          _auto_play.stop_timer()
      # Saute immédiatement à la fin de la séquence
      _sequence_editor_ctrl.skip_to_end()
      # Déclenche la fin de séquence (ending géré par on_play_stopped / on_play_finished)
      _handle_play_stopped()
  ```
- Dans `on_sequence_play_requested()` : met à jour `_skip_button.disabled` selon la disponibilité de la scène courante.
- Dans `_cleanup_play()` : `_skip_button.disabled = true`.
- Dans `_input()` : si `KEY_S` pressé et lecture en cours → appelle `execute_skip()`.

### Calcul de la disponibilité dans game.gd

- Méthode `_compute_skip_availability()` : analyse toutes les sauvegardes, calcule `(max_chapter_index, max_scene_index)`, et retourne une fonction/closure permettant de vérifier si une scène est disponible.
- Appelée au démarrage et après chaque chargement/sauvegarde pour mettre à jour `_play_ctrl`.
- `GamePlayController` expose `set_skip_progression(max_ch_idx: int, max_sc_idx: int)` pour recevoir cette progression.

### SequenceEditor — `skip_to_end()`

Nouvelle méthode dans `sequence_editor.gd` :

```gdscript
func skip_to_end() -> void:
    # Positionne le curseur sur le dernier dialogue
    # et marque le texte comme entièrement affiché
```

### UI du bouton Skip

Ajout dans `game_ui_builder.gd`, barre `_play_buttons_bar` :

```
Save (F5)  |  Load (F9)  |  Auto  |  Skip (S)    ← coin bas-droit
```

- Créé dans `_build_play_overlay()`, stocké sur `game._skip_button`.
- Ajouté dans `_build_play_buttons_bar()` après le bouton Auto.
- `custom_minimum_size = Vector2(120, 30)`.
- `disabled = true` par défaut.

## Structure des fichiers

### Fichiers créés

| Fichier | Rôle |
|---------|------|
| `specs/057-skip.md` | Cette spécification |
| `specs/test_skip.gd` | Tests unitaires |

### Fichiers modifiés

| Fichier | Modification |
|---------|-------------|
| `src/controllers/game_play_controller.gd` | `execute_skip()`, gestion `_skip_button`, touche `S` |
| `src/controllers/game_ui_builder.gd` | Bouton Skip |
| `src/ui/sequence/sequence_editor.gd` | `skip_to_end()` |
| `src/game.gd` | `set_skip_progression()` + calcul progression |

## Critères d'acceptation

- [x] Le bouton "Skip (S)" est présent dans la barre de boutons en jeu (`game._skip_button`).
- [x] Le bouton est grisé (`disabled = true`) quand la scène courante n'est pas "déjà jouée".
- [x] Le bouton est cliquable quand la scène courante est "déjà jouée".
- [x] Cliquer Skip saute instantanément à la fin de la séquence courante.
- [x] Si l'ending est `choices`, les choix sont affichés immédiatement après le saut.
- [x] Si l'ending est `auto_redirect`, la transition vers la séquence suivante est déclenchée.
- [x] Après le saut, le jeu reprend normalement (Skip ne reste pas "actif").
- [x] La touche `S` déclenche l'action Skip si le bouton est disponible.
- [x] La touche `S` n'a aucun effet si le bouton est grisé.
- [x] La disponibilité est réévaluée à chaque changement de scène.
- [x] Si aucune sauvegarde n'existe → bouton toujours grisé.
- [x] `sequence_editor.skip_to_end()` positionne le curseur à la fin de la séquence.
- [x] Les tests GUT passent.
