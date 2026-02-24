# Éditeur de séquence

## Résumé

L'éditeur de séquence est la vue détaillée qui s'ouvre quand on double-clique sur une séquence dans le graphe de scène. Il permet de composer visuellement une séquence de visual novel : importer un background, placer des foregrounds (personnages/objets), rédiger les dialogues et prévisualiser le rendu en mode Play. Le layout est divisé en deux zones : preview visuelle à gauche, liste des dialogues à droite.

## Modèle de données

### Modifications du modèle Dialogue

Le modèle `Dialogue` est enrichi avec :
- `foregrounds: Array[Foreground]` — liste des foregrounds spécifiques à ce dialogue. Si vide, on hérite des foregrounds du dialogue précédent.
- Un UUID pour identifier chaque dialogue de manière unique.

### Transition sur Foreground

Le modèle `Foreground` est enrichi avec :
- `transition_type: String` — type de transition : `"none"` (instantané), `"fade"` (fondu en opacité), `"crossfade"` (transition croisée). Valeur par défaut : `"none"`.
- `transition_duration: float` — durée de la transition en secondes (ex: 0.5). Valeur par défaut : `0.5`. Utilisé uniquement si `transition_type != "none"`.

### Héritage des foregrounds

Quand un dialogue n'a pas de foregrounds propres (`foregrounds` vide), il hérite de l'état visuel du dialogue précédent le plus proche qui a des foregrounds définis. Le premier dialogue sans foreground affiche un écran vide (background seul).

Quand l'utilisateur modifie un foreground hérité sur un dialogue, **tous** les foregrounds hérités sont copiés sur ce dialogue (copie complète). Le dialogue possède alors sa propre liste indépendante.

## Comportement attendu

### Layout général

- **Zone gauche (≈65%)** : preview visuelle affichant le background et les foregrounds du dialogue sélectionné.
- **Zone droite (≈35%)** : panel de gestion des dialogues avec la liste scrollable.
- **Barre d'outils en haut** : bouton d'import background, bouton Play/Stop.

### Import du background

- Un bouton "Importer background" dans la barre d'outils ouvre un sélecteur de fichier (formats : PNG, JPG, JPEG, WEBP).
- L'image sélectionnée est définie comme `Sequence.background`.
- Le background est unique pour toute la séquence.
- La preview affiche le background redimensionné pour remplir la zone de preview (en conservant le ratio).

### Gestion des dialogues (panel droit)

- La liste affiche chaque dialogue avec : le nom du personnage et un aperçu tronqué du texte.
- **Ajouter** : un bouton "+" en bas de la liste crée un nouveau dialogue vide à la fin.
- **Supprimer** : chaque dialogue a un bouton de suppression (icône corbeille). Confirmation demandée avant suppression.
- **Déplacer** : drag & drop dans la liste pour réordonner les dialogues.
- **Sélection** : cliquer sur un dialogue le sélectionne (surligné visuellement) et met à jour la preview.
- **Édition** : les champs `character` et `text` sont éditables directement dans le panel (champ texte inline ou via un formulaire dans l'item de liste).

### Preview visuelle (zone gauche)

- Affiche le rendu du dialogue sélectionné : background + foregrounds effectifs (propres ou hérités).
- Les foregrounds hérités sont affichés normalement (pas de distinction visuelle avec les foregrounds propres en mode preview).
- **Ajout de foreground** : un bouton "Ajouter foreground" permet d'importer une image et de la placer sur la preview. Si le dialogue hérite ses foregrounds, une copie complète est créée avant l'ajout.
- **Déplacement** : cliquer-glisser un foreground pour le repositionner sur la preview.
- **Redimensionnement** : poignées de redimensionnement sur le foreground sélectionné.
- **Suppression** : sélectionner un foreground puis le supprimer (touche Suppr ou bouton).
- **Propriétés de transition** : quand un foreground est sélectionné, un mini-panel affiche les options de transition (type : aucune/fondu/crossfade, durée en secondes).

### Mode Play

- Le bouton "Play" dans la barre d'outils active le mode Play.
- Le mode Play se positionne automatiquement au premier dialogue.
- La preview affiche le rendu visuel (background + foregrounds) en plein zone de preview.
- Une boîte de dialogue style visual novel s'affiche en bas de la preview avec :
  - Le nom du personnage (en haut de la boîte, stylisé).
  - Le texte qui s'affiche lettre par lettre (effet typewriter).
- **Barre d'espace** :
  - Si le texte est en cours d'affichage → affiche tout le texte d'un coup.
  - Si le texte est entièrement affiché → passe au dialogue suivant (avec transitions de foregrounds si applicable).
- Les transitions de foregrounds sont jouées entre deux dialogues quand les foregrounds changent.
- Arrivé au dernier dialogue et après affichage complet du texte, une pression sur espace arrête automatiquement le mode Play et revient au mode édition.
- Un bouton "Stop" permet de quitter le mode Play à tout moment.
- En mode Play, la liste des dialogues à droite reste visible et met en surbrillance le dialogue courant.

## Critères d'acceptation

### Modèle de données
- [x] Le modèle `Dialogue` possède un champ `foregrounds: Array[Foreground]` et un `uuid: String`
- [x] Le modèle `Foreground` possède les champs `transition_type: String` et `transition_duration: float`
- [x] `transition_type` accepte les valeurs `"none"`, `"fade"`, `"crossfade"` (défaut : `"none"`)
- [x] `transition_duration` a une valeur par défaut de `0.5` et est clampée entre `0.1` et `5.0`
- [x] La sérialisation/désérialisation YAML de `Dialogue` et `Foreground` inclut les nouveaux champs

### Layout
- [x] L'éditeur de séquence affiche une zone de preview à gauche et un panel de dialogues à droite
- [x] Une barre d'outils en haut contient le bouton d'import background et le bouton Play/Stop

### Background
- [x] Le bouton "Importer background" ouvre un sélecteur de fichier filtré sur les images (PNG, JPG, JPEG, WEBP)
- [x] L'image sélectionnée est assignée à `Sequence.background` et affichée dans la preview
- [x] Le background conserve son ratio d'aspect dans la preview

### Dialogues
- [x] La liste des dialogues affiche le personnage et un aperçu du texte pour chaque dialogue
- [x] On peut ajouter un dialogue via le bouton "+"
- [x] On peut supprimer un dialogue avec confirmation
- [x] On peut réordonner les dialogues par drag & drop
- [x] On peut éditer le personnage et le texte d'un dialogue directement dans le panel
- [x] Cliquer sur un dialogue le sélectionne et met à jour la preview

### Foregrounds et héritage
- [x] Un dialogue sans foregrounds propres affiche les foregrounds du dialogue précédent le plus proche qui en possède
- [x] Le premier dialogue sans foreground affiche uniquement le background
- [x] On peut ajouter un foreground via un bouton qui ouvre un sélecteur de fichier image
- [x] Modifier un foreground hérité crée une copie complète de tous les foregrounds sur le dialogue courant
- [x] On peut déplacer un foreground par cliquer-glisser dans la preview
- [x] On peut redimensionner un foreground via des poignées
- [x] On peut supprimer un foreground sélectionné
- [x] On peut configurer la transition d'un foreground (type et durée) via un mini-panel de propriétés

### Mode Play
- [x] Le bouton Play démarre la lecture au premier dialogue
- [x] La preview affiche le background et les foregrounds du dialogue courant
- [x] Une boîte de dialogue style visual novel affiche le nom du personnage et le texte
- [x] Le texte s'affiche avec un effet typewriter (lettre par lettre)
- [x] Espace pendant l'animation : affiche tout le texte d'un coup
- [x] Espace après affichage complet : passe au dialogue suivant
- [x] Les transitions de foregrounds (fade/crossfade) sont jouées entre les dialogues
- [x] Après le dernier dialogue, espace arrête le mode Play et revient à l'édition
- [x] Le bouton Stop quitte le mode Play à tout moment
- [x] La liste des dialogues met en surbrillance le dialogue courant pendant le Play
