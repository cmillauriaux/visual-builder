# Temps audio réel dans le rapport de vérification

**Date** : 2026-03-30
**Statut** : Approuvé

## Contexte

Le panneau de vérification d'histoire affiche un temps de lecture estimé basé sur une formule (mots/250 WPM + dialogues + choix). On veut ajouter le **temps de lecture audio réel** en additionnant la durée effective de chaque fichier voice des dialogues.

## Décisions

- **Audios comptés** : uniquement les `voice_files` des dialogues (pas music/audio_fx).
- **Langue** : première langue disponible dans le dictionnaire `voice_files` de chaque dialogue.
- **Présentation** : même structure que le temps texte (par chapitre min/max + total).
- **Approche** : calcul dans le StoryVerifier pendant la simulation, avec cache local.

## Design

### Signature de verify()

```gdscript
func verify(story: RefCounted, story_base_path: String = "") -> Dictionary
```

Le `story_base_path` permet de résoudre les chemins relatifs des `voice_files`.

### Cache audio

Un dictionnaire `_audio_duration_cache: Dictionary` (path -> float) dans le verifier évite de recharger le même fichier entre runs. Réinitialisé à chaque appel à `verify()`.

### Chargement audio

Fonction utilitaire `_get_audio_duration(path: String) -> float` qui :
1. Vérifie le cache.
2. Charge le fichier OGG/MP3 via `FileAccess` + `load_from_buffer` / `AudioStreamMP3.data`.
3. Retourne `stream.get_length()`.
4. Met en cache le résultat.
5. Retourne 0.0 si le fichier est introuvable ou le format non supporté.

### Calcul par séquence

Pour chaque séquence visitée, `_compute_sequence_audio_duration(seq, story_base_path) -> float` :
1. Pour chaque dialogue de la séquence.
2. Si `voice_files` est non vide, prendre la première langue disponible.
3. Résoudre le chemin : `story_base_path + "/" + relative_path`.
4. Appeler `_get_audio_duration()`.
5. Sommer les durées.

### Données ajoutées au step

```gdscript
# Dans chaque step de type "sequence" :
{
    "uuid": "...",
    "name": "...",
    "type": "sequence",
    "chapter_name": "...",
    "word_count": 42,
    "dialogue_count": 3,
    "audio_duration": 12.5,  # float, secondes
}
```

### _compute_timings enrichi

Calcule deux séries parallèles par chemin :
- `min_seconds` / `max_seconds` : temps texte (inchangé)
- `audio_min_seconds` / `audio_max_seconds` : somme des durées audio

Structure de sortie enrichie :
```gdscript
{
    "chapter_name": "Les Épreuves",
    "continuation": {
        "min_seconds": 120.0, "max_seconds": 300.0,
        "audio_min_seconds": 90.0, "audio_max_seconds": 220.0
    }
}
```

### Affichage UI (verifier_report_panel.gd)

Sous chaque ligne de durée texte, une ligne audio :
```
-- Durée totale estimée --
  Histoire (Suite)           de 2 min  à  5 min
  Histoire (Suite) audio     de 1 min 30 sec  à  3 min 40 sec
```

Les lignes audio utilisent une couleur bleu clair pour se distinguer.
Si le total audio est 0 pour toute la story, les lignes audio ne sont pas affichées.

### Formateur texte (story_verifier_formatter.gd)

Mêmes ajouts dans les sections timings du rapport texte.

### Appelants

- `navigation_controller.gd` : passer `_main._get_story_base_path()` à `verify()`.
- `tools/verify_story.gd` : passer le story_path à `verify()`.

## Cas limites

| Cas | Comportement |
|-----|-------------|
| Aucun voice_file | `audio_duration = 0`, pas de ligne audio affichée si total = 0 |
| Fichier introuvable | durée = 0, warning console, vérification continue |
| Mode headless | OGG/MP3 chargés via FileAccess (pas de GPU requis) |
| story_base_path vide | chemins non résolus, audio_duration = 0 partout |

## Fichiers impactés

| Fichier | Modification |
|---------|-------------|
| `src/services/story_verifier.gd` | `story_base_path`, cache, calcul durées, `_compute_timings` enrichi |
| `src/ui/editors/verifier_report_panel.gd` | Affichage lignes audio |
| `src/services/story_verifier_formatter.gd` | Lignes audio dans rapport texte |
| `src/controllers/navigation_controller.gd` | Passer story_base_path à verify() |
| `tools/verify_story.gd` | Passer story_base_path à verify() |
| `specs/services/test_story_verifier.gd` | Tests durées audio |
| `specs/services/test_story_verifier_formatter.gd` | Tests format audio |
| `specs/ui/editors/test_verifier_report_panel.gd` | Tests affichage audio |
