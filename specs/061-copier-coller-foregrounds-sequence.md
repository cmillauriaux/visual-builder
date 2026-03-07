# Copier/Coller les foregrounds entre séquences

## Résumé

Permet de copier tous les foregrounds d'une séquence (niveau séquence + par dialogue) via le menu contextuel (clic droit) du noeud de séquence dans le graphe, puis de les coller sur une autre séquence. Les positions, effets visuels (scale, flip, opacity, transitions, z_order) et images sont conservés.

## Comportement attendu

### Copier les foregrounds

- Clic droit sur un noeud de séquence dans le graphe → le menu contextuel affiche une option **"Copier les foregrounds"** (après les options de transition existantes).
- L'option est **toujours visible** mais **grisée** si la séquence source ne contient aucun foreground (ni au niveau séquence, ni dans ses dialogues).
- La copie stocke en mémoire interne (pas le presse-papiers système) :
  - Les foregrounds de la séquence (tableau `foregrounds` du modèle Sequence)
  - Les foregrounds de chaque dialogue (tableau `foregrounds` de chaque Dialogue), indexés par position dans la liste des dialogues
- Toutes les propriétés de chaque foreground sont copiées : `fg_name`, `image`, `z_order`, `opacity`, `flip_h`, `flip_v`, `scale`, `anchor_bg`, `anchor_fg`, `transition_type`, `transition_duration`.
- Le clipboard persiste lors de la navigation entre scènes (stocké au niveau contrôleur).

### Coller les foregrounds

- Clic droit sur un noeud de séquence → le menu contextuel affiche **"Coller les foregrounds"**.
- L'option est **toujours visible** mais **grisée** si aucun foreground n'a été copié au préalable.
- Au collage :
  - Les foregrounds de la séquence cible sont **remplacés** par des copies des foregrounds de la source (avec de nouveaux UUIDs).
  - Pour chaque dialogue de la séquence cible (par index) : si un dialogue correspondant existait dans la source, ses foregrounds sont copiés (avec de nouveaux UUIDs). Si le dialogue cible n'a pas de correspondance dans la source, ses foregrounds restent inchangés.
  - Les propriétés non liées aux foregrounds (texte, personnage, background, ending, musique, etc.) ne sont **pas modifiées**.
- Le visuel n'est pas mis à jour immédiatement (l'utilisateur doit ouvrir la séquence pour voir le résultat) mais l'histoire est marquée comme modifiée (`story_modified`).

### Interaction avec la multi-sélection

- La copie s'applique uniquement à la séquence sur laquelle le clic droit a été effectué (pas de copie multi-séquence).
- Le collage s'applique uniquement à la séquence cible du clic droit.

## Critères d'acceptation

- [ ] Le menu contextuel (clic droit) d'un noeud séquence contient "Copier les foregrounds"
- [ ] "Copier les foregrounds" est grisé si la séquence n'a aucun foreground (séquence + dialogues)
- [ ] "Copier les foregrounds" stocke les foregrounds de la séquence et de tous ses dialogues
- [ ] Le menu contextuel contient "Coller les foregrounds", toujours visible
- [ ] "Coller les foregrounds" est grisé si rien n'a été copié
- [ ] Le collage remplace les foregrounds de la séquence cible par des copies (nouveaux UUIDs)
- [ ] Le collage applique les foregrounds dialogue par dialogue (par index)
- [ ] Les dialogues cibles au-delà du nombre de dialogues source ne sont pas modifiés
- [ ] Toutes les propriétés foreground sont conservées (image, position, scale, flip, opacity, z_order, transitions)
- [ ] Les propriétés non-foreground de la séquence cible ne sont pas modifiées
- [ ] L'histoire est marquée comme modifiée après le collage
- [ ] Le clipboard persiste lors de la navigation entre scènes
