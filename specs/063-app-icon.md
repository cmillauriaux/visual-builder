# 063 — Icône d'application configurable

## Résumé

Permet à l'utilisateur de définir une icône carrée (ex : 1024×1024) par story dans la configuration du jeu. Lors de l'export web, toutes les variantes d'icônes (PWA, favicon, Apple Touch Icon) sont générées automatiquement à partir de cette image source.

## Comportement attendu

### Nouveau champ du modèle Story

| Champ | Type | Défaut |
|-------|------|--------|
| `app_icon` | `String` | `""` |

Sérialisation dans `story.yaml` au même niveau que `menu_background` :

```yaml
app_icon: "icon.png"
```

`from_dict()` tolère l'absence du champ (rétrocompatibilité — valeur vide par défaut).

### Configuration dans MenuConfigDialog

Nouvelle section **"Icône de l'application"** ajoutée en bas de l'onglet "Menu", séparée par un `HSeparator`. L'onglet Menu est enveloppé dans un `ScrollContainer` pour rester accessible.

Contenu de la section :
- `Label` titre : "Icône de l'application" (font_size 16)
- `Label` info : "Image carrée, recommandé : 1024×1024" (gris)
- `HBoxContainer` avec :
  - `LineEdit` (read-only) affichant le chemin du fichier
  - Bouton `Parcourir...` → ouvre `ImagePickerDialog` en mode `BACKGROUND`
  - Bouton `✕` → efface la sélection
- `TextureRect` pour l'aperçu (100×100, `STRETCH_KEEP_ASPECT_CENTERED`, `SIZE_SHRINK_BEGIN`)
- `Label` d'avertissement (rouge, masqué par défaut) : "L'image n'est pas carrée — elle sera déformée"

Le signal `menu_config_confirmed` est étendu avec un paramètre `app_icon: String`.

`setup()` pré-remplit le champ depuis `story.app_icon`.

### Génération des icônes à l'export

Dans `ExportService.export_story()`, après l'étape boot splash (3c), si `story.app_icon` est défini et le fichier existe :

1. Charger l'image source via `Image.load()`
2. Générer les 3 variantes PWA via `Image.resize()` avec `INTERPOLATE_LANCZOS` :
   - 144×144 → `{temp_project}/assets/icons/icon_144x144.png`
   - 180×180 → `{temp_project}/assets/icons/icon_180x180.png`
   - 512×512 → `{temp_project}/assets/icons/icon_512x512.png`
3. Générer une icône projet (512×512 PNG) et mettre à jour `config/icon` dans le `project.godot` temporaire → Godot génère automatiquement `index.icon.png` (favicon) et `index.apple-touch-icon.png`

Si `app_icon` est vide : les icônes par défaut de `assets/icons/` sont utilisées (comportement actuel inchangé).

### Tailles d'icônes générées

| Fichier | Taille | Usage | Généré par |
|---------|--------|-------|------------|
| `icon_144x144.png` | 144×144 | PWA manifest (Android) | Notre code |
| `icon_180x180.png` | 180×180 | PWA manifest (iOS) | Notre code |
| `icon_512x512.png` | 512×512 | PWA splash / install | Notre code |
| `index.icon.png` | automatique | Favicon HTML | Godot (via config/icon) |
| `index.apple-touch-icon.png` | automatique | iOS Safari | Godot (via config/icon) |

## Critères d'acceptation

### Modèle Story
- [ ] `StoryModel` possède la propriété `app_icon` avec `""` comme valeur par défaut
- [ ] `to_dict()` sérialise `app_icon` à la racine du dictionnaire
- [ ] `from_dict()` restaure la valeur ; si absente, la valeur est `""`

### MenuConfigDialog
- [ ] Une section "Icône de l'application" est visible dans l'onglet Menu (après la musique, séparée par HSeparator)
- [ ] La section contient un champ de sélection d'image avec Parcourir/✕ et aperçu
- [ ] `setup()` pré-remplit le champ depuis `story.app_icon`
- [ ] `Parcourir...` ouvre `ImagePickerDialog` en mode `BACKGROUND`
- [ ] `✕` efface le chemin et l'aperçu
- [ ] Si l'image sélectionnée n'est pas carrée, un avertissement rouge est affiché
- [ ] Le signal `menu_config_confirmed` inclut le paramètre `app_icon`

### NavigationController
- [ ] `_on_menu_config_confirmed()` reçoit et applique `app_icon` sur la story

### Export (ExportService)
- [ ] Si `app_icon` est défini, les 3 icônes PWA sont générées aux bonnes tailles dans le projet temporaire
- [ ] Si `app_icon` est défini, `config/icon` est mis à jour dans le project.godot temporaire
- [ ] Si `app_icon` est vide, les icônes par défaut sont utilisées (pas de régression)
- [ ] L'image source est redimensionnée avec interpolation Lanczos

### Tests
- [ ] Tests GUT couvrent `StoryModel` : sérialisation/désérialisation de `app_icon`
- [ ] Tests GUT couvrent `MenuConfigDialog` : onglet icône, signal étendu
- [ ] Tests GUT couvrent `ExportService` : génération des icônes (méthode extraite testable)
- [ ] Les tests passent
