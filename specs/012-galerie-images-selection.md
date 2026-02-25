# Galerie d'images pour la sélection de backgrounds et foregrounds

## Résumé

Les boutons "Importer background", "+ Foreground" et "Choisir..." (image source dans le dialog IA) ouvrent désormais un dialog unifié avec deux onglets : **Fichier** (FileDialog système) et **Galerie** (vignettes des images déjà présentes dans les assets de l'histoire). L'objectif est de permettre une réutilisation rapide des images existantes tout en rendant l'histoire autonome en centralisant ses assets.

## Comportement attendu

### Dialog d'image picker (`ImagePickerDialog`)

Un `Window` centrée de taille 900×600 px, avec :
- Un titre dynamique : "Sélectionner un background" ou "Sélectionner un foreground"
- Deux onglets : **Fichier** et **Galerie**
- Un bouton "Valider" (désactivé tant qu'aucune image n'est sélectionnée) et "Annuler"

Ce dialog remplace les appels directs à `FileDialog` dans `main.gd` pour les boutons "Importer background" et "+ Foreground", et dans `ai_generate_dialog.gd` pour le bouton "Choisir..." (image source).

### Onglet Fichier

- Affiche un `FileDialog` embarqué (ou équivalent) permettant de naviguer dans le système de fichiers
- Filtres : `*.png`, `*.jpg`, `*.jpeg`, `*.webp`
- Lorsqu'un fichier est sélectionné dans cet onglet, l'image est **copiée** automatiquement dans le répertoire assets de l'histoire :
  - Background → `user://stories/{story_name}/assets/backgrounds/{nom_fichier}`
  - Foreground → `user://stories/{story_name}/assets/foregrounds/{nom_fichier}`
  - Si un fichier du même nom existe déjà, le fichier copié obtient un suffixe `_{index}` (ex : `image_1.png`)
- Le chemin utilisé est le chemin copié dans assets/, pas le chemin source
- La sélection est activée dès qu'un fichier est choisi dans le FileDialog

### Onglet Galerie

- Liste les fichiers image (`.png`, `.jpg`, `.jpeg`, `.webp`) présents dans :
  - Background : `user://stories/{story_name}/assets/backgrounds/`
  - Foreground : `user://stories/{story_name}/assets/foregrounds/`
- Affiche les images sous forme de **vignettes** dans une grille (taille vignette : 128×128 px, avec le nom du fichier tronqué en dessous)
- **État vide** : si le répertoire ne contient aucune image, afficher un label centré "Aucune image disponible. Importez d'abord une image via l'onglet Fichier."
- Cliquer sur une vignette la sélectionne (mise en surbrillance visuelle), active le bouton "Valider"
- Le chemin utilisé est le chemin complet `user://stories/…/assets/…/{nom_fichier}` tel quel

### Confirmation et signal

- Le bouton "Valider" est désactivé (`disabled = true`) tant qu'aucune image n'est sélectionnée dans l'onglet actif
- Appuyer sur "Valider" émet le signal `image_selected(path: String)` et ferme le dialog
- Appuyer sur "Annuler" ferme le dialog sans émettre de signal
- Fermer la fenêtre (croix) équivaut à "Annuler"

### Intégration dans `main.gd`

- `_on_import_bg_pressed()` : ouvre le dialog en mode background avec le story_name courant
- `_on_add_foreground_pressed()` : ouvre le dialog en mode foreground avec le story_name courant
- Sur réception de `image_selected(path)` : comportement identique à l'actuel (`_on_bg_file_selected` / `_on_fg_file_selected`)

### Intégration dans `ai_generate_dialog.gd`

- Le bouton "Choisir..." (`_choose_source_btn`) ouvre le dialog en mode foreground avec le story_name courant
- La galerie affiche les images de `user://stories/{story_name}/assets/foregrounds/`
- L'image source sélectionnée n'est **pas** copiée (elle est déjà dans les assets ou copiée par le dialog si choisie depuis l'onglet Fichier)
- Sur réception de `image_selected(path)` : met à jour `_source_image_path` et `_source_path_label`

## Critères d'acceptation

- [x] Cliquer sur "Importer background" ouvre le dialog `ImagePickerDialog` avec le titre "Sélectionner un background"
- [x] Cliquer sur "+ Foreground" ouvre le dialog `ImagePickerDialog` avec le titre "Sélectionner un foreground"
- [x] L'onglet "Fichier" permet de naviguer dans le système de fichiers et de sélectionner une image PNG/JPG/JPEG/WEBP
- [x] Sélectionner un fichier via l'onglet "Fichier" copie l'image dans `user://stories/{story_name}/assets/backgrounds/` (background) ou `assets/foregrounds/` (foreground)
- [x] Si un fichier du même nom existe dans assets/, le fichier copié est renommé avec un suffixe `_{index}`
- [x] Le chemin transmis au jeu est le chemin dans assets/, pas le chemin source
- [x] L'onglet "Galerie" affiche les vignettes (128×128 px) des images présentes dans le répertoire assets correspondant
- [x] L'onglet "Galerie" affiche "Aucune image disponible. Importez d'abord une image via l'onglet Fichier." quand le répertoire est vide
- [x] Cliquer sur une vignette dans la galerie la sélectionne visuellement
- [x] Le bouton "Valider" est désactivé tant qu'aucune image n'est sélectionnée
- [x] Valider une sélection depuis l'onglet "Galerie" applique le chemin existant sans copie supplémentaire
- [x] Valider depuis l'onglet "Fichier" applique le chemin copié dans assets/
- [x] "Annuler" ou fermer la fenêtre ne modifie pas le background/foreground courant
- [x] Le dialog fonctionne correctement lorsque `story_name` est vide ou que l'histoire n'a pas encore été sauvegardée (afficher un message d'erreur ou désactiver les onglets concernés)
- [x] Le bouton "Choisir..." dans `ai_generate_dialog.gd` ouvre le `ImagePickerDialog` en mode foreground
- [x] Sélectionner une image via "Choisir..." met à jour l'image source dans le dialog IA (label + preview)
