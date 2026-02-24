# 009 — Point d'entrée par niveau

## Contexte

Le play controller (`story_play_controller.gd`) détermine le point d'entrée de chaque niveau (chapitre, scène, séquence) par heuristique de position (le plus à gauche puis le plus haut). L'utilisateur souhaite pouvoir **marquer explicitement** un noeud comme point d'entrée via le menu contextuel (clic droit > "Point d'entrée" avec case à cocher). Un seul point d'entrée par niveau est autorisé.

## Fonctionnalités

### F1 — Propriété `entry_point_uuid` sur les conteneurs

Chaque conteneur parent stocke le UUID du noeud enfant marqué comme point d'entrée :
- `story.gd` → `entry_point_uuid` désigne le chapitre d'entrée
- `chapter.gd` → `entry_point_uuid` désigne la scène d'entrée
- `scene_data.gd` → `entry_point_uuid` désigne la séquence d'entrée

Valeur par défaut : `""` (aucun point d'entrée explicite).

### F2 — Option "Point d'entrée" dans le menu contextuel

Le `GraphNodeItem` affiche une option checkbox "Point d'entrée" dans le menu contextuel (clic droit). Quand activée :
- Le signal `entry_point_toggled(uuid, checked)` est émis
- L'indicateur visuel est mis à jour (préfixe "▶ " dans le titre)

### F3 — Unicité du point d'entrée par niveau

Chaque vue graphe garantit qu'un seul noeud est marqué comme point d'entrée :
- Cocher un noeud décoche automatiquement l'ancien
- Décocher un noeud efface l'`entry_point_uuid` du modèle parent

### F4 — Utilisation par le play controller

Le play controller utilise `entry_point_uuid` pour déterminer le premier élément à jouer :
- Si un `entry_point_uuid` valide est défini, utiliser cet élément
- Sinon, fallback sur l'heuristique de position actuelle (gauche→droite, haut→bas)

### F5 — Persistance

L'`entry_point_uuid` est sérialisé dans `to_dict()` sous la clé `"entry_point"` et désérialisé dans `from_dict()` avec fallback `""` pour la rétrocompatibilité.

## Critères d'acceptation

- [x] `story.entry_point_uuid` sérialisé/désérialisé dans `to_dict()`/`from_dict()`
- [x] `chapter.entry_point_uuid` sérialisé/désérialisé dans `to_dict()`/`from_dict()` et `to_dict_header()`/`from_dict_header()`
- [x] `scene_data.entry_point_uuid` sérialisé/désérialisé dans `to_dict()`/`from_dict()`
- [x] Rétrocompatibilité : `from_dict()` sans clé `"entry_point"` donne `""`
- [x] `GraphNodeItem` a un item checkbox "Point d'entrée" dans le menu contextuel
- [x] Signal `entry_point_toggled(uuid, checked)` émis lors du toggle
- [x] Indicateur visuel (préfixe "▶ ") quand marqué comme point d'entrée
- [x] Un seul point d'entrée par vue graphe (unicité)
- [x] Play controller utilise `entry_point_uuid` si défini et valide
- [x] Play controller fallback sur heuristique position si UUID vide ou invalide
- [x] Tous les tests passent sans régression
