# Bouton Galerie sur la page principale

## Résumé

Ajouter un bouton "Galerie" dans la barre d'outils principale de l'éditeur, permettant de consulter toutes les images (backgrounds et foregrounds) de l'histoire courante et de nettoyer la galerie en supprimant les images non utilisées. Cela offre une vue d'ensemble des assets visuels et un outil de maintenance pour éviter l'accumulation de fichiers inutiles.

## Comportement attendu

### Bouton dans la top bar

- Un bouton "Galerie" est ajouté dans la top bar, entre le bouton "Menu" et le bouton "Vérifier".
- Le bouton est visible uniquement quand une histoire est ouverte (niveaux `chapters`, `scenes`, `sequences`), comme les boutons "Variables", "Menu", etc.
- Au clic, il ouvre le dialog de galerie.

### Dialog Galerie (GalleryDialog)

Le dialog est une `Window` modale (900x600 px), similaire à `ImagePickerDialog`.

#### Structure

- **Titre** : "Galerie — {nom de l'histoire}"
- **Deux sections** avec titres ("Backgrounds" et "Foregrounds"), chacune affichant une grille de vignettes 128x128 en 4 colonnes.
- Chaque vignette affiche :
  - L'image redimensionnée en vignette
  - Le nom du fichier en dessous
  - Les images **non utilisées** sont affichées avec une **opacité réduite à 50%** pour les distinguer visuellement
- **Double-clic** sur une vignette ouvre un aperçu plein écran via `ImagePreviewPopup`.
- Si une section est vide, afficher un message "Aucun background disponible." / "Aucun foreground disponible."

#### Bouton Nettoyer

- Un bouton "Nettoyer la galerie" est placé en bas du dialog.
- Au clic :
  1. L'application identifie toutes les images non utilisées par l'histoire.
  2. Un `ConfirmationDialog` s'affiche listant les fichiers à supprimer et leur taille totale (ex : "3 fichiers — 2.4 Mo").
  3. Sur confirmation, les fichiers sont supprimés du disque.
  4. La grille est rafraîchie pour refléter les suppressions.
- Si aucune image non utilisée n'est détectée, un `AcceptDialog` affiche "Toutes les images sont utilisées."
- Le bouton est désactivé si la galerie est vide.

### Détection des images utilisées

Une image est considérée comme "utilisée" si son chemin apparaît dans au moins un de ces champs du modèle Story chargé en mémoire :
- `story.menu_background`
- `sequence.background` (pour toute séquence de toute scène de tout chapitre)
- `foreground.image` dans `sequence.foregrounds[]`
- `foreground.image` dans `dialogue.foregrounds[]` (pour tout dialogue de toute séquence)

La comparaison se fait sur le chemin complet du fichier.

### Service GalleryCleanerService

Un service `src/services/gallery_cleaner_service.gd` encapsule la logique métier :
- `static func collect_used_images(story) -> Array[String]` — parcourt le modèle Story et retourne la liste de tous les chemins d'images utilisés.
- `static func find_unused_images(story_base_path: String, used_images: Array) -> Dictionary` — retourne `{"backgrounds": Array[String], "foregrounds": Array[String]}` des fichiers non utilisés.
- `static func calculate_total_size(file_paths: Array) -> int` — calcule la taille totale en octets des fichiers listés.
- `static func delete_files(file_paths: Array) -> int` — supprime les fichiers et retourne le nombre de fichiers effectivement supprimés.

### Fichiers

| Fichier | Action |
|---|---|
| `src/services/gallery_cleaner_service.gd` | Nouveau — service de détection et nettoyage |
| `src/ui/dialogs/gallery_dialog.gd` | Nouveau — dialog de consultation de galerie |
| `src/controllers/main_ui_builder.gd` | Modifié — ajout du bouton Galerie dans la top bar |
| `src/main.gd` | Modifié — variable `_gallery_button`, connexion du signal, méthode `_on_gallery_pressed()`, visibilité dans `update_view()` |

## Critères d'acceptation

- [x] Le bouton "Galerie" apparaît dans la top bar entre "Menu" et "Vérifier"
- [x] Le bouton est visible uniquement aux niveaux `chapters`, `scenes`, `sequences`
- [x] Le dialog affiche les backgrounds et foregrounds en deux sections séparées avec grille 4 colonnes
- [x] Les images non utilisées sont affichées avec une opacité réduite (50%)
- [x] Le double-clic sur une vignette ouvre un aperçu plein écran (ImagePreviewPopup)
- [x] Le bouton "Nettoyer" identifie correctement les images non utilisées en parcourant tout le modèle Story
- [x] Le bouton "Nettoyer" affiche une confirmation avec le nombre de fichiers et la taille totale avant suppression
- [x] Après confirmation, les fichiers non utilisés sont supprimés et la grille est rafraîchie
- [x] Si aucune image non utilisée, un message "Toutes les images sont utilisées." est affiché
- [x] Le service `GalleryCleanerService` est couvert par des tests unitaires
- [x] Le dialog `GalleryDialog` est couvert par des tests unitaires
