# 029 — Prévisualisation plein écran des images

## Contexte

Les vignettes 128x128 de la galerie et les aperçus 200x200 / 64x64 de l'onglet IA ne permettent pas d'apprécier le détail des images. L'utilisateur doit pouvoir cliquer sur une image pour la voir en entier avant de la sélectionner ou l'accepter.

## Critères d'acceptation

1. Un composant réutilisable `ImagePreviewPopup` (`src/ui/shared/image_preview_popup.gd`) permet d'afficher une image en plein écran par-dessus l'interface :
   - Extends `Control`, anchors `PRESET_FULL_RECT`
   - `ColorRect` noir semi-transparent (alpha 0.7) en fond
   - `TextureRect` centré avec marges, `STRETCH_KEEP_ASPECT_CENTERED`
   - `Label` nom de fichier en bas (optionnel)
   - `Button` "✕" en haut à droite
   - Fermeture par clic sur l'overlay, touche Escape, ou bouton ✕
   - Méthode publique `show_preview(texture, filename)` — ignore les textures null
2. Dans `ImagePickerDialog`, un **double-clic** sur une vignette de la galerie ouvre la prévisualisation plein écran (le simple clic continue de sélectionner).
3. Dans `ImagePickerDialog`, un **simple clic** sur l'aperçu du résultat IA ouvre la prévisualisation.
4. Dans `ImagePickerDialog`, un **simple clic** sur l'aperçu de la source IA ouvre la prévisualisation.
5. Les prévisualisations de la galerie chargent l'image en pleine résolution (pas la vignette).
6. Tests couvrant :
   - Structure UI du composant (overlay, image, label, bouton)
   - `show_preview` rend visible et affiche la texture
   - `show_preview` avec texture null ne s'ouvre pas
   - Fermeture par `_close()`
   - Nom de fichier affiché dans le label
   - Intégration : `ImagePickerDialog` possède une instance `_image_preview`
   - Intégration : double-clic galerie appelle la prévisualisation
   - Intégration : clic sur l'aperçu résultat IA appelle la prévisualisation
   - Intégration : clic sur l'aperçu source IA appelle la prévisualisation
