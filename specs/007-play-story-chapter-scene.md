# Bouton Play à tous les niveaux (Story, Chapter, Scene)

## Résumé

L'éditeur dispose d'un bouton Play au niveau séquence (toolbar de l'éditeur de séquence) qui lit les dialogues avec effet typewriter et transitions de foregrounds. Cette spec ajoute un bouton Play aux niveaux supérieurs (story/chapitre/scène) permettant de jouer une histoire complète en suivant les endings/redirections configurés.

## Modèle de données

Aucune modification du modèle n'est nécessaire. Le contrôleur utilise les modèles existants :
- `Ending` avec `type` = `"auto_redirect"` ou `"choices"`
- `Consequence` avec `type` ∈ `["redirect_sequence", "redirect_scene", "redirect_chapter", "game_over", "to_be_continued"]`
- `Choice` avec `text`, `consequence`

## Architecture

### StoryPlayController (`src/ui/story_play_controller.gd`)

Machine à états avec 3 états :

| État | Description |
|---|---|
| `IDLE` | Pas de lecture en cours |
| `PLAYING_SEQUENCE` | Une séquence est en cours de lecture |
| `WAITING_FOR_CHOICE` | L'utilisateur doit choisir parmi les options |

### Transitions d'état

1. **IDLE** → `start_play_story()` / `start_play_chapter()` / `start_play_scene()` → **PLAYING_SEQUENCE**
2. **PLAYING_SEQUENCE** → séquence terminée → vérifie ending :
   - `auto_redirect` → `_resolve_consequence()` → **PLAYING_SEQUENCE**
   - `choices` → **WAITING_FOR_CHOICE**
   - `game_over` / `to_be_continued` / pas d'ending → **IDLE** + signal `play_finished`
3. **WAITING_FOR_CHOICE** → `on_choice_selected(index)` → `_resolve_consequence()` → **PLAYING_SEQUENCE**

### Résolution des conséquences

| Type | Comportement |
|---|---|
| `redirect_sequence` | Trouve la séquence par UUID dans la scène courante, la joue |
| `redirect_scene` | Trouve la scène dans le chapitre courant, joue sa 1ère séquence |
| `redirect_chapter` | Trouve le chapitre dans la story, joue sa 1ère scène → 1ère séquence |
| `game_over` | Arrête le play avec raison "game_over" |
| `to_be_continued` | Arrête le play avec raison "to_be_continued" |

### Sélection du "premier" élément

"Premier" élément = celui avec la plus petite `position.x` (puis `position.y` en cas d'égalité). Cohérent avec la lecture gauche→droite du graph.

### Signaux émis

- `sequence_play_requested(sequence)` — demande à main.gd de charger et jouer une séquence
- `choice_display_requested(choices)` — demande l'affichage des choix
- `play_finished(reason: String)` — lecture terminée (raisons : "game_over", "to_be_continued", "no_ending", "error", "stopped")

## Comportement attendu

### Bouton Play dans la top bar

- Un bouton "▶ Jouer" visible quand le niveau est `chapters`, `scenes` ou `sequences`
- Se transforme en "■ Arrêter" pendant la lecture
- Le bouton Play de la toolbar séquence reste indépendant (lecture séquence seule)

### Déroulement du play

1. L'utilisateur clique sur "▶ Jouer" depuis n'importe quel niveau
2. Le contrôleur détermine la 1ère séquence à jouer (selon le niveau)
3. Il émet `sequence_play_requested(sequence)`
4. `main.gd` navigue vers la séquence, charge les éditeurs, lance le play via `_sequence_editor_ctrl.start_play()`
5. Quand la séquence se termine, `main.gd` notifie le contrôleur via `on_sequence_finished()`
6. Le contrôleur vérifie l'ending et décide de la suite

### Overlay de choix

Quand le contrôleur émet `choice_display_requested(choices)` :
- Un PanelContainer centré s'affiche dans le visual editor
- Il contient un VBoxContainer avec un Label "Faites votre choix" et un bouton par choix
- Le clic sur un bouton appelle `on_choice_selected(index)` sur le contrôleur

### Arrêt

- Le bouton "■ Arrêter" arrête immédiatement la lecture
- Naviguer en arrière (bouton Retour) arrête aussi la lecture
- Un message s'affiche à la fin de la lecture (ex: "Fin de la lecture — Game Over")

## Cas limites

| Cas | Comportement |
|---|---|
| Séquence sans dialogues | Traitée comme fin immédiate, le contrôleur passe à l'ending |
| Cible UUID introuvable | Arrêt avec message d'erreur |
| Scène/chapitre vide (pas de séquences) | Arrêt avec message |
| Pas d'ending configuré | Arrêt avec "Fin de la lecture (aucune terminaison configurée)" |
| Redirections circulaires | L'utilisateur peut appuyer sur Stop (pas de protection pour v1) |

## Critères d'acceptation

### StoryPlayController
- [x] Machine à états avec 3 états : IDLE, PLAYING_SEQUENCE, WAITING_FOR_CHOICE
- [x] `start_play_story()` trouve le 1er chapitre → 1ère scène → 1ère séquence
- [x] `start_play_chapter()` trouve la 1ère scène → 1ère séquence
- [x] `start_play_scene()` trouve la 1ère séquence
- [x] Sélection du 1er élément par position.x puis position.y
- [x] Suivi des redirections `redirect_sequence`, `redirect_scene`, `redirect_chapter`
- [x] Gestion des choix : état WAITING_FOR_CHOICE + signal `choice_display_requested`
- [x] `game_over` et `to_be_continued` arrêtent le play
- [x] Pas d'ending → arrêt avec raison "no_ending"
- [x] Cible introuvable → arrêt avec raison "error"
- [x] Scène/chapitre vide → arrêt avec raison "error"

### Intégration main.gd
- [x] Bouton "▶ Jouer" dans la top bar, visible aux niveaux chapters/scenes/sequences
- [x] Bouton "■ Arrêter" pendant le play
- [x] Overlay de choix avec boutons
- [x] Navigation automatique vers la séquence jouée
- [x] Arrêt du play via bouton Retour
- [x] Message de fin de lecture affiché

### Tests
- [x] Tests unitaires couvrant tous les cas du contrôleur
- [x] Démarrage à chaque niveau (story, chapter, scene)
- [x] Suivi des redirections
- [x] Sélection de choix
- [x] game_over, to_be_continued
- [x] Pas d'ending
- [x] Cible introuvable
- [x] Scène/chapitre vide
- [x] Sélection du 1er élément par position
