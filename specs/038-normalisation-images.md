# Normalisation d'images de la galerie

## Résumé

L'utilisateur peut sélectionner plusieurs images dans la galerie, choisir une image de référence, puis normaliser toutes les autres images pour qu'elles aient la même balance des blancs, luminosité et contraste que la référence. Un aperçu avant/après est présenté via des fichiers temporaires avant de valider le remplacement des originaux.

## Comportement attendu

### Déclenchement

- Un bouton **"Normaliser les images"** est présent dans la barre du bas de `GalleryDialog`, entre le bouton "Nettoyer la galerie" et le spacer.
- Le bouton est désactivé tant qu'il y a moins de 2 images dans la galerie.
- Cliquer sur ce bouton ouvre un `ImageNormalizerDialog`.

### Phase 1 — Sélection des images

- Le dialog affiche toutes les images de la galerie (backgrounds + foregrounds) dans une grille à 4 colonnes.
- Chaque thumbnail (96×96 px) est accompagné d'une CheckBox et du nom du fichier.
- L'utilisateur coche les images qu'il souhaite normaliser ensemble.
- Boutons "Tout sélectionner" et "Tout désélectionner" pour les actions groupées.
- Un label affiche le nombre d'images sélectionnées : "X image(s) sélectionnée(s)".
- Le bouton **"Suivant →"** est activé uniquement quand ≥ 2 images sont sélectionnées.

### Phase 2 — Choix de l'image de référence

- Seules les images sélectionnées sont affichées dans une grille.
- L'utilisateur clique sur une image pour la désigner comme référence.
- L'image de référence est visuellement mise en évidence (bordure colorée, tint `Color(0.5, 0.8, 1.0)`).
- Un label indique : "Cliquez sur l'image de référence".
- Le bouton **"Normaliser"** est activé uniquement quand une référence est choisie.

### Phase 3 — Aperçu avant/après

- Le service `ImageNormalizerService` analyse les images et normalise chaque image non-référence vers les valeurs de l'image de référence.
- Les images normalisées sont sauvegardées dans un dossier temporaire : `{story_base_path}/assets/.normalizer_temp/`.
- Le dialog affiche une grille à 2 colonnes : "Avant" | "Après" pour chaque image.
- L'image de référence est marquée "(référence — non modifiée)".
- Bouton **"Appliquer"** : remplace les originaux par les fichiers normalisés, ferme le dialog.
- Bouton **"Retour"** : supprime les fichiers temporaires, revient à la phase 1.

### Service ImageNormalizerService

Service `RefCounted` avec méthodes statiques pour le traitement d'image. Utilise `PackedByteArray` via `Image.get_data()` pour la performance.

#### Analyse d'image

- `analyze_image(path: String) -> Dictionary` : charge l'image, la redimensionne à max 512×512 pour l'analyse, calcule les statistiques :
  - `mean_r`, `mean_g`, `mean_b` : moyenne de chaque canal (valeurs 0.0 à 1.0)
  - `mean_luminance` : luminance moyenne (Rec.601 : `0.299*R + 0.587*G + 0.114*B`)
  - `std_luminance` : écart-type de la luminance
  - `pixel_count` : nombre de pixels analysés

#### Normalisation

- `normalize_image(path, image_stats, reference_stats, output_path) -> bool` : applique la normalisation à l'image pleine résolution.
- Formule par canal (R, G, B) pour chaque pixel :
  ```
  contrast_factor = ref_std / max(image_std, 0.001)
  new_c = ref_mean_c + (pixel_c * ref_mean_c / max(image_mean_c, 0.001) - ref_mean_c) * contrast_factor
  final_c = clamp(new_c, 0.0, 1.0)
  ```
- Le canal alpha est préservé tel quel.
- Le format de sortie correspond au format d'entrée (PNG, JPG, WEBP).

#### Utilitaires

- `cleanup_temp_dir(temp_dir_path: String) -> void` : supprime tous les fichiers temporaires et le dossier.
- `apply_normalized_images(mappings: Array) -> int` : chaque mapping = `{"original": path, "temp": path}`. Remplace les fichiers originaux. Retourne le nombre de remplacements réussis.
- `get_temp_path(original_path: String, temp_dir: String, prefix: String) -> String` : retourne `temp_dir/prefix_filename`.

### Gestion des fichiers temporaires

- Dossier : `{story_base_path}/assets/.normalizer_temp/`
- Préfixe `bg_` pour les backgrounds, `fg_` pour les foregrounds (évite les collisions de noms).
- Le dossier est supprimé systématiquement : à la fermeture du dialog, au retour de la phase 3, ou à l'annulation.

## Fichiers impactés

| Fichier | Action |
|---|---|
| `src/services/image_normalizer_service.gd` | Nouveau |
| `src/ui/dialogs/image_normalizer_dialog.gd` | Nouveau |
| `src/ui/dialogs/gallery_dialog.gd` | Modifié |
| `specs/services/test_image_normalizer_service.gd` | Nouveau |
| `specs/ui/dialogs/test_image_normalizer_dialog.gd` | Nouveau |
| `specs/ui/dialogs/test_gallery_dialog.gd` | Modifié |

## Critères d'acceptation

- [ ] Un bouton "Normaliser les images" est visible dans la barre du bas de `GalleryDialog`.
- [ ] Le bouton est désactivé quand il y a moins de 2 images dans la galerie.
- [ ] Le bouton ouvre un `ImageNormalizerDialog` (Window, 1000×700, exclusive).
- [ ] Phase 1 : toutes les images de la galerie sont affichées avec des checkboxes.
- [ ] Phase 1 : les boutons "Tout sélectionner" / "Tout désélectionner" fonctionnent.
- [ ] Phase 1 : le label compteur affiche le bon nombre d'images sélectionnées.
- [ ] Phase 1 : le bouton "Suivant →" est désactivé quand < 2 images sont sélectionnées.
- [ ] Phase 2 : seules les images sélectionnées sont affichées.
- [ ] Phase 2 : cliquer sur une image la désigne comme référence avec un retour visuel.
- [ ] Phase 2 : le bouton "Normaliser" est désactivé tant qu'aucune référence n'est choisie.
- [ ] Phase 3 : les images normalisées sont sauvegardées dans des fichiers temporaires.
- [ ] Phase 3 : l'aperçu avant/après est affiché pour chaque image.
- [ ] Phase 3 : l'image de référence est marquée comme non modifiée.
- [ ] Phase 3 : "Appliquer" remplace les originaux et ferme le dialog.
- [ ] Phase 3 : "Retour" supprime les fichiers temporaires et revient à la phase 1.
- [ ] `ImageNormalizerService.analyze_image()` calcule les statistiques correctement.
- [ ] `ImageNormalizerService.normalize_image()` ajuste la balance des blancs, la luminosité et le contraste.
- [ ] La normalisation préserve le canal alpha.
- [ ] La normalisation préserve le format de fichier d'origine (PNG, JPG, WEBP).
- [ ] Les fichiers temporaires sont nettoyés à la fermeture du dialog.
- [ ] Le signal `normalization_applied` déclenche un rafraîchissement de la galerie.
