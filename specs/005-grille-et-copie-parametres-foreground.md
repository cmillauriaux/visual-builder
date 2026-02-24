# Grille de placement et copie de paramètres foreground

## Résumé

Deux outils pour faciliter le placement précis des foregrounds sur le background dans l'éditeur visuel de séquence : une grille superposée au background avec snapping optionnel, et un système de copier/coller des paramètres de positionnement entre foregrounds.

## Comportement attendu

### Grille de placement

- Un bouton toggle dans la toolbar de l'éditeur visuel permet d'afficher/masquer la grille.
- La grille divise le background en **12×12 cellules** (espacement fixe, non configurable).
- La grille s'affiche **par-dessus le background mais sous les foregrounds** (entre `_bg_rect` et `_fg_container` dans l'arbre de nœuds).
- Les lignes de la grille sont semi-transparentes (ex: blanc à 20-30% d'opacité) pour rester discrètes.
- La grille suit les transformations de zoom/pan du canvas.
- Si aucun background n'est chargé, la grille ne s'affiche pas.

### Snapping (magnétisme)

- Un second bouton toggle dans la toolbar permet d'activer/désactiver le snapping, **indépendamment** de la visibilité de la grille.
- Quand le snapping est actif, le déplacement d'un foreground (drag) cale son point d'ancrage (`anchor_bg`) sur le **point de snap le plus proche**.
- Les points de snap sont les **intersections de la grille** (13×13 = 169 points) **et les centres des cellules** (12×12 = 144 points), soit 313 points au total.
- Le snapping s'applique au relâchement du drag (ou en continu pendant le drag — le foreground saute au point le plus proche).
- Le snapping est purement visuel/positionnement : il modifie `anchor_bg` pour correspondre à un point de grille, sans modifier `anchor_fg` ni `scale`.

### Copier les paramètres d'un foreground

- Clic droit sur un foreground → le menu contextuel existant affiche une nouvelle option **"Copier les paramètres"** (en plus de "Supprimer").
- Cette action copie en mémoire (variable interne, pas le presse-papiers système) les propriétés suivantes du foreground ciblé :
  - `scale` (float)
  - `anchor_bg` (Vector2)
  - `anchor_fg` (Vector2)
  - `flip_h` (bool)
  - `flip_v` (bool)

### Coller les paramètres sur un foreground

- Clic droit sur un foreground → le menu contextuel affiche **"Coller les paramètres"**.
- Cette option est **toujours visible** mais **grisée (désactivée)** si aucun paramètre n'a été copié au préalable.
- Au clic sur "Coller les paramètres", les 5 propriétés copiées sont appliquées au foreground ciblé et le visuel est immédiatement mis à jour.
- Les propriétés non copiées (image, nom, uuid, z_order, opacity, transitions) restent inchangées.

## Critères d'acceptation

### Grille

- [x] Un bouton toggle affiche/masque la grille sur le preview visuel
- [x] La grille divise le background en 12×12 cellules
- [x] La grille est visible entre le background et les foregrounds (z-order correct)
- [x] La grille suit le zoom et le pan du canvas
- [x] La grille ne s'affiche pas quand il n'y a pas de background

### Snapping

- [x] Un bouton toggle active/désactive le snapping, indépendamment de la grille
- [x] Quand le snapping est actif, le drag d'un foreground cale `anchor_bg` sur le point de snap le plus proche
- [x] Les points de snap incluent les intersections (13×13) et les centres des cellules (12×12)
- [x] Le snapping ne modifie que `anchor_bg`, pas les autres propriétés

### Copier/Coller les paramètres

- [x] Le menu contextuel (clic droit) contient "Copier les paramètres"
- [x] "Copier les paramètres" stocke scale, anchor_bg, anchor_fg, flip_h et flip_v du foreground ciblé
- [x] Le menu contextuel contient "Coller les paramètres", toujours visible
- [x] "Coller les paramètres" est grisé si rien n'a été copié
- [x] "Coller les paramètres" applique les 5 propriétés copiées au foreground ciblé
- [x] Le visuel du foreground se met à jour immédiatement après le collage
- [x] Les propriétés non concernées (image, nom, uuid, z_order, opacity, transitions) ne sont pas modifiées
