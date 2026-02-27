# Onglets dans l'éditeur de séquence

## Résumé

Le panneau droit de l'éditeur de séquence empile actuellement les dialogues et la terminaison dans un seul VBoxContainer. Cette spec introduit un `TabContainer` pour séparer ces sections en onglets distincts (Dialogues, Terminaison) et préparer l'ajout futur d'onglets supplémentaires (Musique, FX).

## Comportement attendu

### Structure des onglets

Le panneau droit (`_dialogue_panel`) est remplacé par un `TabContainer` contenant 4 onglets :

1. **Dialogues** — contient le ScrollContainer avec la liste des dialogues (`dialogue_list_panel`) et le bouton "+ Ajouter un dialogue"
2. **Terminaison** — contient l'`ending_editor` existant
3. **Musique** — placeholder avec un `Label` centré "À venir"
4. **FX** — placeholder avec un `Label` centré "À venir"

### Comportement de sélection

- À chaque ouverture/changement de séquence, l'onglet **Dialogues** est sélectionné par défaut (onglet index 0).
- Le changement d'onglet n'affecte pas les données : chaque onglet conserve son état interne.

### Indicateur visuel sur l'onglet Terminaison

- Quand une terminaison est configurée (ending != null), le titre de l'onglet affiche **"Terminaison ●"** (avec un caractère Unicode pastille `●`).
- Quand aucune terminaison n'est définie (ending == null), le titre affiche simplement **"Terminaison"**.
- L'indicateur est mis à jour à chaque changement de terminaison (signal `ending_changed`) et au chargement d'une séquence.

### Intégration avec l'existant

- Les scripts `dialogue_list_panel.gd` et `ending_editor.gd` ne sont pas modifiés. Seul `main.gd` change la hiérarchie des nœuds.
- Les signaux existants (`dialogue_delete_requested`, `ending_changed`, `dialogue_selected`) restent inchangés.
- Les tests existants accédant à ces composants via les références de `main.gd` continuent de fonctionner car les variables membres (`_dialogue_list_container`, `_ending_editor`) pointent toujours vers les mêmes objets.

## Critères d'acceptation

- [x] Le panneau droit de l'éditeur de séquence utilise un `TabContainer` avec 4 onglets visibles : "Dialogues", "Terminaison", "Musique", "FX"
- [x] L'onglet "Dialogues" contient la liste des dialogues scrollable et le bouton "+ Ajouter un dialogue"
- [x] L'onglet "Terminaison" contient l'`ending_editor` existant avec tout son comportement (modes, choix, redirections, effets)
- [x] Les onglets "Musique" et "FX" affichent un label centré "À venir"
- [x] À l'ouverture d'une séquence, l'onglet "Dialogues" est toujours sélectionné par défaut
- [x] Le titre de l'onglet "Terminaison" affiche "Terminaison ●" quand une terminaison est configurée
- [x] Le titre de l'onglet "Terminaison" affiche "Terminaison" quand aucune terminaison n'est définie
- [x] L'indicateur se met à jour dynamiquement lors de la modification de la terminaison
- [x] Les fonctionnalités existantes (ajout/suppression de dialogues, drag & drop, édition de terminaison) restent fonctionnelles
- [x] Les tests existants passent sans modification
