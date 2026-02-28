# 023 — Export d'une histoire en jeu standalone

## Contexte

Le projet contient un éditeur (`main.tscn`) et un mode jeu standalone (`game.tscn`).
Aujourd'hui, exporter une histoire en jeu autonome nécessite plusieurs étapes manuelles
(copier la story dans `res://story/`, modifier `project.godot`, configurer les export presets, etc.).
On veut automatiser ce processus via un script CLI et un bouton dans l'éditeur.

## Objectif

1. **StoryPathRewriter** : réécrire les chemins d'images `user://` en `res://` dans une story copiée
2. **Script shell CLI** : `scripts/export_story.sh` pour exporter depuis le terminal
3. **Bouton UI** : dialog d'export dans l'éditeur visuel

## Problème technique : réécriture des chemins d'images

Les images dans les modèles sont stockées en chemins absolus `user://` :
- `sequence.background` → `user://stories/<name>/assets/backgrounds/img.png`
- `foreground.image` → `user://stories/<name>/assets/foregrounds/img.png`
- `dialogue.foregrounds[].image` → idem

Le `menu_background` est déjà relatif (ex: `backgrounds/menu_bg.png`), résolu par
`main_menu.gd` avec `base_path + "/assets/"`.

Pour l'export, la story est copiée dans `res://story/`. Les chemins `user://` doivent
être réécrits en `res://story/assets/...` sinon les images ne se chargeront pas.

## Architecture

### Fichiers créés

| Fichier | Rôle |
|---------|------|
| `src/export/story_path_rewriter.gd` | Réécriture des chemins images dans la story |
| `src/export/rewrite_runner.gd` | Script headless pour lancer la réécriture |
| `src/ui/dialogs/export_dialog.gd` | Dialog UI d'export dans l'éditeur |
| `scripts/export_story.sh` | Script shell principal |
| `scripts/export_presets/web.cfg` | Template export preset HTML5 |
| `scripts/export_presets/macos.cfg` | Template export preset macOS |
| `scripts/export_presets/linux.cfg` | Template export preset Linux |
| `scripts/export_presets/windows.cfg` | Template export preset Windows |
| `scripts/export_presets/android.cfg` | Template export preset Android |

### Fichiers modifiés

| Fichier | Modification |
|---------|-------------|
| `src/main.gd` | Connexion du bouton export au dialog |
| `src/controllers/main_ui_builder.gd` | Ajout du bouton "Exporter" dans la top bar |
| `.gutconfig.json` | Ajout de `res://specs/export/` aux dirs de test |

## StoryPathRewriter

Classe statique qui réécrit les chemins d'images dans une story chargée en mémoire.

```gdscript
static func rewrite_story_paths(story_folder: String, new_base: String) -> bool
```

### Logique de réécriture

Pour chaque séquence de la story :
1. `sequence.background` : si commence par `user://`, extraire le nom de fichier et remplacer par `{new_base}/assets/backgrounds/{filename}`
2. `sequence.foregrounds[].image` : si commence par `user://`, remplacer par `{new_base}/assets/foregrounds/{filename}`
3. Pour chaque dialogue, `dialogue.foregrounds[].image` : même traitement

Ne touche **pas** à `story.menu_background` (déjà relatif).

### Approche

Chargement via `StorySaver.load_story()`, modification des objets en mémoire,
sauvegarde via `StorySaver.save_story()`. Plus robuste que du regex/sed car utilise
le modèle de données existant.

## Script shell `scripts/export_story.sh`

### Usage

```
./scripts/export_story.sh <story_path> [options]

Arguments:
  story_path              Chemin vers le dossier story (user://, absolu, ou res://)

Options:
  -o, --output DIR        Répertoire de sortie (défaut: ./build/)
  -p, --platform PLAT     Plateforme: web, macos, linux, windows, android (défaut: web)
  -n, --name NAME         Nom du fichier exporté (défaut: titre de la story)
  --godot PATH            Chemin vers le binaire Godot
  --keep-temp             Garder le dossier temporaire pour debug
  -h, --help              Aide
```

### Flux

1. Parser les arguments, valider les entrées
2. Résoudre `story_path` → chemin OS absolu
3. Valider : `story.yaml` existe dans le dossier
4. Créer un dossier temporaire
5. Copier le projet dans `temp/` (exclure `.godot/`, `.git/`, `build/`)
6. Copier la story dans `temp/project/story/`
7. Réécrire les chemins via Godot headless + `rewrite_runner.gd`
8. Modifier `project.godot` : `run/main_scene` → `res://src/game.tscn`
9. Modifier `game.tscn` : ajouter `story_path = "res://story"`
10. Copier le preset d'export approprié
11. Lancer l'import Godot headless
12. Lancer l'export Godot headless
13. Nettoyer `temp/` (sauf si `--keep-temp`)

## Export Dialog UI

Dialog modal dans l'éditeur avec :
- Sélection plateforme (dropdown)
- Nom du jeu (champ texte, pré-rempli avec le titre de la story)
- Bouton "Exporter" qui lance le processus

Le bouton "Exporter" est ajouté dans la top bar, à côté de "Sauvegarder".
Actif uniquement si une story est chargée.

## Critères d'acceptation

- [ ] `StoryPathRewriter.rewrite_story_paths()` réécrit correctement les chemins `user://`
- [ ] Les chemins `res://` existants ne sont pas modifiés
- [ ] Les chemins vides restent vides
- [ ] `menu_background` (relatif) n'est pas touché
- [ ] Les foregrounds dans les dialogues sont aussi réécrits
- [ ] `scripts/export_story.sh` existe et est exécutable
- [ ] Les presets d'export existent pour web, macos, linux, windows, android
- [ ] `rewrite_runner.gd` fonctionne en mode headless
- [ ] Le bouton "Exporter" apparaît dans la toolbar de l'éditeur
- [ ] Le dialog d'export affiche les plateformes disponibles
- [ ] Le dialog pré-remplit le nom avec le titre de la story
- [ ] Le bouton export est désactivé sans story chargée
- [ ] Tous les tests GUT passent
