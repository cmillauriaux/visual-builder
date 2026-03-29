# 074 — Export avec sélection de langue et export partiel

## Contexte

La fenêtre d'export permet d'exporter une story en jeu standalone. Actuellement, l'export inclut
toujours toutes les langues disponibles et tous les chapitres. On veut pouvoir :

1. **Sélectionner une langue spécifique** à exporter (texte + audio), ou "Tous" pour tout inclure.
2. **Exporter partiellement** en sélectionnant un chapitre de départ et un chapitre de fin.
3. **Refléter ces choix dans le nom du fichier exporté**, avec la version de la story.

## Objectif

### Nom du fichier exporté

Le nom suit le pattern : `{titre}[_{langue}][_ch{N}_to_ch{M}]_v{version}`

Exemples :
- Export complet, toutes langues : `DustNBone_v1.12`
- Export avec langue : `DustNBone_en_v1.12`
- Export partiel : `DustNBone_ch1_to_ch3_v1.12`
- Export partiel avec langue : `DustNBone_en_ch1_to_ch2_v1.12`

Les indices `ch{N}` sont 1-indexés (position dans l'array `story.chapters`).

### Langue

- Dropdown dans la fenêtre d'export : "Tous" (défaut) + codes langue disponibles dans `i18n/`
- La liste est chargée via `StoryI18nService.load_languages_config(story_path)`
- Si une langue est sélectionnée (non "Tous"), seuls `{lang}.yaml` et `languages.yaml` sont gardés dans le dossier `i18n/` de la story exportée

### Export partiel

- Case à cocher "Exporter partiellement"
- Quand cochée, affiche deux dropdowns : "Chapitre de départ" et "Chapitre de fin"
- Les dropdowns listent les chapitres dans l'ordre de `story.chapters` avec leur `chapter_name`
- "Chapitre de fin" ne peut pas être avant "Chapitre de départ"
- Si coché, seuls les chapitres dans l'intervalle [start_idx, end_idx] sont inclus dans l'export :
  - Les dossiers `chapters/{uuid}` non sélectionnés sont supprimés
  - Le fichier `story.yaml` est mis à jour pour ne lister que les chapitres sélectionnés

## Architecture

### Fichiers modifiés

| Fichier | Modification |
|---------|-------------|
| `src/ui/dialogs/export_dialog.gd` | Ajout dropdown langue + checkbox partial + dropdowns chapitres |
| `src/services/export_service.gd` | Paramètres langue/partial, génération nom, filtrage i18n + chapitres |
| `src/controllers/menu_controller.gd` | Transmission des nouveaux paramètres |

### Signal mis à jour

```gdscript
signal export_requested(platform: String, output_path: String, quality: String,
    export_options: Dictionary, language: String, partial_export: Dictionary)
```

`partial_export` est `{}` pour un export complet, ou `{"start_idx": int, "end_idx": int}` pour partiel.

### `export_story()` mis à jour

```gdscript
func export_story(story, platform, output_path, story_path, quality, export_options,
    language: String = "", partial_export: Dictionary = {}) -> ExportResult
```

## Critères d'acceptation

- [ ] La fenêtre d'export affiche un dropdown "Langue" avec "Tous" + langues disponibles de la story
- [ ] Si aucun fichier i18n n'existe, le dropdown contient uniquement "Tous"
- [ ] La case "Exporter partiellement" est décochée par défaut
- [ ] Quand elle est cochée, deux dropdowns chapitre (départ/fin) apparaissent
- [ ] Les dropdowns chapitres listent les chapitres dans l'ordre de `story.chapters`
- [ ] Le nom du fichier exporté inclut la langue si spécifiée (ex: `_en`)
- [ ] Le nom inclut la plage de chapitres si export partiel (ex: `_ch1_to_ch2`)
- [ ] Le nom inclut la version avec préfixe `v` (ex: `_v1.0.0`)
- [ ] La version est toujours présente dans le nom
- [ ] Un export avec langue "fr" et chapitres 1→3 génère `{titre}_fr_ch1_to_ch3_v{version}`
- [ ] Quand une langue est sélectionnée, seuls les fichiers i18n de cette langue sont exportés
- [ ] Quand export partiel, seuls les dossiers chapters sélectionnés sont copiés
- [ ] story.yaml du projet temporaire ne liste que les chapitres sélectionnés
- [ ] Tous les tests GUT passent
