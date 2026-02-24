# Éditeur de terminaison — UI Redirection et Choix

## Résumé

L'éditeur de terminaison permet de configurer comment une séquence se termine. Deux modes sont disponibles : **Redirection** (passage automatique vers une autre séquence/scène/chapitre ou fin) et **Choix** (le joueur choisit parmi plusieurs options). L'UI est intégrée dans le panneau dialogue (colonne droite de l'éditeur de séquence), sous le bouton "Ajouter un dialogue".

## Modèle de données

Aucune modification du modèle n'est nécessaire. Le modèle `Ending` existant supporte déjà :
- `type: String` — `"auto_redirect"` ou `"choices"`
- `auto_consequence: Consequence` — pour le mode redirection
- `choices: Array[Choice]` — pour le mode choix (1 à 8)

Le modèle `Consequence` possède :
- `type: String` — `"redirect_sequence"`, `"redirect_scene"`, `"redirect_chapter"`, `"game_over"`, `"to_be_continued"`
- `target: String` — UUID de la cible (vide pour game_over/to_be_continued)

## Comportement attendu

### Intégration dans le panneau dialogue

Sous le bouton "+ Ajouter un dialogue" :
1. Un séparateur visuel (label "— Terminaison —")
2. L'EndingEditor UI avec ses deux modes

### Mode selector

Deux boutons toggle mutuellement exclusifs :
- **"Redirection"** — active le mode `auto_redirect`
- **"Choix"** — active le mode `choices`
- Un bouton **"Aucune"** pour supprimer la terminaison

### Mode Redirection

Quand activé :
- Un `OptionButton` pour le type de conséquence : Séquence / Scène / Chapitre / Game Over / To be continued
- Un `OptionButton` pour la cible : liste dynamique des éléments disponibles (format "Nom"), masqué si type = game_over ou to_be_continued
- Un label résumé affichant la redirection configurée (ex: "→ Séquence 2")

### Mode Choix

Quand activé :
- Une liste scrollable des choix existants
- Chaque choix affiche :
  - `LineEdit` pour le texte du choix
  - `OptionButton` pour le type de conséquence
  - `OptionButton` pour la cible (masqué si game_over/to_be_continued)
  - Bouton "Supprimer" pour retirer le choix
- Un bouton "+ Ajouter un choix" en bas (maximum 8 choix)

### Signal flow

1. L'utilisateur modifie la terminaison dans EndingEditor
2. EndingEditor émet le signal `ending_changed`
3. `main.gd` reçoit le signal et recalcule les connexions dans les graphes

### Listes de cibles dynamiques

`main.gd` fournit les données via `set_available_targets(sequences, scenes, chapters)` :
- **Séquences** : depuis `_current_scene.sequences` → `[{uuid, name}]`
- **Scènes** : depuis `_current_chapter.scenes` → `[{uuid, name}]`
- **Chapitres** : depuis `_story.chapters` → `[{uuid, name}]`

### Connexions dans les graphes

Les connexions issues des terminaisons sont calculées dynamiquement lors du chargement d'une vue graphe :
- `redirect_sequence` → connexion dans `sequence_graph_view`
- `redirect_scene` → connexion dans `scene_graph_view`
- `redirect_chapter` → connexion dans `chapter_graph_view`

Approche : recalcul dynamique à chaque chargement de vue (pas de persistance séparée). On parcourt les endings de tous les éléments enfants pour déduire les connexions additionnelles.

## Critères d'acceptation

### UI EndingEditor
- [x] Un séparateur "— Terminaison —" est visible sous le bouton "Ajouter un dialogue"
- [x] Trois boutons toggle : "Aucune", "Redirection", "Choix"
- [x] Le mode "Aucune" est sélectionné par défaut quand la séquence n'a pas de terminaison
- [x] Changer de mode met à jour le modèle `Ending` de la séquence

### Mode Redirection
- [x] Un dropdown type affiche les 5 types de conséquence
- [x] Un dropdown cible affiche les éléments disponibles selon le type choisi
- [x] Le dropdown cible est masqué si type = game_over ou to_be_continued
- [x] Modifier type ou cible émet le signal `ending_changed`
- [x] Le modèle `auto_consequence` est correctement mis à jour

### Mode Choix
- [x] On peut ajouter un choix via le bouton "+ Ajouter un choix"
- [x] Maximum 8 choix (bouton désactivé au-delà)
- [x] Chaque choix a un champ texte, un dropdown type et un dropdown cible
- [x] Le dropdown cible d'un choix est masqué si type = game_over ou to_be_continued
- [x] On peut supprimer un choix
- [x] Modifier un choix émet le signal `ending_changed`

### Signal et intégration
- [x] Le signal `ending_changed` est émis à chaque modification de la terminaison
- [x] `main.gd` connecte le signal et recalcule les connexions
- [x] Les données de cibles disponibles sont passées à l'ending editor au chargement d'une séquence

### Connexions dans les graphes
- [x] Les connexions issues des endings de type `redirect_sequence` apparaissent dans le graphe de séquences
- [x] Les connexions issues des endings de type `redirect_scene` apparaissent dans le graphe de scènes
- [x] Les connexions issues des endings de type `redirect_chapter` apparaissent dans le graphe de chapitres
- [x] Les connexions dynamiques ne dupliquent pas les connexions manuelles existantes

### Persistance
- [x] Les endings sont sauvegardés/chargés correctement (déjà couvert par le modèle existant)
- [x] Au rechargement, l'UI reflète la terminaison existante de la séquence

### Tests
- [x] Tests unitaires pour le signal `ending_changed`
- [x] Tests unitaires pour `set_available_targets`
- [x] Tests unitaires pour le recalcul des connexions dans les graph views
- [x] Les tests existants du ending_editor continuent de passer
