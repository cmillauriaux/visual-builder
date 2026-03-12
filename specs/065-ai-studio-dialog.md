# 065 — Studio IA (AI Studio Dialog)

## Résumé

Nouveau dialogue "Studio IA" accessible depuis le menu Paramètres de l'éditeur, offrant deux onglets :
- **Décliner** : génération d'images IA unitaire (même workflow que l'onglet IA existant dans ImagePickerDialog)
- **Expressions** : génération par lots de combinaisons pose × expression faciale avec le workflow Expression

## Contexte / Motivation

L'onglet IA existant dans `ImagePickerDialog` est conçu pour sélectionner **une seule image** à intégrer dans une séquence. Les créateurs de visual novels ont besoin d'un outil de production avancé pour générer en lot toutes les variantes d'expression d'un personnage (combinaisons pose × expression). Le Studio IA centralise ces fonctionnalités dans un dialogue dédié.

## Spécification

### Point d'entrée

- Nouvel item **"Studio IA"** (id 5) dans le menu déroulant **Paramètres** de la barre supérieure de l'éditeur
- Placé après "Notifications" et avant le séparateur "Langues"
- Nécessite qu'une histoire soit chargée (comme les autres items du menu)

### Structure générale du dialogue

```
Window (1100×700, exclusive, titre "Studio IA")
  MarginContainer (12px)
    VBoxContainer
      Label "URL ComfyUI :" + LineEdit (partagé)
      Label "Token :" + LineEdit secret (partagé)
      HSeparator
      TabContainer
        [Tab 0 : "Décliner"]
        [Tab 1 : "Expressions"]
      HSeparator
      HBoxContainer → Button "Fermer"
    ImagePreviewPopup (overlay pour zoom)
```

L'URL et le token ComfyUI sont partagés entre les deux onglets et placés au-dessus du TabContainer.

### Onglet "Décliner"

Réplique l'onglet IA de `ImagePickerDialog` :

- **Workflow** : OptionButton (Création / Expression)
- **Image source** : TextureRect preview + boutons "Parcourir..." et "Galerie..."
- **Prompt** : TextEdit (min 60px hauteur)
- **CFG** : HSlider (1.0–30.0, step 0.5, défaut 1.0)
- **Steps** : HSlider (1–50, step 1, défaut 4)
- **Générer** : bouton, désactivé tant que URL + source + prompt ne sont pas renseignés
- **Résultat** : TextureRect preview + label statut + barre de progression
- **Nom** : LineEdit pour nommer l'image
- **Sauvegarder** : enregistre dans `assets/foregrounds/` sans fermer le dialogue
- **Régénérer** : relance la génération avec les mêmes paramètres

### Onglet "Expressions"

#### Sélection de l'image source
- TextureRect preview + boutons "Parcourir..." et "Galerie..."
- Utilise toujours le workflow `WorkflowType.EXPRESSION`

#### Préfixe
- LineEdit pour le préfixe des noms de fichiers (ex: "personnage_nom")

#### CFG / Steps
- Mêmes sliders que l'onglet Décliner

#### Denoise
- HSlider (0.1–1.0, step 0.05, défaut 0.5)
- Contrôle la fidélité à l'image source (0.1 = peu de changement, 1.0 = régénération totale)

#### Zone visage (Face Box Size)
- HSlider (10–200, step 5, défaut 80)
- Contrôle la taille de la zone de détection du visage en pixels
- Affecte deux paramètres du workflow Expression :
  - `dilation` (noeud 100 / BboxDetectorCombined_v2) : expansion de la bounding box de détection
  - `expand` (noeud 101 / GrowMask) : expansion supplémentaire du masque
- Une valeur basse (ex: 20-40) limite la zone modifiée au visage seul, évitant de modifier les vêtements
- Une valeur haute (ex: 120-200) étend la zone modifiée au-delà du visage (cheveux, cou, épaules)
- Le paramètre `face_box_size` est passé via `comfyui_client.generate()` et `build_workflow()`

#### Expressions (cases à cocher, minimum 1)
- 30 expressions par défaut : smile, sad, shy, grumpy, laughing out loud, angry, surprised, worried, neutral, scared, disgusted, confused, proud, embarrassed, bored, excited, crying, hopeful, determined, jealous, dreamy, mischievous, exhausted, relieved, suspicious, tender, annoyed, desperate, nostalgic, seductive
- Expressions personnalisées : ajoutées dynamiquement via LineEdit + bouton "+ Ajouter"
- Chaque expression personnalisée a un bouton "✕" pour la supprimer
- Les expressions personnalisées sont persistées dans `ComfyUIConfig`

#### Génération par lots
- Le prompt est l'expression elle-même (ex: "smile")
- Le nom de fichier est : `"{prefix}_{expr_slug}.png"` (ex: "hero_smile.png")
- Les combinaisons sont traitées séquentiellement (une à la fois)
- Affichage du statut : "3/12 générés" + ProgressBar
- Bouton "Annuler" pour interrompre la génération en cours

#### Grille de résultats
- GridContainer avec 4 colonnes
- Chaque cellule : Panel avec TextureRect (128×128) + Label (nom du fichier)
- Indicateur de statut visuel par cellule (en attente / en cours / terminé / échoué)
- **Double-clic** : ouvre ImagePreviewPopup (zoom plein écran)
- **Clic droit** : PopupMenu avec "Régénérer" et "Supprimer"

#### Prévisualisation séquentielle
- Bouton **"Prévisualiser"** au-dessus de la grille de résultats (à côté du label "Résultats")
- Désactivé tant qu'aucune image n'est générée (completed count == 0)
- Ouvre ImagePreviewPopup en mode collection sur la première image complétée
- **Navigation** :
  - Boutons "◀ Précédent" et "Suivant ▶" dans la barre inférieure du popup
  - Touches clavier : Flèche gauche = précédent, Flèche droite = suivant
  - Compteur "N / Total" affiché entre les boutons de navigation
  - Les boutons Précédent/Suivant sont désactivés aux extrémités (premier/dernier)
- **Actions** :
  - Bouton "Regénérer" : relance la génération pour l'image courante, ferme le popup
  - Bouton "Supprimer" : supprime l'image courante de la queue, affiche l'image suivante ou ferme si plus d'images
- **Signaux** : `regenerate_requested(index)` et `delete_requested(index)` émis par ImagePreviewPopup

#### Validation
- Bouton **"Tout sauvegarder"** : enregistre toutes les images générées dans `assets/foregrounds/`
- Gestion des conflits de noms via `_resolve_unique_path`

### Service de file d'attente (ExpressionQueueService)

```
extends RefCounted

enum ItemStatus { PENDING, GENERATING, COMPLETED, FAILED }

Méthodes :
- build_queue(expressions, prefix) : construit la liste des expressions
- get_items() / get_total() : accès aux données
- get_next_pending_index() : prochaine tâche à traiter
- mark_generating(index) / mark_completed(index, image) / mark_failed(index, error)
- cancel() / is_cancelled()
- get_completed_items() : items terminés avec succès
- _build_prompt(pose, expression) → String
- _build_filename(prefix, pose, expression) → String
```

### Persistance des expressions personnalisées

Extension de `ComfyUIConfig` :
- Nouveau champ `_custom_expressions: PackedStringArray`
- Méthodes `get_custom_expressions()` / `set_custom_expressions()`
- Persisté dans la section `[expressions]` clé `custom` (valeurs séparées par virgule)

## Fichiers créés

| Fichier | Description |
|---------|-------------|
| `specs/065-ai-studio-dialog.md` | Cette spécification |
| `src/ui/dialogs/ai_studio_dialog.gd` | Dialog principal (extends Window) |
| `src/services/expression_queue_service.gd` | Service de file d'attente pour génération par lots |
| `specs/ui/dialogs/test_ai_studio_dialog.gd` | Tests du dialog |
| `specs/services/test_expression_queue_service.gd` | Tests du service de queue |

## Fichiers modifiés

| Fichier | Modification |
|---------|-------------|
| `src/controllers/main_ui_builder.gd` | Ajout item "Studio IA" (id 5) au menu Paramètres |
| `src/controllers/menu_controller.gd` | Ajout handler `on_ai_studio_pressed()` |
| `src/services/comfyui_config.gd` | Ajout stockage expressions personnalisées |

## Critères d'acceptation

- [ ] Le menu Paramètres contient l'item "Studio IA"
- [ ] Le dialogue s'ouvre avec deux onglets "Décliner" et "Expressions"
- [ ] L'URL et le token ComfyUI sont partagés entre les onglets
- [ ] L'onglet Décliner permet de générer et sauvegarder une image sans fermer le dialogue
- [ ] L'onglet Expressions affiche 30 expressions par défaut
- [ ] Les expressions personnalisées peuvent être ajoutées et supprimées
- [ ] Les expressions personnalisées sont persistées dans ComfyUIConfig
- [ ] Le bouton Générer nécessite : URL + source + préfixe + min 1 expression
- [ ] La génération par lots traite chaque combinaison séquentiellement
- [ ] La grille de résultats affiche l'état de chaque génération
- [ ] Double-clic sur un résultat ouvre la preview plein écran
- [ ] Clic droit permet de régénérer ou supprimer un résultat
- [ ] Le bouton "Prévisualiser" ouvre la navigation séquentielle des images
- [ ] La navigation par boutons et touches clavier fonctionne dans le popup
- [ ] Les boutons "Regénérer" et "Supprimer" dans le popup fonctionnent correctement
- [ ] "Tout sauvegarder" enregistre les images dans assets/foregrounds/
- [ ] Le bouton "Annuler" interrompt la génération en cours
- [ ] Tous les tests passent
