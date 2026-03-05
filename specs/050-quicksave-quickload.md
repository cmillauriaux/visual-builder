# Quicksave / Quickload (sauvegarde rapide)

## Résumé

Ajouter un mécanisme de sauvegarde/chargement rapide via les raccourcis F5 (quicksave) et F9 (quickload), ainsi que des boutons visibles dans l'interface de jeu. Le quicksave utilise un slot dédié séparé des 6 slots manuels existants, permettant une sauvegarde instantanée sans passer par le menu pause. Fonctionnalité standard des visual novels.

## Comportement attendu

### Slot de sauvegarde rapide

- Le quicksave utilise un répertoire dédié `user://saves/quicksave/` contenant `save.json` et `screenshot.png`.
- Ce slot est **totalement séparé** des 6 slots du système de sauvegarde manuelle (037). Il n'apparaît pas dans la grille de sauvegarde/chargement.
- Le quicksave **écrase silencieusement** la sauvegarde rapide précédente sans demander de confirmation.
- Les données sauvegardées sont identiques à celles d'une sauvegarde manuelle : timestamp, story_path, chapter/scene/sequence UUID et noms, dialogue_index, variables.
- Un screenshot est capturé au moment du quicksave.

### Raccourcis clavier

- **F5** : déclenche un quicksave.
- **F9** : déclenche un quickload.
- Les raccourcis ne fonctionnent que pendant le **gameplay actif** (séquence en cours de lecture, jeu non pausé).
- En dehors du gameplay (menus, pause, sélecteur de story), les touches F5/F9 sont ignorées.
- Le quicksave fonctionne immédiatement, même si le texte est en cours d'apparition (typewriter).

### Boutons dans l'interface

- Deux boutons **"Save (F5)"** et **"Load (F9)"** sont affichés à côté du bouton Auto, au-dessus de la zone de texte (bottom-right).
- Les trois boutons (Save, Load, Auto) sont regroupés dans une barre horizontale.
- Les boutons Save et Load suivent les **mêmes conditions d'affichage** que le bouton Auto : visibles pendant le gameplay, cachés sinon.
- Les boutons déclenchent exactement la même action que les raccourcis clavier correspondants.

### Notification toast

- Lors d'un quicksave réussi (via F5 ou bouton), un toast **"Sauvegarde rapide effectuée"** s'affiche en haut à droite pendant 3 secondes.
- Lors d'un appui sur F9 (ou bouton Load) **sans sauvegarde rapide existante**, un toast **"Aucune sauvegarde rapide"** s'affiche pendant 3 secondes.
- Si un nouveau toast arrive avant la fin du précédent, il le remplace immédiatement (compteur de génération).
- Le toast a un `z_index` élevé (100) et `mouse_filter = IGNORE` pour ne pas bloquer les interactions.

### Confirmation avant quickload

- Lorsque le gameplay est actif et qu'une sauvegarde rapide existe, F9/bouton Load affiche un **dialogue de confirmation modal** :
  - Le jeu se met en pause.
  - Message : "Charger la sauvegarde rapide ?"
  - Deux boutons : "Oui" et "Non".
  - **Oui** : charge la sauvegarde rapide (même logique que le chargement d'un slot manuel), retire la pause.
  - **Non** : ferme le dialogue, retire la pause, retour au gameplay.
- L'overlay de confirmation utilise `process_mode = PROCESS_MODE_ALWAYS` pour rester interactif pendant la pause.

### Analytics

- Événement `quicksave` tracké avec `story_title` et `chapter`.
- Événement `quickload` tracké avec `story_title`.

## Critères d'acceptation

### GameSaveManager

- [ ] Constante `QUICKSAVE_DIR = "user://saves/quicksave"` définie.
- [ ] `quicksave(state, screenshot)` crée `save.json` et `screenshot.png` dans le répertoire quicksave.
- [ ] `quickload()` retourne les données sauvegardées ou `{}` si aucune sauvegarde.
- [ ] `quicksave_exists()` retourne `true` uniquement si une sauvegarde rapide existe.
- [ ] `delete_quicksave()` supprime les fichiers du slot quicksave.
- [ ] Un quicksave écrase la sauvegarde précédente sans erreur.
- [ ] Les méthodes quicksave n'affectent pas `list_saves()` (toujours 6 slots).

### Boutons UI

- [ ] Boutons "Save (F5)" et "Load (F9)" créés à côté du bouton Auto dans une barre horizontale (HBoxContainer).
- [ ] Les boutons sont cachés par défaut et visibles uniquement pendant le gameplay (même logique que Auto).
- [ ] Cliquer sur "Save (F5)" déclenche un quicksave + toast.
- [ ] Cliquer sur "Load (F9)" déclenche le flux quickload (vérification + confirmation/toast).

### Raccourcis clavier

- [ ] F5 pendant le gameplay actif déclenche un quicksave.
- [ ] F9 pendant le gameplay actif déclenche le flux quickload.
- [ ] F5 et F9 sont ignorés quand le jeu est en pause ou hors gameplay.
- [ ] Les événements F5/F9 sont consommés (`set_input_as_handled`).

### Toast

- [ ] Toast "Sauvegarde rapide effectuée" affiché 3 secondes après quicksave réussi.
- [ ] Toast "Aucune sauvegarde rapide" affiché 3 secondes si F9 sans sauvegarde existante.
- [ ] Un nouveau toast remplace l'ancien immédiatement.

### Confirmation quickload

- [ ] Dialogue de confirmation affiché avant quickload pendant le gameplay.
- [ ] "Oui" charge la sauvegarde et reprend le jeu.
- [ ] "Non" ferme le dialogue et reprend le jeu.
- [ ] Le jeu est mis en pause pendant le dialogue de confirmation.

### Tests

- [ ] Tests unitaires pour `quicksave`, `quickload`, `quicksave_exists`, `delete_quicksave`.
- [ ] Test que quicksave n'affecte pas les 6 slots réguliers.
- [ ] Tests UI : boutons créés, cachés par défaut, barre horizontale contient 3 boutons.
- [ ] Test toast overlay créé et caché par défaut.
- [ ] Test confirmation overlay créé et caché par défaut.
