# Propagation des modifications de foreground aux dialogues suivants

## Contexte

Dans l'éditeur de séquence, quand un foreground est modifié (position, scale, flip, opacity, transition, etc.), les dialogues suivants peuvent contenir des foregrounds à la même position initiale. L'utilisateur souhaite pouvoir propager automatiquement la modification à ces foregrounds similaires via une fenêtre de confirmation.

## Comportement attendu

1. L'utilisateur modifie une propriété d'un foreground dans le dialogue N (via le panneau de propriétés ou par drag visuel)
2. Le système scanne les dialogues suivants (N+1, N+2, ...) qui possèdent **leurs propres foregrounds** (non hérités)
3. Pour chaque foreground trouvé dont `anchor_bg` est à **±1% (0.01)** de la position **initiale** (avant modification) du foreground modifié, il est considéré comme un "match"
4. Si des matchs existent, une fenêtre de confirmation apparaît :
   > "X foreground(s) dans Y dialogue(s) suivant(s) ont une position similaire. Appliquer la modification à tous ?"
   > [Oui] [Non]
5. Si l'utilisateur confirme, la modification est propagée aux foregrounds matchés (voir sémantique ci-dessous)

## Sémantique de propagation par type de propriété

La propagation n'utilise pas une approche unique "delta" ou "absolue" — chaque type de propriété a sa propre sémantique :

| Propriété | Sémantique | Détail |
|---|---|---|
| `anchor_bg` | **Delta** (décalage) | `fg.anchor_bg += (new_anchor_bg - initial_anchor_bg)` — chaque foreground est décalé du même vecteur, préservant les positions relatives |
| `scale` | **Absolue** | `fg.scale = new_scale` |
| `flip_h`, `flip_v` | **Absolue** | `fg.flip_h = new_flip_h` |
| `opacity` | **Absolue** | `fg.opacity = new_opacity` |
| `z_order` | **Absolue** | `fg.z_order = new_z_order` |
| `transition_type` | **Absolue** | `fg.transition_type = new_type` |
| `transition_duration` | **Absolue** | `fg.transition_duration = new_duration` |

**Justification** : La position est la seule propriété où un delta a du sens — si un personnage est décalé de 10% vers la droite dans le dialogue N, on veut décaler les copies suivantes du même montant, pas les téléporter au même point. Les autres propriétés (booléens, valeurs discrètes, échelle) sont plus naturellement "remplacées" par la nouvelle valeur.

## Règles de matching

- Comparaison sur `anchor_bg` (coordonnées normalisées 0.0-1.0)
- Seuil de tolérance : **±0.01** sur chaque axe (x et y). Ce seuil est plus strict que le `0.05` utilisé par la normalisation (`_positions_close` dans `sequence_editor.gd`) car la propagation est une action destructrice qui doit être précise. Le `0.01` du `_wrapper_matches_fg` dans `sequence_visual_editor.gd` a été choisi comme référence.
- Comparaison avec la position **initiale** du foreground (avant la modification en cours)
- Tous les foregrounds matchant dans un même dialogue sont inclus (pas de filtre par nom, image ou UUID)
- Seuls les dialogues avec `dlg.foregrounds.size() > 0` sont considérés (les dialogues héritant sont ignorés)

## Prérequis : dialogue avec foregrounds propres

La propagation ne s'applique que lorsque le dialogue courant possède **ses propres foregrounds** (`dlg.foregrounds.size() > 0`). Si le dialogue est en mode hérité, l'utilisateur doit d'abord confirmer la création d'une copie locale (dialogue `_inherit_confirm_dialog` existant). Le snapshot est capturé **après** la copie locale via `ensure_own_foregrounds()`, pas avant — pour éviter les références d'objets périmées.

**Résolution de la référence après copie** : `ensure_own_foregrounds()` crée de nouveaux objets mais préserve les UUIDs. Après l'appel, le contrôleur doit **re-résoudre** le foreground par UUID depuis `dlg.foregrounds` pour obtenir la bonne référence avant de capturer le snapshot.

## Architecture

### Approche choisie : détection centralisée dans le contrôleur

La logique de recherche/propagation vit dans `sequence_editor.gd` (contrôleur de données). L'orchestration (snapshot, détection, confirmation) est dans `sequence_ui_controller.gd` pour éviter d'alourdir `main.gd`.

### Flux de données

```
[Sélection foreground (ou après ensure_own_foregrounds)]
  → Capturer l'état initial (anchor_bg + propriétés modifiables)
  → Stocker dans _fg_initial_snapshot: Dictionary

[Modification (properties panel OU drag visuel)]
  → Calculer les changements (propriétés modifiées vs snapshot initial)
  → sequence_editor.find_similar_foregrounds(initial_anchor_bg, dialogue_index) → matches
  → Si matches non vide → afficher confirmation dialog
  → Si confirmé → sequence_editor.propagate_fg_changes(matches, changes, initial_anchor_bg)
  → EventBus.story_modified.emit()
  → Mettre à jour le snapshot initial avec les nouvelles valeurs (que l'utilisateur ait confirmé ou refusé)
```

**Comportement du dialogue de confirmation** :
- **Oui** : la propagation est appliquée, le snapshot est mis à jour
- **Non** : la modification du foreground courant est conservée, la propagation est ignorée, le snapshot est quand même mis à jour (pour ne pas re-proposer la même modification au prochain changement)
- **Fermeture du dialogue** (croix) : identique à "Non"

**Timing dans `main.gd`** : `on_foreground_modified()` est appelé **après** les mises à jour visuelles existantes (`refresh_foreground_z_order`, `refresh_foreground_flip`, `update_foregrounds`). Si la propagation est confirmée, les foregrounds des dialogues affectés sont mis à jour via `_update_foreground_visuals()` du visual editor lors du prochain changement de dialogue.

**Drag visuel** : pendant un drag, le modèle (`fg.anchor_bg`) est muté incrémentalement à chaque mouvement de souris. Le signal `foreground_modified` n'est émis qu'au mouse-up. Le snapshot (capturé à la sélection) contient toujours la valeur d'avant le drag, donc `_compute_fg_changes` détecte correctement le delta total.

### Nouvelles méthodes dans `sequence_editor.gd`

```gdscript
const PROPAGATION_THRESHOLD := 0.01

## Trouve les foregrounds dans les dialogues suivants dont anchor_bg est à ±threshold
## de la position donnée. Ne considère que les dialogues avec leurs propres foregrounds.
func find_similar_foregrounds(anchor_bg: Vector2, from_dialogue_index: int, threshold: float = PROPAGATION_THRESHOLD) -> Array:
    # Retourne Array[{dialogue_index: int, foreground: Foreground}]

## Applique un ensemble de changements de propriétés aux foregrounds matchés.
## Pour anchor_bg, applique un delta : fg.anchor_bg += (changes["anchor_bg"] - initial_anchor_bg)
## Pour les autres propriétés, applique la valeur absolue : fg.set(prop, value)
func propagate_fg_changes(matches: Array, changes: Dictionary, initial_anchor_bg: Vector2) -> void:
```

### Capture du snapshot dans `sequence_ui_controller.gd`

```gdscript
var _fg_initial_snapshot: Dictionary = {}

# Propriétés trackées pour la détection de changements
# Note : anchor_fg est exclu car l'utilisateur ne peut pas le modifier via l'UI
const TRACKED_FG_PROPERTIES := [
    "anchor_bg", "scale", "z_order",
    "flip_h", "flip_v", "opacity",
    "transition_type", "transition_duration",
]

func _capture_fg_snapshot(fg) -> Dictionary:
    var snapshot := {}
    for prop in TRACKED_FG_PROPERTIES:
        snapshot[prop] = fg.get(prop)
    return snapshot

func _compute_fg_changes(fg, snapshot: Dictionary) -> Dictionary:
    var changes := {}
    for key in snapshot.keys():
        if fg.get(key) != snapshot[key]:
            changes[key] = fg.get(key)
    return changes
```

### Points d'interception

| Source de modification | Où intercepter | Comment |
|---|---|---|
| Properties panel (spinbox, slider, checkbox) | `_on_foreground_properties_changed()` dans `main.gd` | Délègue à `_seq_ui_ctrl.on_foreground_modified()` |
| Drag visuel (déplacement) | `_on_fg_gui_input()` dans `sequence_visual_editor.gd` au mouse-up | Émet le signal `foreground_modified` |
| Resize handle (scale) | `_on_resize_handle_input()` dans `sequence_visual_editor.gd` au mouse-up | Émet le même signal `foreground_modified` |

Un seul signal `foreground_modified` est ajouté à `sequence_visual_editor.gd`, émis au mouse-up du drag et du resize. Il est connecté dans `main.gd._connect_signals()` et délègue à `_seq_ui_ctrl.on_foreground_modified()`.

### Dialogue de confirmation

Un `ConfirmationDialog` instancié dans `sequence_ui_controller.gd` (pattern identique au dialogue de suppression de dialogue existant dans le même fichier).

### Protection mode Play

La propagation est désactivée pendant le mode Play (`_playing == true`). En pratique, cela est implicitement garanti car le visual editor désélectionne tous les foregrounds au démarrage du Play (`_on_play_started`), donc aucun snapshot n'est actif.

## Ce qui n'est PAS dans le scope

- Undo/redo de la propagation (pourra être ajouté plus tard via le système de commandes)
- Propagation aux dialogues **précédents** (uniquement les suivants)
- Matching par nom, image ou UUID (uniquement par position `anchor_bg`)
- Dialogues héritant leurs foregrounds (uniquement ceux avec foregrounds explicites)
- Modification de `anchor_fg` (non exposé dans l'UI, exclu du snapshot)

## Fichiers impactés

| Fichier | Modifications |
|---|---|
| `src/ui/sequence/sequence_editor.gd` | + constante `PROPAGATION_THRESHOLD`, + `find_similar_foregrounds()`, + `propagate_fg_changes()` |
| `src/controllers/sequence_ui_controller.gd` | + snapshot capture (`_fg_initial_snapshot`, `_capture_fg_snapshot`, `_compute_fg_changes`), + `on_foreground_modified()`, + dialogue de confirmation, + `TRACKED_FG_PROPERTIES` |
| `src/main.gd` | + connexion du signal `foreground_modified`, + délégation à `_seq_ui_ctrl.on_foreground_modified()` |
| `src/ui/sequence/sequence_visual_editor.gd` | + signal `foreground_modified` émis au mouse-up du drag et du resize |
| `specs/ui/sequence/test_sequence_editor.gd` | + tests pour `find_similar_foregrounds()` et `propagate_fg_changes()` |
| `specs/ui/sequence/test_foreground_propagation.gd` | + tests d'intégration pour le flux complet (snapshot, détection, propagation) |
