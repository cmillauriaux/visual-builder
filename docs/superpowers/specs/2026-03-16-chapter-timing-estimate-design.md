# Spec : Estimation du temps de jeu par chapitre

## Contexte

L'outil "Vérifier l'histoire" (`StoryVerifier` + `VerifierReportPanel`) simule tous les parcours
possibles de l'histoire et affiche un rapport de validation. Cette spec ajoute une estimation du
temps de jeu minimum et maximum pour chaque chapitre, visible dans ce rapport.

## Objectif

Afficher, par chapitre, la durée de lecture estimée pour :
- le joueur le plus rapide (chemin le plus court menant à la fin du chapitre)
- le joueur le plus lent (chemin le plus long)

Les deux estimées supposent que le joueur lit l'intégralité des dialogues.

## Paramètres de calcul

| Paramètre | Valeur |
|---|---|
| Vitesse de lecture | 200 mots / minute |
| Temps par clic (boîte de dialogue) | 5 secondes |

**Formule par séquence** :
```
secondes = (word_count / 200.0) * 60 + dialogue_count * 5.0
```

Les étapes `condition` et `choice` n'ont pas de dialogue : `word_count = 0`, `dialogue_count = 0`.

## Périmètre

- Fichiers modifiés : `src/services/story_verifier.gd`, `src/ui/editors/verifier_report_panel.gd`
- Fichier de tests : `specs/services/test_story_verifier.gd` (ou équivalent existant)
- Aucun nouveau fichier de service créé

## Modifications de `StoryVerifier`

### Nouvelles constantes

```gdscript
const WORDS_PER_MINUTE := 200.0
const SECONDS_PER_DIALOGUE_CLICK := 5.0
```

### Enrichissement des étapes de path

Dans `_simulate_run`, chaque étape `sequence` reçoit deux champs supplémentaires :

```gdscript
{
    "uuid": ...,
    "name": ...,
    "type": "sequence",
    "chapter_name": chapter.chapter_name,  # chapitre courant au moment de la visite
    "word_count": int,                      # total des mots de tous les dialogues
    "dialogue_count": int,                  # nombre de boîtes de dialogue (= nombre de clics)
}
```

Les étapes `condition` et `choice` reçoivent `chapter_name`, `word_count: 0`, `dialogue_count: 0`.

### Nouvelle méthode `_count_sequence_words(seq) -> int`

Compte le total des mots de tous les dialogues d'une séquence :

```gdscript
func _count_sequence_words(seq) -> int:
    var total := 0
    for dlg in seq.dialogues:
        total += dlg.text.split(" ", false).size()
    return total
```

### Nouvelle méthode `_compute_chapter_timings(runs) -> Array`

Algorithme :
1. Pour chaque run, accumuler `word_count` et `dialogue_count` par `chapter_name`
2. Convertir en secondes avec la formule ci-dessus
3. Stocker `[secondes_run0, secondes_run1, ...]` par chapitre
4. Trier et retourner `min = times[0]`, `max = times[-1]`

**Tous les runs sont inclus** (valides et invalides) — un run `game_over` représente un chemin
possible et contribue au calcul du minimum/maximum de chaque chapitre traversé.

Retourne :
```gdscript
[
    { "chapter_name": "Chapitre 1", "min_seconds": 150.0, "max_seconds": 315.0 },
    { "chapter_name": "Chapitre 2", "min_seconds": 105.0, "max_seconds": 240.0 },
]
```

L'ordre des chapitres est l'ordre de première apparition dans les runs.

### Nouvelle méthode `_format_duration(seconds: float) -> String`

- Si `seconds < 60` : `"X sec"`
- Sinon : `"X min Y sec"`

### Modification de `verify()`

Après la simulation des runs, calculer et inclure dans le rapport :
```gdscript
"chapter_timings": _compute_chapter_timings(runs)
```

## Modifications de `VerifierReportPanel`

### Nouveau bloc d'affichage

Inséré **entre le résumé (`SummaryPanel`) et les nœuds orphelins** dans `show_report()`.

Affiché uniquement si `chapter_timings` est non vide.

Structure visuelle :
```
-- Durée estimée par chapitre --

Chapitre 1    de 2 min 30 sec  à  5 min 15 sec
Chapitre 2    de 1 min 45 sec  à  4 min 00 sec
```

- Titre de section : même style que "Noeuds orphelins" (`font_size: 15`, couleur gris clair)
- Une ligne par chapitre, couleur blanche neutre

## Tests

Les tests couvrent :

1. `_count_sequence_words` : séquence sans dialogue, avec un dialogue, avec plusieurs dialogues
2. `_compute_chapter_timings` : histoire à 1 chapitre, histoire à 2 chapitres, runs avec chemins de longueurs différentes
3. `_format_duration` : valeurs < 60 sec, valeurs exactes en minutes, valeurs mixtes
4. `verify()` : vérifier que `chapter_timings` est présent et correct dans le rapport retourné
5. Intégration UI : `show_report` affiche le bloc timing quand `chapter_timings` est non vide, ne l'affiche pas si vide
