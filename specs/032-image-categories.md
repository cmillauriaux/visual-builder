# 032 — Catégories d'images pour la galerie

## Résumé

Les images de la galerie (backgrounds et foregrounds) peuvent être organisées en catégories. L'utilisateur peut affecter une image à une ou plusieurs catégories via un clic droit, filtrer l'affichage par catégorie, et gérer les catégories (ajout, renommage, suppression) via un dialog dédié.

## Catégories par défaut

- "Base"
- "NPC"
- "Character"

## Persistance

Fichier `{story_base_path}/assets/categories.yaml` au format :

```yaml
categories:
  - "Base"
  - "NPC"
  - "Character"
assignments:
  - image: "backgrounds/forest.png"
    categories:
      - "Base"
  - image: "foregrounds/hero.png"
    categories:
      - "Character"
      - "NPC"
```

Les clés d'image incluent le sous-dossier (`backgrounds/` ou `foregrounds/`) pour éviter les collisions de noms.

## Service : ImageCategoryService

Fichier : `src/services/image_category_service.gd` (extends `RefCounted`)

### Propriétés internes

- `_categories: Array` — liste ordonnée des catégories (défaut : `["Base", "NPC", "Character"]`)
- `_assignments: Dictionary` — clé = chemin relatif de l'image (ex: `"backgrounds/forest.png"`), valeur = `Array` de noms de catégories

### Méthodes CRUD catégories

- `get_categories() -> Array` — retourne la liste des catégories
- `add_category(name: String) -> void` — ajoute une catégorie (ignore les doublons)
- `rename_category(old_name: String, new_name: String) -> void` — renomme une catégorie (met à jour les assignments)
- `remove_category(name: String) -> void` — supprime une catégorie (retire des assignments)

### Méthodes d'assignation

- `assign_image_to_category(image_key: String, category: String) -> void`
- `unassign_image_from_category(image_key: String, category: String) -> void`
- `is_image_in_category(image_key: String, category: String) -> bool`
- `get_image_categories(image_key: String) -> Array`

### Méthodes de filtrage

- `filter_paths_by_category(paths: Array, category: String) -> Array` — filtre les chemins absolus par catégorie en extrayant la clé relative

### Persistance

- `save_to(base_path: String) -> void` — sauvegarde dans `{base_path}/assets/categories.yaml`
- `load_from(base_path: String) -> void` — charge depuis le fichier ; si absent, utilise les défauts

### Signal

- `categories_changed` — émis lors de toute modification de catégorie

## Dialog : CategoryManagerDialog

Fichier : `src/ui/dialogs/category_manager_dialog.gd` (extends `Window`)

### Comportement

- Window modale pour gérer les catégories
- `ItemList` affichant toutes les catégories
- Bouton "Ajouter" avec un `LineEdit` pour le nom
- Bouton "Renommer" (ouvre un dialog de saisie)
- Bouton "Supprimer" (confirmation si des images sont assignées)
- Bouton "Fermer"
- Méthode `setup(service: RefCounted)` pour initialiser avec le service
- Signal `categories_changed` émis après modification

## Modifications : GalleryDialog

- Charger `ImageCategoryService` dans `setup()`
- **Clic droit** sur un item → `PopupMenu` avec catégories en mode check + option "Gérer les catégories..."
- **Filtre par catégorie** : `OptionButton` ("Toutes" + liste des catégories) au-dessus du scroll
- `_refresh()` filtre via le service si un filtre est actif
- Sauvegarder le service après chaque modification

## Modifications : ImagePickerDialog

- Charger `ImageCategoryService` dans `setup()`
- **Clic droit** sur un item de la galerie → `PopupMenu` identique
- **Filtre par catégorie** : `OptionButton` dans l'onglet Galerie
- Filtrage appliqué lors du rafraîchissement de la grille

## Fichiers impactés

| Fichier | Action |
|---|---|
| `specs/032-image-categories.md` | Nouveau |
| `src/services/image_category_service.gd` | Nouveau |
| `specs/services/test_image_category_service.gd` | Nouveau |
| `src/ui/dialogs/category_manager_dialog.gd` | Nouveau |
| `specs/ui/dialogs/test_category_manager_dialog.gd` | Nouveau |
| `src/ui/dialogs/gallery_dialog.gd` | Modifié |
| `src/ui/dialogs/image_picker_dialog.gd` | Modifié |
| `specs/ui/dialogs/test_gallery_dialog.gd` | Modifié |
| `specs/ui/dialogs/test_image_picker_dialog.gd` | Modifié |

## Critères d'acceptation

1. Le service gère correctement les catégories par défaut et la persistance YAML
2. Les catégories peuvent être ajoutées, renommées et supprimées
3. Les images peuvent être assignées à plusieurs catégories
4. Le filtre par catégorie fonctionne dans la galerie et le picker
5. Le clic droit affiche un menu contextuel avec les catégories cochées/décochées
6. Le dialog de gestion des catégories permet l'ajout, le renommage et la suppression
7. La persistance fonctionne en roundtrip (save → load → données identiques)
8. Tous les tests GUT passent
