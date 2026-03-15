# Design — Thème UI personnalisable

**Date :** 2026-03-15
**Statut :** Approuvé
**Périmètre :** Onglet "Thème UI" dans la boîte de dialogue "Configurer le jeu"

---

## Contexte

Le jeu visuel utilise un thème UI Kenney Adventure (style brun/beige) défini dans `src/ui/themes/game_theme.gd`. Les assets sont dans `assets/ui/kenney/` (10 fichiers PNG). Il n'existe pas encore de moyen de personnaliser ce thème par story.

Le projet est utilisé sur plusieurs postes via Git — toute solution doit être portable (pas de chemins absolus).

---

## Objectif

Permettre à l'auteur de choisir, pour chaque story, un thème UI personnalisé : remplacer tout ou partie des 10 assets Kenney par ses propres images. Le thème custom s'applique uniquement en mode Play (prévisualisation dans l'éditeur) et dans le jeu exporté — pas dans l'interface de l'éditeur elle-même.

---

## Assets UI reconnus

Les 10 noms de fichiers attendus (noms exacts) :

| Fichier | Rôle |
|---|---|
| `button_brown.png` | Bouton standard (Button, OptionButton) |
| `button_red.png` | Bouton danger |
| `button_red_close.png` | Bouton fermeture (×) |
| `panel_brown.png` | Panneau standard (PanelContainer) |
| `panel_brown_dark.png` | Panneau sombre |
| `banner_hanging.png` | Bannière du menu principal |
| `checkbox_brown_empty.png` | Case à cocher non cochée |
| `checkbox_brown_checked.png` | Case à cocher cochée |
| `scrollbar_brown.png` | Scrollbar standard |
| `scrollbar_brown_small.png` | Scrollbar compacte |

---

## 1. Modèle de données

### `story.yaml`

Ajout d'un champ à la racine :

```yaml
ui_theme:
  mode: "default"   # ou "custom"
```

Les assets custom ne sont **pas listés dans le YAML**. Leur présence dans `stories/{nom}/assets/ui/` est la source de vérité.

### Rétrocompatibilité

Pour les stories existantes sans ce champ, le chargement dans `story_saver.gd` utilise :

```gdscript
story.ui_theme_mode = data.get("ui_theme", {}).get("mode", "default")
```

Le champ est écrit à la prochaine sauvegarde normale. Aucune migration requise.

### `src/models/story.gd`

Ajout : `var ui_theme_mode: String = "default"`

---

## 2. Structure de fichiers

Les assets custom sont stockés dans le dossier de la story :

```
stories/{nom}/
  assets/
    ui/                         ← nouveau dossier
      button_brown.png          ← override (si présent)
      panel_brown.png           ← override (si présent)
      …                         ← autres overrides
    foregrounds/
    backgrounds/
```

- Seuls les fichiers présents overrident le défaut.
- Les fichiers manquants utilisent le fallback Kenney.
- Le dossier est git-tracké → portable entre postes.

---

## 3. Onglet "Thème UI" dans `menu_config_dialog.gd`

### Structure de l'onglet

```
[ Par défaut ]  [ Personnaliser ]   ← boutons radio

--- Mode Par défaut ---
Aperçu statique du thème Kenney Adventure.
"Le jeu utilisera le thème par défaut."

--- Mode Personnaliser ---
Assets personnalisés (N / 10)

┌─────────────────────────────────────────────┐
│ [miniature]  button_brown.png    [✕] [Remplacer] │
│ [miniature]  panel_brown.png     [✕] [Remplacer] │
└─────────────────────────────────────────────┘

[ 📂 Parcourir… ]
  "Sélectionner une ou plusieurs images PNG"
  "Les fichiers doivent être nommés : button_brown.png, …"
```

### Comportements

**Bouton radio "Par défaut" ↔ "Personnaliser"** : bascule l'affichage. Ne supprime pas les assets déjà importés.

**Bouton "Remplacer" (par asset)** : file picker single PNG → copie dans `stories/{nom}/assets/ui/{nom_standard}.png` → rafraîchit la miniature.

**Bouton "✕ Supprimer" (par asset)** : supprime le fichier de `assets/ui/` → l'asset disparaît de la liste (fallback Kenney actif).

**Bouton "📂 Parcourir…" (bas de liste)** : file picker multi-sélection PNG.
- Fichiers dont le nom correspond à un des 10 assets → copiés dans `assets/ui/`.
- Fichiers non reconnus → popup warning : *"N fichier(s) ignoré(s) : nom1.png, nom2.png… (nom non reconnu)"*.

**Import** : même pattern que les foregrounds/backgrounds — copie physique du fichier source dans le dossier de la story. Pas de référence de chemin absolu stockée.

---

## 4. Chargement dynamique du thème (`game_theme.gd`)

```gdscript
static func create_theme(story_ui_path: String = "") -> Theme:
    # Pour chaque asset, cherche d'abord story_ui_path + filename
    # Fallback sur res://assets/ui/kenney/ si absent ou chemin vide
```

**En mode Play (éditeur)** : `play_controller.gd` appelle `create_theme()` avec :
- `story.path + "/assets/ui"` si `story.ui_theme_mode == "custom"`
- `""` sinon (thème défaut)

**Dans `game.tscn` (jeu exporté)** : le thème est créé avec `res://story/assets/ui` si le dossier existe, sinon `""`.

---

## 5. Export (`export_service.gd`)

- Si `story.ui_theme_mode == "custom"` ET `stories/{nom}/assets/ui/` non vide : copier le dossier dans `res://story/assets/ui/` dans le projet exporté.
- Si mode `"default"` ou dossier vide : ne rien copier. Le fallback Kenney intégré (`res://assets/ui/kenney/`) s'applique.

---

## 6. Signal `menu_config_confirmed`

Ajout de `ui_theme_mode: String` à la fin des paramètres du signal (pas de breaking change sur les paramètres existants).

---

## 7. Tests

- Charger une ancienne story sans `ui_theme` → `ui_theme_mode == "default"`, champ écrit à la prochaine sauvegarde.
- Mode défaut → `create_theme("")` → tous les assets Kenney chargés.
- Mode custom avec 2 overrides → les 2 assets custom chargés, les 8 autres en fallback Kenney.
- Import multi-fichiers avec 1 fichier non reconnu → warning affiché, les autres importés.
- Suppression d'un asset custom → fichier supprimé, fallback Kenney actif.
- Export avec mode custom → dossier `assets/ui/` copié dans le projet exporté.
