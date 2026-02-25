# Couleur des liens selon le type de transition

## Résumé

Les connexions entre nœuds dans les graphes (séquences, scènes, chapitres) sont colorées selon leur nature : **blanc** pour une transition automatique, **vert** pour un choix du joueur, **jaune** quand les deux types coexistent. Un tooltip apparaît au survol d'un lien pour en expliquer la nature.

## Comportement attendu

### Types de connexion

Chaque connexion (from → to) possède un type calculé à partir des sources qui la génèrent :

| Source | Type attribué |
|--------|---------------|
| Connexion manuelle (`connections[]`) | `"transition"` |
| Ending `auto_redirect` avec `redirect_*` | `"transition"` |
| Ending `choices` avec une consequence `redirect_*` | `"choice"` |
| Les deux types présents sur la même paire (from, to) | `"both"` |

Le cas `"both"` est possible :
- Au niveau **scène/chapitre** : plusieurs séquences dans un même conteneur source pointent vers la même cible, certaines en `auto_redirect`, d'autres en `choices`.
- Au niveau **séquence** : connexion manuelle vers B + ending `choices` contenant aussi B.

### Coloration des ports

Les couleurs des ports sont mises à jour après calcul de la carte des types :

- **Port droit** (sortant) d'un nœud : couleur basée sur l'agrégat des types de toutes ses connexions sortantes
- **Port gauche** (entrant) d'un nœud : couleur basée sur l'agrégat des types de toutes ses connexions entrantes
- La couleur de ligne = `lerp(couleur_port_droit, couleur_port_gauche, 0.5)`

Valeurs des couleurs :
- `"transition"` → `Color.WHITE`
- `"choice"` → `Color(0.0, 0.9, 0.2)` (vert)
- `"both"` → `Color(1.0, 0.85, 0.0)` (jaune)

### Déduplication

Une paire (from, to) ne crée qu'**un seul lien** dans GraphEdit, même si elle est contribuée par plusieurs sources. Les types sont agrégés dans `_connection_type_map` avant la connexion.

### Tooltip au survol

- Détection : en `_process()`, on vérifie si la souris est à moins de 10 pixels d'un point échantillonné sur la courbe de Bézier d'une connexion
- Si oui : un panel flottant apparaît près du curseur avec le texte :
  - `"transition"` → "Transition automatique"
  - `"choice"` → "Choix du joueur"
  - `"both"` → "Transition et Choix"
- Le panel suit le curseur tant que la souris reste sur la connexion
- Il disparaît quand la souris quitte la zone de proximité

### API exposée

Chaque vue graphe expose :
```gdscript
func get_connection_type(from_uuid: String, to_uuid: String) -> String
# Retourne "transition", "choice", "both", ou "" si connexion inexistante
```

## Critères d'acceptation

### Calcul du type de connexion
- [x] Une connexion manuelle a le type "transition"
- [x] Une connexion issue d'un ending `auto_redirect` a le type "transition"
- [x] Une connexion issue d'un ending `choices` a le type "choice"
- [x] Une connexion présente à la fois comme manuelle ET comme `choices` a le type "both"
- [x] Au niveau scène : une connexion contribuée par `auto_redirect` ET `choices` de séquences différentes a le type "both"
- [x] `get_connection_type()` retourne "" pour une paire non connectée

### Coloration des ports
- [x] Un nœud sans connexion sortante a son port droit blanc
- [x] Un nœud dont toutes les connexions sortantes sont "transition" a son port droit blanc
- [x] Un nœud dont toutes les connexions sortantes sont "choice" a son port droit vert
- [x] Un nœud avec des connexions sortantes de types mixtes a son port droit jaune
- [x] Un nœud sans connexion entrante a son port gauche blanc
- [x] Un nœud dont toutes les connexions entrantes sont "choice" a son port gauche vert
- [x] Un nœud avec connexions entrantes mixtes a son port gauche jaune

### Déduplication préservée
- [x] Une connexion contribuée par deux sources n'apparaît qu'une seule fois dans le graphe
- [x] La connexion manuelle + ending vers même cible → un seul lien (type "both" si types différents)

### Tooltip
- [x] Le tooltip s'affiche au survol d'une connexion "transition" avec "Transition automatique"
- [x] Le tooltip s'affiche au survol d'une connexion "choice" avec "Choix du joueur"
- [x] Le tooltip s'affiche au survol d'une connexion "both" avec "Transition et Choix"
- [x] Le tooltip est invisible quand aucune connexion n'est survolée

### Tests
- [x] Tests unitaires pour `get_connection_type()` sur les 3 niveaux de graphe
- [x] Tests unitaires pour les couleurs des ports selon les types de connexion
- [x] Les tests existants des connexions continuent de passer
