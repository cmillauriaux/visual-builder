# APNG Static Export — Design Spec

**Date**: 2026-04-17
**Objectif**: Ajouter une option d'export pour convertir les fichiers APNG en images statiques (première frame PNG), réduisant la taille de l'export.

## Contexte

Les foregrounds animés (APNG) peuvent être significativement plus lourds que des images statiques. Pour les exports où l'animation n'est pas nécessaire (versions légères, tests rapides), il est utile de pouvoir les aplatir en une seule image PNG.

## Architecture

### 1. UI — ExportDialog (`src/ui/dialogs/export_dialog.gd`)

Ajouter une checkbox `_static_apng_check` après la checkbox WebP existante (`_webp_check`).

- **Texte** : `"Désactiver les animations (APNG → image fixe)"`
- **Valeur par défaut** : `false` (décochée)
- **Clé dans `get_export_options()`** : `"static_apng"`

### 2. Pipeline — ExportService (`src/services/export_service.gd`)

#### Nouvelle étape : `_flatten_apng_files(story_dir: String, log_path: String) -> void`

Insérée dans `export_story()` **avant** le resize et la conversion WebP (entre la suppression des assets non utilisés et le redimensionnement), conditionnée par `export_options.get("static_apng", false)`.

**Algorithme** :
1. Parcourir récursivement le dossier story pour trouver tous les fichiers `.apng`
2. Pour chaque fichier `.apng` :
   - Lire les bytes bruts avec `FileAccess`
   - Charger avec `Image.load_png_from_buffer()` (les readers PNG standard ne voient que la première frame d'un APNG — rétrocompatibilité du format)
   - Sauvegarder en `.png` avec `img.save_png()` au même emplacement (extension changée)
   - Supprimer le fichier `.apng` original
3. Mettre à jour les références dans les fichiers YAML : remplacer `.apng` par `.png` via `_replace_filenames_in_yaml()` (méthode déjà existante)
4. Logger le nombre de fichiers convertis et le gain de taille

#### Helper : `_find_apng_files_recursive(dir_path: String) -> Array`

Parcours récursif retournant les chemins absolus de tous les fichiers `.apng`.

### 3. Intégration dans le pipeline existant

Les fichiers `.png` résultants sont automatiquement pris en charge par les étapes suivantes :
- **Resize** (`_resize_story_images`) : `_find_image_files_recursive` inclut déjà `.png`
- **WebP** (`_convert_images_to_webp`) : convertit les `.png` → `.webp` et met à jour les YAML
- **Strip imports** (`_strip_image_imports`) : appliqué aux `.png`/`.webp` résultants
- **PCK chapter builder** : résout les assets par nom dans les YAML — `.png` détecté
- **Story path rewriter** : travaille sur les noms de fichiers YAML — déjà mis à jour

Aucune modification nécessaire dans ces étapes.

### 4. Ordre des étapes dans `export_story()`

```
3b-extra. Filtrer langues / chapitres / assets non utilisés
     ↓
NEW: Aplatir APNG → PNG (si static_apng activé)
     ↓
3b. Resize images (si SD / Ultra SD)
     ↓
3b-bis. Convertir PNG/JPG → WebP (si webp activé)
```

## Tests

### Test ExportDialog (`specs/ui/dialogs/test_export_dialog.gd`)

- La checkbox `_static_apng_check` existe dans le dialogue
- `get_export_options()` retourne `"static_apng": false` par défaut
- `get_export_options()` retourne `"static_apng": true` quand la checkbox est cochée

### Test ExportService (`specs/services/test_export_service.gd`)

- `_flatten_apng_files` : un fichier `.apng` dans un dossier temp est remplacé par un `.png` valide
- `_flatten_apng_files` : les références `.apng` dans un fichier YAML sont remplacées par `.png`
- `_flatten_apng_files` : le fichier `.apng` original est supprimé
- `_find_apng_files_recursive` : trouve les fichiers `.apng` dans une arborescence de test

## Hors périmètre

- Pas de modification du modèle `Foreground` (les propriétés `anim_*` restent dans les YAML, elles sont simplement ignorées au runtime si l'image est un `.png`)
- Pas de modification de `ApngLoader` ou `ForegroundAnimPlayer`
- Pas de gestion du resize des APNG (les APNG sont aplatis avant le resize)
