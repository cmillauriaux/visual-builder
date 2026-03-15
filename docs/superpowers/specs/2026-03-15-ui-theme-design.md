# Design — Thème UI personnalisable

**Date :** 2026-03-15
**Statut :** Approuvé
**Périmètre :** Onglet "Thème UI" dans la boîte de dialogue "Configurer le jeu"

---

## Contexte

Le jeu visuel utilise un thème UI Kenney Adventure (style brun/beige) défini dans `src/ui/themes/game_theme.gd`. Les assets sont dans `assets/ui/kenney/`. Il n'existe pas encore de moyen de personnaliser ce thème par story.

Le projet est utilisé sur plusieurs postes via Git — toute solution doit être portable (pas de chemins absolus).

---

## Objectif

Permettre à l'auteur de remplacer tout ou partie des 8 assets Kenney par ses propres images. Le thème custom s'applique uniquement en mode Play et dans le jeu exporté — pas dans l'interface de l'éditeur elle-même.

---

## Assets personnalisables (8 fichiers)

Note : `scrollbar_brown.png` et `scrollbar_brown_small.png` existent dans `assets/ui/kenney/` mais les scrollbars utilisent `StyleBoxFlat` (code pur) — non personnalisables via PNG.

| Fichier | Rôle |
|---|---|
| `button_brown.png` | `_setup_button()`, `_setup_option_button()` — bouton standard |
| `button_red.png` | `apply_danger_style()` — bouton danger |
| `button_red_close.png` | `apply_close_style()` — bouton fermeture |
| `panel_brown.png` | `_setup_panel_container()` — panneau standard |
| `panel_brown_dark.png` | `apply_dark_panel_style()` — panneau sombre |
| `banner_hanging.png` | `main_menu.gd` — bannière du menu principal |
| `checkbox_brown_empty.png` | `_setup_check_button()` — toggle switch non activé |
| `checkbox_brown_checked.png` | `_setup_check_button()` — toggle switch activé |

---

## 1. Modèle de données

### `story.yaml`

```yaml
ui_theme:
  mode: "default"   # ou "custom"
```

Les assets custom ne sont **pas listés dans le YAML**. Leur présence dans `stories/{nom}/assets/ui/` est la source de vérité.

### Rétrocompatibilité

La sérialisation est dans **`story.gd`** (pas `story_saver.gd`) qui possède `to_dict()` / `from_dict()`.

```gdscript
# story.gd — from_dict()
story.ui_theme_mode = d.get("ui_theme", {}).get("mode", "default")

# story.gd — to_dict() — dans le dict retourné
"ui_theme": { "mode": ui_theme_mode },
```

Champ absent dans une ancienne story → `"default"`. Écrit à la prochaine sauvegarde. Aucune migration requise.

### `src/models/story.gd`

Ajout : `var ui_theme_mode: String = "default"`

---

## 2. Structure de fichiers

```
stories/{nom}/
  assets/
    ui/                     ← créé à la demande au premier import
      button_brown.png      ← override (si présent)
      …
    foregrounds/
    backgrounds/
```

Dossier git-tracké, portable entre postes. Créé par `DirAccess.make_dir_recursive_absolute()` lors du premier import.

---

## 3. Onglet "Thème UI" dans `menu_config_dialog.gd`

### Boutons radio

Deux `Button` dans un même `ButtonGroup` (avec `toggle_mode = true`). Godot 4 n'a pas de `RadioButton` natif.

### Structure de l'onglet

```
[ Par défaut ]  [ Personnaliser ]   ← ButtonGroup

--- Mode Par défaut ---
Aperçu statique du thème Kenney Adventure.
"Le jeu utilisera le thème par défaut."

--- Mode Personnaliser ---
Assets personnalisés (N / 8)

┌────────────────────────────────────────────────┐
│ [miniature]  button_brown.png    [✕] [Remplacer] │
│ [miniature]  panel_brown.png     [✕] [Remplacer] │
└────────────────────────────────────────────────┘

[ 📂 Parcourir… ]
  "Sélectionner une ou plusieurs images PNG"
  "Noms attendus : button_brown.png, panel_brown.png…"
```

### Comportements

**Boutons "Par défaut / Personnaliser"** : bascule l'affichage. Ne supprime pas les assets déjà importés.

**Bouton "Remplacer" (par asset)** : file picker single PNG → copie dans `{story_base_path}/assets/ui/{nom_standard}.png` → rafraîchit la miniature.

**Bouton "✕ Supprimer" (par asset)** : supprime le fichier de `assets/ui/` → l'asset disparaît de la liste.

**Bouton "📂 Parcourir…" (bas de liste)** : file picker multi-sélection PNG (desktop uniquement — l'éditeur ne tourne pas en web).
- Fichiers dont le nom correspond à un des 8 assets → copiés dans `assets/ui/`.
- Fichiers non reconnus → popup warning : *"N fichier(s) ignoré(s) : nom1.png, nom2.png…"*

**Import** : copie physique dans le dossier de la story. Crée `assets/ui/` si absent. Pas de chemin absolu stocké.

---

## 4. Chargement dynamique du thème (`game_theme.gd`)

### Helper privé

```gdscript
static func _resolve_asset(filename: String, story_ui_path: String) -> Texture2D:
    if story_ui_path != "":
        var custom_path = story_ui_path + "/" + filename
        if FileAccess.file_exists(custom_path):
            return load(custom_path)
    return load(ASSETS_PATH + filename)
```

`FileAccess.file_exists()` fonctionne avec des chemins `res://` et des chemins absolus en Godot 4 — utilisable dans les deux contextes (éditeur et jeu exporté).

### Nouvelles signatures publiques

```gdscript
static func create_theme(story_ui_path: String = "") -> Theme
static func apply_danger_style(button: Button, story_ui_path: String = "") -> void
static func apply_close_style(button: Button, story_ui_path: String = "") -> void
static func apply_dark_panel_style(panel: PanelContainer, story_ui_path: String = "") -> void
```

Le paramètre `story_ui_path` a une valeur par défaut `""` → **zéro breaking change** sur tous les callers existants (`options_menu.gd`, `save_load_menu.gd`, `chapter_scene_menu.gd`, `pause_menu.gd`, `ending_screen.gd`) qui continuent d'appeler sans argument.

### `main_menu.gd` — bannière

`build_ui()` charge `banner_hanging.png` avant que la story soit connue. Solution :
- `build_ui()` **conserve** le `load(GameTheme.ASSETS_PATH + "banner_hanging.png")` existant (bannière par défaut présente dès le premier frame)
- `build_ui()` assigne en plus ce `TextureRect` à `_banner_texture_rect` (nouvelle variable membre — à ajouter à la classe)
- Ajout de la méthode `update_banner(story_ui_path: String)` :

```gdscript
func update_banner(story_ui_path: String) -> void:
    var tex = GameTheme._resolve_asset("banner_hanging.png", story_ui_path)
    if tex and _banner_texture_rect:
        _banner_texture_rect.texture = tex
```

### Menus avec styles overridés (`apply_danger_style`, etc.)

Les menus (`pause_menu.gd`, `save_load_menu.gd`, `chapter_scene_menu.gd`) appellent `apply_danger_style()` et `apply_close_style()` dans leur `build_ui()` — avant que la story soit chargée. Solution : chaque menu concerné expose une méthode `apply_custom_theme(story_ui_path: String)` qui ré-appelle les fonctions `apply_*` avec le bon path sur les boutons existants. Cette méthode est appelée par `game.gd` après le chargement de la story, uniquement si `ui_theme_mode == "custom"`.

### En mode Play (éditeur)

`main.gd` possède `_play_overlay: PanelContainer` (ligne 98) et `_choice_overlay: CenterContainer` (ligne 102). Dans `play_controller.gd`, le thème est appliqué dans `on_play_pressed()` et `on_top_play_pressed()`, retiré dans `on_stop_pressed()` :

```gdscript
# on_play_pressed() et on_top_play_pressed() — en début de fonction
var ui_path = ""
var story = _main._editor_main.get_current_story()
if story != null and story.ui_theme_mode == "custom":
    ui_path = _main._get_story_base_path() + "/assets/ui"
_main._play_overlay.theme = GameTheme.create_theme(ui_path)
_main._choice_overlay.theme = GameTheme.create_theme(ui_path)

# on_stop_pressed() — en début de fonction
_main._play_overlay.theme = null   # hérite du thème éditeur
_main._choice_overlay.theme = null
```

Le thème s'applique uniquement aux nœuds play — l'éditeur reste inchangé.

### Dans le jeu exporté (`game_ui_builder.gd` / `game.gd`)

`GameUIBuilder.build()` garde `game.theme = GameTheme.create_theme()` (sans argument) — thème par défaut immédiat, pas de flash non thématisé. Ensuite, dans `game.gd._load_story_and_show_menu()` (ligne 277, appelée dans `_ready()` de manière synchrone) :

```gdscript
var ui_path = ""
if story != null and story.ui_theme_mode == "custom":
    ui_path = "res://story/assets/ui"
self.theme = GameTheme.create_theme(ui_path)
_main_menu.update_banner(ui_path)
if story.ui_theme_mode == "custom":
    _pause_menu.apply_custom_theme(ui_path)
    _save_load_menu.apply_custom_theme(ui_path)
    _chapter_scene_menu.apply_custom_theme(ui_path)
```

---

## 5. Export (`export_service.gd`)

### Correction du bug dans `_copy_dir_recursive`

Ligne 350, la méthode passe `[]` lors des récursions, empêchant toute exclusion de sous-dossiers. Correction :

```gdscript
_copy_dir_recursive(from_path, to_path, exclude)  # au lieu de []
```

### Exclusion de `assets/ui` selon le mode

```gdscript
var story_exclude = ["artbook"]
if story.ui_theme_mode != "custom":   # story est le paramètre RefCounted de export_story()
    story_exclude.append("ui")
_copy_dir_recursive(abs_story_dir, abs_temp_story, story_exclude)
```

`story.ui_theme_mode` est accessible via le paramètre `story: RefCounted` déjà présent dans `export_story()`. Avec la correction de propagation, `"ui"` est comparé à `file_name` à chaque niveau de récursion. Comme `assets/ui/` est le seul dossier nommé `ui` dans la structure story, l'exclusion est sans ambiguïté.

---

## 6. Signal `menu_config_confirmed`

Ajout de `ui_theme_mode: String` à la fin du signal (17 paramètres). Deux mises à jour obligatoires :

1. La déclaration du signal dans `menu_config_dialog.gd` ajoute le paramètre `ui_theme_mode: String`.
2. L'émission dans `_on_confirmed()` (ligne 645) passe `_ui_theme_mode` comme 17e argument (variable locale lue depuis le bouton radio de l'onglet).
3. La méthode `_on_menu_config_confirmed` dans `navigation_controller.gd` accepte ce 17e paramètre et met à jour `story.ui_theme_mode`.

Refactorisation vers un objet de données : tâche déférée indépendante.

---

## 7. Tests

- Ancienne story sans `ui_theme` → `ui_theme_mode == "default"`, champ sérialisé dans `to_dict()`.
- `to_dict()` → dict contient `{ "ui_theme": { "mode": "default" } }`.
- `create_theme("")` → 8 assets Kenney chargés.
- `create_theme(ui_path)` avec 2 overrides → 2 assets custom, 6 en fallback Kenney.
- `create_theme(ui_path)` avec dossier `assets/ui/` vide ou absent → 8 assets Kenney.
- `apply_danger_style(btn, ui_path)` avec `button_red.png` custom → texture custom.
- `apply_close_style(btn, ui_path)` avec `button_red_close.png` custom → texture custom.
- `apply_dark_panel_style(panel, ui_path)` avec `panel_brown_dark.png` custom → texture custom.
- `update_banner(ui_path)` avec `banner_hanging.png` custom → texture bannière mise à jour.
- Import multi-fichiers : fichier inconnu → warning, fichiers reconnus importés.
- Import : `assets/ui/` créé si absent.
- Suppression d'un asset custom → fichier supprimé, fallback Kenney actif.
- Export mode custom → `assets/ui/` présent dans le build.
- Export mode default → `assets/ui/` absent du build.
- `_copy_dir_recursive` avec exclusion propagée → sous-dossier exclu correctement.
- Play éditeur mode custom → thème appliqué sur `_play_overlay` et `_choice_overlay` uniquement.
- Stop play → `theme = null` sur ces nœuds, éditeur inchangé.
- `_on_menu_config_confirmed` dans `navigation_controller.gd` accepte le 17e paramètre.
