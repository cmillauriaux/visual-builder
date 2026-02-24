# Bouton de création contextuel

## Résumé

Un bouton unique dans la barre du haut permet de créer un chapitre, une scène ou une séquence selon le niveau de navigation courant. Son label s'adapte dynamiquement au contexte. Il simplifie le workflow de création en offrant un accès direct sans passer par un clic droit.

## Comportement attendu

### Bouton contextuel

- Un bouton est ajouté dans la top bar (HBoxContainer existante), positionné entre le breadcrumb et le bouton "Sauvegarder".
- Le label du bouton change selon le niveau courant :
  - Niveau `chapters` : **"+ Nouveau chapitre"**
  - Niveau `scenes` : **"+ Nouvelle scène"**
  - Niveau `sequences` : **"+ Nouvelle séquence"**
- Le bouton est **masqué** (visible = false) dans les cas suivants :
  - Aucune histoire n'est ouverte (niveau `none`)
  - Niveau `sequence_edit` (éditeur visuel de séquence)

### Création de l'élément

- Au clic sur le bouton, un nouvel élément est créé dans le graphe courant avec :
  - **Nom auto-incrémenté** basé sur le nombre d'éléments existants + 1. Exemples :
    - "Chapitre 1", "Chapitre 2", "Chapitre 3"...
    - "Scène 1", "Scène 2"...
    - "Séquence 1", "Séquence 2"...
  - **Position décalée** : le noeud est placé avec un décalage horizontal de **300 px** par rapport au dernier noeud créé. Si le graphe est vide, le premier noeud est placé à la position `(100, 100)`.
- L'élément est immédiatement visible dans le graphe après création.
- L'utilisateur peut renommer l'élément ensuite par double-clic sur le titre du noeud (fonctionnalité existante).

### Calcul de la position

- La position du nouveau noeud est calculée ainsi :
  - S'il n'y a aucun noeud dans le graphe : `Vector2(100, 100)`
  - Sinon : `Vector2(position_x_max_existante + 300, 100)` où `position_x_max_existante` est la position X la plus à droite parmi les noeuds existants.

### Calcul du nom auto-incrémenté

- Le numéro est calculé à partir du nombre d'éléments existants + 1 dans la collection courante (chapitres, scènes ou séquences).
- Exemple : s'il y a déjà 2 chapitres, le nouveau sera "Chapitre 3".

## Critères d'acceptation

- [x] Un bouton contextuel est présent dans la top bar, entre le breadcrumb et le bouton "Sauvegarder"
- [x] Le label du bouton affiche "+ Nouveau chapitre" quand le niveau courant est `chapters`
- [x] Le label du bouton affiche "+ Nouvelle scène" quand le niveau courant est `scenes`
- [x] Le label du bouton affiche "+ Nouvelle séquence" quand le niveau courant est `sequences`
- [x] Le bouton est masqué quand aucune histoire n'est ouverte (niveau `none`)
- [x] Le bouton est masqué quand le niveau courant est `sequence_edit`
- [x] Au clic, un nouveau chapitre est créé dans le graphe avec un nom auto-incrémenté (ex: "Chapitre 2")
- [x] Au clic, une nouvelle scène est créée dans le graphe avec un nom auto-incrémenté (ex: "Scène 2")
- [x] Au clic, une nouvelle séquence est créée dans le graphe avec un nom auto-incrémenté (ex: "Séquence 2")
- [x] Le premier noeud d'un graphe vide est placé à la position (100, 100)
- [x] Les noeuds suivants sont décalés de 300 px horizontalement par rapport au noeud le plus à droite
- [x] Le nouveau noeud est immédiatement visible dans le graphe après création
- [x] Le bouton met à jour son label et sa visibilité lors de chaque changement de niveau de navigation
