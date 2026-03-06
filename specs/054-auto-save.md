# Auto-save aux points de choix

## Résumé

Ajouter un système de sauvegarde automatique qui se déclenche aux moments clés du jeu
(avant chaque choix, début de chapitre, début de scène). Les 10 dernières auto-saves
sont conservées par rotation dans des slots dédiés (`user://saves/autosave_N/`).
L'auto-save peut être activé ou désactivé dans les options.

## Comportement attendu

### Déclencheurs

L'auto-save se déclenche dans trois situations, **si `autosave_enabled` est `true`** :

1. **Avant chaque choix** : quand le `StoryPlayController` passe en état `WAITING_FOR_CHOICE`
   (juste avant d'afficher les choix au joueur).
2. **Début de chapitre** : quand `chapter_entered` est émis (entrée dans un nouveau chapitre).
3. **Début de scène** : quand `scene_entered` est émis (entrée dans une nouvelle scène).

Dans chaque cas, le signal `autosave_triggered` est émis par le `StoryPlayController`.

### Rotation des slots

- `NUM_AUTOSAVE_SLOTS = 10` slots numérotés `autosave_0` à `autosave_9`.
- Chaque nouvelle auto-save occupe le slot suivant en rotation circulaire (index 0→9→0…).
- L'index courant est persisté dans un fichier `user://saves/autosave_index.dat` (entier JSON).
- La save la plus récente remplace le slot `(current_index) % NUM_AUTOSAVE_SLOTS`.
- Les slots auto-save sont stockés dans `user://saves/autosave_N/save.json` et
  `user://saves/autosave_N/screenshot.png`.

### Indicateur visuel

- Le signal `notification_triggered` du `StoryPlayController` est émis avec le message
  `"Auto-save..."` après chaque auto-save réussie.
- Le message est géré par la couche play existante (même canal que les notifications de variables).

### Paramètre autosave_enabled

- `GameSettings` expose la propriété `autosave_enabled: bool` (défaut `true`).
- Le paramètre est persisté dans `settings.cfg` sous `[gameplay] > autosave_enabled`.
- `OptionsMenu` ajoute un `CheckButton "Auto-save"` dans la section Gameplay.
- `StoryPlayController.setup()` reçoit un paramètre `autosave_enabled: bool`.
- Si `autosave_enabled` est `false`, le signal `autosave_triggered` n'est **pas** émis
  et aucune auto-save n'est écrite.

### Onglet "Automatiques" dans le menu Load

- L'onglet "Automatiques" affiche toutes les auto-saves existantes, triées de la plus
  récente à la plus ancienne (ordre de la rotation inversé).
- Chaque entrée affiche : screenshot (si disponible), nom du chapitre, nom de la scène,
  date/heure, et un bouton **Charger**.
- Le signal `load_slot_pressed` est émis avec un index spécial négatif :
  `-(slot_autosave_index + 2)` pour distinguer les auto-saves du quicksave (`-1`).
  - Exemple : autosave_0 → `-2`, autosave_1 → `-3`, … autosave_9 → `-11`.
- Si aucune auto-save n'existe : label "Aucune sauvegarde automatique".
- Le placeholder "À venir" (spec 053) est remplacé par ce contenu réel.

## Nouveaux fichiers / modifications

| Fichier | Modification |
|---|---|
| `src/persistence/game_save_manager.gd` | Ajouter `autosave()`, `list_autosaves()`, `load_autosave(n)`, `AUTOSAVE_DIR`, `NUM_AUTOSAVE_SLOTS`, `_get_next_autosave_index()` |
| `src/ui/play/story_play_controller.gd` | Ajouter signal `autosave_triggered`, paramètre `autosave_enabled` dans `setup()`, appels dans `on_sequence_finished()`, `_resolve_consequence()` (chapter/scene redirects) |
| `src/ui/menu/save_load_menu.gd` | Remplacer le placeholder "À venir" par `_refresh_auto_saves()` |
| `src/ui/menu/game_settings.gd` | Ajouter `autosave_enabled: bool = true`, load/save |
| `src/ui/menu/options_menu.gd` | Ajouter `_autosave_enabled_check` dans section Gameplay |

## Critères d'acceptation

- [x] `GameSaveManager.autosave()` écrit dans `user://saves/autosave_N/save.json` avec rotation sur 10 slots.
- [x] `GameSaveManager.list_autosaves()` retourne la liste des auto-saves existantes, triées de la plus récente à la plus ancienne.
- [x] `GameSaveManager.load_autosave(n)` charge les données du slot autosave_n.
- [x] `StoryPlayController.setup()` accepte un paramètre `autosave_enabled: bool`.
- [x] Le signal `autosave_triggered` est émis avant chaque choix (état `WAITING_FOR_CHOICE`).
- [x] Le signal `autosave_triggered` est émis à chaque `chapter_entered`.
- [x] Le signal `autosave_triggered` est émis à chaque `scene_entered`.
- [x] Si `autosave_enabled` est `false`, aucune auto-save n'est déclenchée.
- [x] Le signal `notification_triggered` avec `"Auto-save..."` est émis après chaque auto-save réussie.
- [x] `GameSettings.autosave_enabled` est persisté dans `settings.cfg`.
- [x] `OptionsMenu` affiche un `CheckButton "Auto-save"` dans la section Gameplay.
- [x] L'onglet "Automatiques" du menu Load affiche toutes les auto-saves existantes.
- [x] L'onglet "Automatiques" affiche "Aucune sauvegarde automatique" si aucune auto-save n'existe.
- [x] Cliquer "Charger" sur une auto-save émet `load_slot_pressed` avec l'index approprié (`-(n+2)`).
- [x] La rotation circulaire fonctionne : le slot 9 est suivi par le slot 0.
