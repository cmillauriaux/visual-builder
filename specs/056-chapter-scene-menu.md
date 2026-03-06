# Menu Chapitres / Scènes

## Résumé

Un menu "Chapitres / Scènes" est accessible depuis le menu pause. Il liste tous les chapitres et scènes de l'histoire et permet de rejouer les scènes déjà atteintes par le joueur.

## Comportement attendu

### Ouverture du menu

Quand le joueur clique sur "Chapitres / Scènes" dans le menu pause :

1. Toutes les sauvegardes (manuelles 6 slots, automatiques 10 slots, rapide) sont analysées.
2. Pour chaque sauvegarde, le chapitre (`chapter_uuid`) et la scène (`scene_uuid`) enregistrés permettent de déterminer la progression maximale atteinte.
3. Le menu pause se ferme et le menu "Chapitres / Scènes" s'affiche (le jeu reste en pause).

### Calcul de la progression maximale

- Les chapitres sont ordonnés selon leur position dans `story.chapters` (index 0, 1, 2…).
- Les scènes sont ordonnées selon leur position dans `chapter.scenes` (index 0, 1, 2…).
- La "progression maximale" est la paire `(max_chapter_index, max_scene_index)` la plus avancée trouvée dans l'ensemble des sauvegardes.
- Une scène est considérée "débloquée" si : `chapter_index < max_chapter_index` OU (`chapter_index == max_chapter_index` ET `scene_index <= max_scene_index`).
- Si aucune sauvegarde n'existe, `max_chapter_index = 0` et `max_scene_index = 0` (seule la première scène du premier chapitre est débloquée).

### Affichage

- Les chapitres sont listés dans l'ordre de `story.chapters`.
- Pour chaque chapitre, un en-tête indique le nom du chapitre.
- Pour chaque scène dans un chapitre :
  - **Débloquée** : bouton cliquable affichant le vrai nom de la scène (`scene.scene_name`).
  - **Verrouillée** : élément non-cliquable, grisé. Affiche "Chapitre {chapter_index+1}" sur la première ligne et "??????" sur la deuxième.

### Rejouer une scène

- Cliquer sur une scène débloquée :
  1. Ferme le menu "Chapitres / Scènes".
  2. Arrête la partie en cours (`_play_ctrl.stop_current()`).
  3. Lance la scène sélectionnée depuis son point d'entrée (`_story_play_ctrl.start_play_scene`).
  4. Dépause le jeu.

### Fermeture

- Le bouton "✕" ferme le menu et retourne au menu pause.

## Structure UI

```
ChapterSceneMenu (Control)
  Overlay (ColorRect, semi-transparent)
  CenterContainer
    PanelContainer (min_size 800x500)
      VBoxContainer
        Header (HBoxContainer)
          _title_label (Label) "Chapitres / Scènes"
          CloseButton (Button) "✕"
        ScrollContainer
          _chapters_container (VBoxContainer)
            Pour chaque chapitre :
              ChapterHeader (Label) "Chapitre N — Nom"
              ScenesRow (HBoxContainer)
                Pour chaque scène débloquée : Button (scene_name)
                Pour chaque scène verrouillée : PanelContainer (grisé)
                  VBoxContainer
                    Label "Chapitre N"
                    Label "??????"
```

## Signaux

- `scene_selected(chapter_uuid: String, scene_uuid: String)` — émis quand une scène débloquée est cliquée.
- `close_pressed` — émis quand le bouton fermer est cliqué.

## Critères d'acceptation

- [ ] Un bouton "Chapitres / Scènes" est présent dans le menu pause.
- [ ] Le bouton émet le signal `chapters_scenes_pressed` dans `PauseMenu`.
- [ ] `ChapterSceneMenu` est construit par `build_ui()`.
- [ ] `show_menu(story, max_chapter_idx, max_scene_idx)` affiche le menu et liste les chapitres/scènes.
- [ ] Les chapitres sont listés dans l'ordre de `story.chapters`.
- [ ] Pour chaque chapitre, les scènes sont listées dans l'ordre de `chapter.scenes`.
- [ ] Les scènes débloquées (index <= max) s'affichent comme boutons avec leur vrai nom.
- [ ] Les scènes verrouillées (index > max) s'affichent grisées avec "Chapitre N" et "??????".
- [ ] Cliquer une scène débloquée émet `scene_selected(chapter_uuid, scene_uuid)`.
- [ ] Le bouton "✕" émet `close_pressed`.
- [ ] Si aucune sauvegarde n'existe, seule la première scène du premier chapitre est débloquée.
- [ ] Dans `game.gd`, `_on_chapters_scenes_pressed()` calcule la progression maximale depuis toutes les sauvegardes.
- [ ] Dans `game.gd`, `_on_chapter_scene_selected()` arrête la partie et relance `start_play_scene`.
- [ ] `ChapterSceneMenu` est accessible via `game._chapter_scene_menu`.
