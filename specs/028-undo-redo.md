# Mécanisme Undo/Redo

## Résumé

Implémente un système d'annulation/rétablissement d'actions dans l'éditeur visuel. L'utilisateur peut annuler (Ctrl+Z) ou rétablir (Ctrl+Y) jusqu'à 50 actions, via des boutons dans la barre de navigation ou des raccourcis clavier. La pile d'historique est globale et partagée entre tous les niveaux de l'éditeur.

## Comportement attendu

### Service `UndoRedoService`

- Singleton accessible via `src/services/undo_redo_service.gd`
- Implémente le pattern Command : chaque action est un objet avec une méthode `execute()` et `undo()`
- La pile `_undo_stack` contient au maximum 50 commandes ; au-delà, l'entrée la plus ancienne est supprimée
- La pile `_redo_stack` est vidée dès qu'une nouvelle commande est poussée
- Méthodes publiques : `push(command)`, `undo()`, `redo()`, `clear()`, `can_undo() -> bool`, `can_redo() -> bool`, `get_undo_label() -> String`, `get_redo_label() -> String`

### Commandes couvertes

Chaque commande est une classe interne ou un script dans `src/commands/` :

| Commande | Description |
|---|---|
| `AddChapterCommand` | Ajout d'un chapitre |
| `RemoveChapterCommand` | Suppression d'un chapitre |
| `AddSceneCommand` | Ajout d'une scène |
| `RemoveSceneCommand` | Suppression d'une scène |
| `AddSequenceCommand` | Ajout d'une séquence |
| `RemoveSequenceCommand` | Suppression d'une séquence |
| `AddConditionCommand` | Ajout d'une condition |
| `RemoveConditionCommand` | Suppression d'une condition |
| `RenameNodeCommand` | Renommage d'un nœud (chapitre, scène, séquence, condition) |
| `MoveNodeCommand` | Déplacement d'un nœud dans un graphe |
| `AddDialogueCommand` | Ajout d'un dialogue dans une séquence |
| `RemoveDialogueCommand` | Suppression d'un dialogue dans une séquence |
| `EditDialogueCommand` | Modification du texte ou du personnage d'un dialogue |

### Boutons dans la barre de navigation

- Deux boutons `← Annuler` et `Rétablir →` ajoutés dans `_top_bar` (à gauche du spacer)
- Le bouton `← Annuler` est désactivé (`disabled = true`) quand `can_undo()` retourne `false`
- Le bouton `Rétablir →` est désactivé quand `can_redo()` retourne `false`
- Chaque bouton affiche un tooltip dynamique indiquant l'action concernée :
  - Ex : `Annuler : Ajout chapitre "Chapitre 2"`
  - Ex : `Rétablir : Suppression dialogue`

### Raccourcis clavier

- `Ctrl+Z` déclenche `undo()`
- `Ctrl+Y` ou `Ctrl+Shift+Z` déclenche `redo()`
- Les raccourcis sont actifs dans tout l'éditeur (gérés dans `src/main.gd` via `_input`)

### Réinitialisation de la pile

- Lors du chargement d'une histoire (`on_load_pressed`), la pile est vidée via `clear()`
- Lors de la création d'une nouvelle histoire (`on_new_story_pressed`), la pile est vidée
- Les boutons sont mis à jour (désactivés) après chaque `clear()`

### Mise à jour de la vue après undo/redo

- Après `undo()` ou `redo()`, `refresh_current_view()` est appelé dans `main.gd` pour synchroniser l'affichage
- Les boutons sont rafraîchis (enabled/disabled + tooltip) après chaque opération undo/redo/push

## Critères d'acceptation

- [x] Un service `UndoRedoService` existe dans `src/services/undo_redo_service.gd` avec les méthodes `push`, `undo`, `redo`, `clear`, `can_undo`, `can_redo`, `get_undo_label`, `get_redo_label`
- [x] La pile undo est limitée à 50 entrées maximum
- [x] La pile redo est vidée lors du push d'une nouvelle commande
- [x] Les 13 commandes listées sont implémentées dans `src/commands/`
- [x] Deux boutons `← Annuler` et `Rétablir →` sont visibles dans la barre de navigation
- [x] Les boutons sont désactivés quand aucune action n'est disponible
- [x] Les boutons affichent un tooltip indiquant l'action concernée
- [x] `Ctrl+Z` annule la dernière action
- [x] `Ctrl+Y` (ou `Ctrl+Shift+Z`) rétablit l'action annulée
- [x] La pile est vidée lors du chargement ou de la création d'une nouvelle histoire
- [x] La vue est rafraîchie après chaque undo/redo
- [x] Les boutons undo/redo ne sont visibles que lorsqu'une histoire est ouverte
