# Spec 058 — Historique des dialogues

## Résumé

Un bouton "Historique (H)" placé à côté du bouton Skip dans la barre de boutons de jeu permet au joueur de consulter tous les dialogues déjà lus depuis le début de la session courante. Un panneau overlay scrollable s'ouvre, affichant chaque réplique (personnage + texte) dans l'ordre chronologique.

## Comportement attendu

### Bouton Historique

- Le bouton est libellé "Historique (H)" et est positionné après le bouton Skip dans `_play_buttons_bar`.
- Il est toujours **activé** (pas de logique de grisage), dès que la lecture est en cours.
- Cliquer dessus ouvre ou ferme le panneau historique (toggle).
- Le raccourci clavier `H` ouvre/ferme le panneau si la lecture est en cours.
- `H` n'a aucun effet si les choix sont affichés.

### Enregistrement de l'historique

- À chaque changement de dialogue (`on_play_dialogue_changed`), le dialogue affiché (personnage + texte complet) est ajouté à la liste d'historique.
- Quand le joueur sélectionne un choix (`_on_choice_selected`), le texte du choix est ajouté avec le marqueur `"→"` comme personnage (ex. `{ "character": "→", "text": "Je choisis cette option" }`).
- L'historique est stocké dans `GamePlayController` sous `_dialogue_history: Array[Dictionary]`, chaque entrée ayant la forme `{ "character": String, "text": String }`.
- L'historique est **réinitialisé** (`_dialogue_history = []`) à l'appel de `_cleanup_play()` (fin ou arrêt d'une histoire).

### Panneau historique (overlay)

- Le panneau est un `PanelContainer` centré sur l'écran (`PRESET_CENTER`), avec une taille minimale de `Vector2(600, 400)` et une taille maximale de 80 % de l'écran (géré via `custom_minimum_size`).
- Un `ScrollContainer` avec un `VBoxContainer` interne affiche les entrées dans l'ordre chronologique (la plus ancienne en haut, la plus récente en bas).
- Chaque entrée est rendue par un `Label` multi-ligne : `[Personnage] : texte` (ou juste le texte si le personnage est vide).
- À l'ouverture, le panneau se scrolle automatiquement vers le bas (entrée la plus récente visible).
- Une zone cliquable transparente (`ColorRect` ou `Control` avec `MOUSE_FILTER_STOP`) en fond ferme le panneau si cliquée.
- Le panneau est affiché par-dessus tout le reste (z_index élevé).
- Il se ferme automatiquement quand la lecture s'arrête (`_cleanup_play`).

### Indicateur visuel du bouton

- Panneau fermé : texte "Historique (H)" — standard.
- Panneau ouvert : texte "Historique [ON]" — couleur override (ex. `Color(0.2, 0.8, 0.8)`).

## Architecture

### GamePlayController

- `_dialogue_history: Array[Dictionary]` — liste des dialogues joués.
- `_history_button: Button = null` — référence au bouton.
- `_history_panel: Control = null` — référence au panneau overlay.
- `_history_open: bool = false` — état du panneau.
- `open_history()` : construit et affiche le panneau (ou le ferme si déjà ouvert).
- `close_history()` : ferme et supprime le panneau.
- Dans `on_play_dialogue_changed()` : append `{ "character": dlg.character, "text": dlg.text }` à `_dialogue_history`.
- Dans `_cleanup_play()` : `_dialogue_history = []`, `close_history()`, `_history_button.disabled = true` (si présent).
- Dans `_start_sequence_actually()` : `_history_button.disabled = false` (si présent).
- Dans `_input()` : si `KEY_H` et lecture en cours et pas de choix affichés → `open_history()`.

### game_ui_builder.gd

Ajout dans `_build_play_overlay()` :
```
game._history_button = Button.new()
game._history_button.text = "Historique (H)"
game._history_button.custom_minimum_size = Vector2(140, 30)
game._history_button.clip_text = true
game._history_button.disabled = true
```

Ajout dans `_build_play_buttons_bar()` après `_skip_button` :
```
game._play_buttons_bar.add_child(game._history_button)
```

## Structure des fichiers

### Fichiers créés

| Fichier | Rôle |
|---------|------|
| `specs/058-history-panel.md` | Cette spécification |
| `specs/test_history_panel.gd` | Tests unitaires |

### Fichiers modifiés

| Fichier | Modification |
|---------|-------------|
| `src/controllers/game_play_controller.gd` | Historique, bouton, panneau, touche H |
| `src/controllers/game_ui_builder.gd` | Bouton Historique |

## Critères d'acceptation

- [x] Le bouton "Historique (H)" est présent dans la barre de boutons de jeu (`game._history_button`).
- [x] Le bouton est grisé (`disabled = true`) en dehors d'une lecture active.
- [x] Le bouton est activé (`disabled = false`) dès qu'une séquence démarre.
- [x] Cliquer le bouton ouvre le panneau historique (s'il est fermé).
- [x] Cliquer le bouton ferme le panneau historique (s'il est ouvert).
- [x] La touche `H` ouvre/ferme le panneau si la lecture est en cours.
- [x] La touche `H` n'a aucun effet si les choix sont affichés.
- [x] Chaque dialogue joué (personnage + texte) est ajouté à `_dialogue_history`.
- [x] Quand le joueur sélectionne un choix, le texte du choix est ajouté à `_dialogue_history` avec le marqueur `"→"`.
- [x] Le panneau affiche les entrées dans l'ordre chronologique (plus ancienne en haut).
- [x] À l'ouverture, le panneau est scrollé vers le bas (entrée la plus récente visible).
- [x] Cliquer en dehors du panneau le ferme.
- [x] L'historique est réinitialisé à chaque nouvelle histoire ou arrêt.
- [x] Le panneau se ferme automatiquement lors du `_cleanup_play()`.
- [x] Le texte du bouton est "Historique [ON]" (avec couleur) quand le panneau est ouvert.
- [x] Les tests GUT passent.
