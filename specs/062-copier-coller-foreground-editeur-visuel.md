# Copier/Coller un foreground dans l'éditeur visuel

## Résumé

Permet de copier un ou plusieurs foregrounds via le menu contextuel (clic droit) dans l'éditeur visuel de séquence, puis de les coller comme nouveaux foregrounds dans la même séquence. Toutes les propriétés sont dupliquées (image, position, scale, flip, opacity, transitions, z_order) avec de nouveaux UUIDs. Supporte la multi-sélection avec SHIFT et le collage depuis le background.

## Comportement attendu

### Multi-sélection avec SHIFT

- Clic gauche sur un foreground → sélectionne uniquement ce foreground (remplace la sélection).
- SHIFT + clic gauche sur un foreground → ajoute/retire le foreground de la sélection courante (toggle).
- Clic gauche sur le background (espace vide) → désélectionne tout.
- Tous les foregrounds sélectionnés affichent une bordure de sélection.
- Le resize handle n'apparaît que quand un seul foreground est sélectionné.
- La touche Suppr supprime tous les foregrounds sélectionnés.

### Copier le(s) foreground(s)

- Clic droit sur un foreground → le menu contextuel affiche **"Copier le foreground"**.
- Si plusieurs foregrounds sont sélectionnés, la copie stocke **tous** les foregrounds sélectionnés.
- Si un seul foreground est ciblé (clic droit sans sélection multiple), seul celui-ci est copié.
- Toutes les propriétés de chaque foreground sont copiées : `fg_name`, `image`, `z_order`, `opacity`, `flip_h`, `flip_v`, `scale`, `anchor_bg`, `anchor_fg`, `transition_type`, `transition_duration`.

### Coller le(s) foreground(s)

- Clic droit sur un foreground **ou sur le background** → le menu contextuel affiche **"Coller le foreground"**.
- L'option est **toujours visible** mais **grisée** si aucun foreground n'a été copié.
- Au collage :
  - Un nouveau foreground est créé pour chaque foreground copié, avec un **nouveau UUID**.
  - Toutes les propriétés copiées sont appliquées.
  - Les nouveaux foregrounds sont ajoutés à la séquence courante.
  - Le visuel est immédiatement mis à jour.

### Menu contextuel sur le background

- Clic droit sur le background (espace vide) → un menu contextuel simplifié apparaît avec uniquement **"Coller le foreground"** (grisé si rien n'a été copié).

## Critères d'acceptation

### Copier/Coller (existant)

- [x] Le menu contextuel (clic droit sur foreground) contient "Copier le foreground"
- [x] "Copier le foreground" stocke toutes les propriétés du foreground ciblé
- [x] Le menu contextuel contient "Coller le foreground", toujours visible
- [x] "Coller le foreground" est grisé si rien n'a été copié
- [x] "Coller le foreground" crée un nouveau foreground avec un nouveau UUID
- [x] Toutes les propriétés sont conservées (image, fg_name, scale, flip_h, flip_v, opacity, z_order, anchor_bg, anchor_fg, transition_type, transition_duration)
- [x] Le nouveau foreground est ajouté à la séquence courante
- [x] Le visuel se met à jour immédiatement après le collage

### Multi-sélection SHIFT

- [x] SHIFT + clic gauche ajoute/retire un foreground de la sélection
- [x] Clic gauche sans SHIFT remplace la sélection
- [x] Tous les foregrounds sélectionnés affichent la bordure de sélection
- [x] Le resize handle n'apparaît que pour une sélection unique
- [x] Suppr supprime tous les foregrounds sélectionnés
- [x] Le signal `foreground_selected` émet le dernier foreground sélectionné

### Copier/Coller multi-sélection

- [x] "Copier le foreground" copie tous les foregrounds sélectionnés
- [x] "Coller le foreground" crée un nouveau foreground par foreground copié
- [x] Chaque foreground collé a un UUID unique

### Menu contextuel background

- [x] Clic droit sur le background affiche un menu contextuel
- [x] Ce menu contient uniquement "Coller le foreground"
- [x] "Coller le foreground" est grisé si le clipboard est vide
