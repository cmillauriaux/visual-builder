# 073 — Vue Map de la Story

## Contexte

L'éditeur navigue par niveaux hiérarchiques (chapitres → scènes → séquences), mais l'auteur n'a aucun moyen de voir la structure globale de son histoire en un seul coup d'œil. La vue Map comble ce besoin en affichant tous les éléments de la story dans une unique vue hiérarchique avec des boîtes imbriquées et des connexions.

## Objectif

Ajouter un bouton **"🗺 Map"** dans la barre supérieure de l'éditeur (à gauche du bouton Jouer) qui remplace la zone de contenu par une vue d'ensemble de toute la story. La vue affiche des chapitres (boîtes larges) contenant des scènes (boîtes moyennes), elles-mêmes contenant des séquences et conditions (nœuds). Des flèches représentent les connexions entre éléments. Cliquer sur un élément navigue directement vers lui.

## Spécification

### Bouton Map

- [ ] Un bouton "🗺 Map" est affiché dans la barre supérieure, à gauche du bouton "▶ Jouer"
- [ ] Le bouton est visible dès qu'une story est ouverte (tous les niveaux sauf NONE)
- [ ] Le bouton est en mode toggle : il reste enfoncé (button_pressed = true) quand la vue Map est active
- [ ] Cliquer le bouton quand la Map est déjà active ferme la Map et retourne au niveau précédent
- [ ] Cliquer le bouton depuis n'importe quel niveau (chapitres, scènes, séquences, édition) ouvre la Map

### Vue Map — affichage général

- [ ] La vue Map remplace la zone de contenu centrale (comme un niveau de navigation à part entière)
- [ ] La vue est zoomable via Ctrl+scroll (ou scroll seul) avec un zoom min de 0.2 et max de 3.0
- [ ] La vue est pannable par clic-milieu + glisser, ou clic-gauche + glisser sur zone vide
- [ ] La vue se redessine correctement à chaque changement de zoom ou de pan

### Chapitres

- [ ] Chaque chapitre est représenté par une boîte avec bordure colorée (couleur générée par index)
- [ ] Le nom du chapitre est affiché en en-tête de la boîte
- [ ] Les chapitres sont positionnés de gauche à droite selon leur ordre dans la story
- [ ] Un clic sur l'en-tête d'un chapitre navigue vers la vue scènes de ce chapitre

### Scènes

- [ ] Chaque scène est une boîte imbriquée à l'intérieur de la boîte chapitre
- [ ] Le nom de la scène est affiché en en-tête de la boîte scène
- [ ] Les scènes sont positionnées de gauche à droite à l'intérieur du chapitre
- [ ] Un clic sur l'en-tête d'une scène navigue vers la vue séquences de cette scène

### Séquences

- [ ] Chaque séquence est un nœud rectangulaire à l'intérieur de la boîte scène
- [ ] Le nom de la séquence est affiché dans le nœud
- [ ] Les séquences sont empilées verticalement à l'intérieur de la boîte scène
- [ ] Un clic sur une séquence navigue directement vers l'éditeur de séquence

### Conditions

- [ ] Chaque condition est un nœud distinct (forme ou couleur différente) dans la boîte scène
- [ ] Le nom de la condition est affiché dans le nœud
- [ ] Un clic sur une condition navigue directement vers l'éditeur de condition

### Connexions

- [ ] Les connexions entre chapitres (story.connections) sont dessinées comme des flèches
- [ ] Les connexions entre scènes dans un chapitre (chapter.connections) sont dessinées
- [ ] Les connexions entre séquences/conditions dans une scène (scene.connections) sont dessinées
- [ ] La couleur des flèches correspond au type de connexion (transition=bleu, choix=vert, both=jaune)

### Navigation depuis la Map

- [ ] Cliquer sur une séquence quitte la Map et ouvre l'éditeur de séquence pour cet élément
- [ ] Cliquer sur une condition quitte la Map et ouvre l'éditeur de condition pour cet élément
- [ ] Cliquer sur l'en-tête d'une scène quitte la Map et ouvre la vue séquences de cette scène
- [ ] Cliquer sur l'en-tête d'un chapitre quitte la Map et ouvre la vue scènes de ce chapitre
- [ ] Le bouton "← Retour" dans la barre supérieure ferme la Map et retourne au niveau précédent

### État EditorState

- [ ] Un mode `MAP_VIEW` est ajouté à l'enum `EditorState.Mode`
- [ ] Le mode MAP_VIEW est activé quand `_current_level == "map"` dans `editor_main`
- [ ] Le mode MAP_VIEW est correctement géré dans `ui_controller._on_editor_mode_changed()`

## Fichiers concernés

- **Nouveaux** : `src/views/story_map_view.gd`, `specs/views/test_story_map_view.gd`
- **Modifiés** : `src/controllers/editor_state.gd`, `src/ui/editors/editor_main.gd`, `src/controllers/navigation_controller.gd`, `src/controllers/main_ui_builder.gd`, `src/main.gd`, `src/controllers/ui_controller.gd`

## Critères de non-régression

- Les tests existants passent toujours après l'implémentation
- La navigation normale (chapitres → scènes → séquences) n'est pas affectée
- Le bouton Jouer fonctionne toujours normalement depuis tous les niveaux
