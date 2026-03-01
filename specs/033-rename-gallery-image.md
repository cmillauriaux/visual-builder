# Renommer une image depuis la galerie

## Résumé

L'utilisateur peut renommer un fichier image directement depuis la galerie ou depuis tout sélecteur d'image en faisant un clic droit et en choisissant "Renommer". Le fichier est physiquement renommé sur le disque et toutes les références dans le modèle de l'histoire sont mises à jour automatiquement.

## Comportement attendu

### Déclenchement

- Un clic droit sur une miniature d'image (dans `GalleryDialog` ou dans l'onglet Galerie de `ImagePickerDialog`) affiche un menu contextuel.
- L'option **"Renommer"** apparaît en première position du menu, suivie d'un séparateur puis des entrées de catégories existantes.

### Dialog de renommage

- Un `AcceptDialog` s'ouvre avec :
  - Un titre : "Renommer l'image"
  - Un champ `LineEdit` pré-rempli avec le nom de fichier **sans extension** (ex: `forest` pour `forest.png`).
  - Le texte est entièrement sélectionné à l'ouverture pour faciliter la saisie.
  - Un bouton **OK** et un bouton **Annuler**.
- L'extension originale est conservée automatiquement — elle n'est pas affichée ni modifiable.

### Validation et application

1. **Nom identique** : si le nouveau nom (sans extension) est identique à l'actuel, le dialog se ferme sans rien faire.
2. **Nom vide** : le bouton OK est désactivé tant que le champ est vide.
3. **Conflit de nom** : si un fichier avec le nouveau nom complet (`nom + extension`) existe déjà dans le même répertoire :
   - Un message d'erreur s'affiche dans le dialog (ex: "Ce nom est déjà utilisé.").
   - Le dialog reste ouvert, l'utilisateur doit choisir un autre nom.
4. **Renommage valide** :
   - Le fichier est renommé sur le disque (`DirAccess.rename()`).
   - Toutes les propriétés de l'histoire qui référencent l'ancien chemin sont mises à jour vers le nouveau chemin (parcours complet du modèle : `menu_background`, `sequence.background`, `foreground.image` dans séquences et dialogues).
   - L'histoire est marquée comme modifiée.
   - La grille est rechargée pour afficher le nouveau nom.

### Caractères autorisés

- Le nom ne peut contenir que des caractères alphanumériques, tirets (`-`), underscores (`_`) et points (`.`).
- Les espaces et les caractères spéciaux sont interdits. Un message d'erreur s'affiche si la saisie est invalide.

## Critères d'acceptation

- [x] Un clic droit sur une miniature dans `GalleryDialog` affiche un menu contextuel avec "Renommer" en première position.
- [x] Un clic droit sur une miniature dans l'onglet Galerie de `ImagePickerDialog` affiche le même menu contextuel avec "Renommer" en première position.
- [x] Cliquer sur "Renommer" ouvre un dialog avec un `LineEdit` pré-rempli du nom du fichier sans extension.
- [x] Le texte du `LineEdit` est entièrement sélectionné à l'ouverture du dialog.
- [x] Le bouton OK est désactivé si le champ `LineEdit` est vide.
- [x] Si le nouveau nom est identique à l'ancien, le dialog se ferme sans modifier de fichier.
- [x] Si un fichier avec le nouveau nom existe déjà dans le même répertoire, un message d'erreur s'affiche et le dialog reste ouvert.
- [x] Si le nom contient des caractères invalides, un message d'erreur s'affiche et le dialog reste ouvert.
- [x] Un renommage valide renomme physiquement le fichier sur le disque.
- [x] Toutes les références à l'ancien chemin dans le modèle de l'histoire sont mises à jour vers le nouveau chemin.
- [x] L'histoire est marquée comme modifiée après un renommage réussi.
- [x] La grille de la galerie est rechargée et affiche le nouveau nom après un renommage réussi.
- [x] Les assignations de catégories existantes pour l'image sont transférées au nouveau chemin.
