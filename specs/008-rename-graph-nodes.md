# 008 — Renommage titre/sous-titre des noeuds de graphe

## Contexte

Chaque noeud de graphe (chapitre, scène, séquence) affiche actuellement le même texte en titre (`GraphNode.title`) et dans le corps (`ContentLabel`). L'utilisateur souhaite pouvoir personnaliser les noeuds avec un **sous-titre descriptif** (ex: "La forêt maudite") via un clic droit > "Renommer".

**Convention** : Le titre (`GraphNode.title`) reste l'identifiant de type (ex: "Chapitre 1"). Le sous-titre (`ContentLabel`) affiche le nom personnalisé si défini, sinon le titre par défaut.

## Fonctionnalités

### F1 — Champ `subtitle` dans les modèles

- `chapter.gd`, `scene_data.gd`, `sequence.gd` possèdent un champ `var subtitle: String = ""`
- Sérialisé dans `to_dict()` / `to_dict_header()` avec la clé `"subtitle"`
- Désérialisé dans `from_dict()` / `from_dict_header()` avec fallback `""` (rétrocompatibilité)
- Le `to_dict()` de `chapter.gd` inclut `"subtitle"` dans les scene headers inline

### F2 — Affichage du sous-titre dans GraphNodeItem

- `GraphNodeItem` accepte un paramètre optionnel `subtitle` dans `setup()`
- `ContentLabel` affiche le sous-titre si non vide, sinon le nom (`_item_name`)
- Méthodes `get_subtitle()`, `set_subtitle(value)`, `set_item_name_and_subtitle(name, subtitle)`
- Le titre (`GraphNode.title`) affiche toujours `_item_name`

### F3 — Menu contextuel "Renommer"

- Clic droit sur un `GraphNodeItem` affiche un `PopupMenu` avec l'option "Renommer"
- Sélectionner "Renommer" émet le signal `rename_requested(uuid: String)`
- Le `PopupMenu` est créé dans `setup()` et connecté

### F4 — Dialogue de renommage (`RenameDialog`)

- `ConfirmationDialog` avec deux champs :
  - `LineEdit` "Titre" (pré-rempli avec le nom actuel)
  - `LineEdit` "Description (optionnel)" (pré-rempli avec le sous-titre actuel)
- Signal `rename_confirmed(uuid: String, new_name: String, new_subtitle: String)`
- Méthode `setup(uuid, current_name, current_subtitle)`

### F5 — Propagation dans les vues graphe

- Chaque vue (`chapter_graph_view`, `scene_graph_view`, `sequence_graph_view`) :
  - Émet un signal `*_rename_requested(uuid)` relayé depuis `GraphNodeItem.rename_requested`
  - `_create_node()` passe le sous-titre et connecte le signal rename
  - `load_*()` passe `item.subtitle` à `_create_node()`
  - `rename_*()` accepte un paramètre optionnel `new_subtitle: String = ""`

### F6 — Câblage dans le contrôleur principal (`main.gd`)

- Connexion des signaux `*_rename_requested` des 3 vues graphe
- Chaque handler : récupère le modèle, ouvre `RenameDialog`, sur confirmation appelle `rename_*()` sur la vue

## Critères d'acceptation

- [x] CA1 : Les modèles sérialisent/désérialisent correctement `subtitle`
- [x] CA2 : Les fichiers sans `subtitle` chargent sans erreur (rétrocompatibilité)
- [x] CA3 : `ContentLabel` affiche le sous-titre si défini, sinon le nom
- [x] CA4 : Le clic droit sur un noeud affiche le menu "Renommer"
- [x] CA5 : Le dialogue de renommage s'ouvre avec les valeurs actuelles pré-remplies
- [x] CA6 : La confirmation met à jour le modèle et l'affichage du noeud
- [x] CA7 : Le roundtrip save/load préserve les sous-titres
- [x] CA8 : Tous les tests GUT passent
