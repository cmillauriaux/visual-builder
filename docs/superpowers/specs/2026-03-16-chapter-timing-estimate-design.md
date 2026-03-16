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

Dans `_simulate_run`, **dans la branche `else` (séquence)**, juste avant d'appeler
`path.append(...)`, calculer :

```gdscript
var word_count := _count_sequence_words(current_node)   # current_node est la séquence
var dialogue_count := current_node.dialogues.size()
```

Puis construire le step :

```gdscript
path.append({
    "uuid": node_uuid,
    "name": node_name,
    "type": "sequence",
    "chapter_name": chapter.chapter_name,  # capturé ICI, avant toute résolution de conséquence
    "word_count": word_count,
    "dialogue_count": dialogue_count,
})
```

> **Important** : `chapter.chapter_name` doit être lu **avant** l'appel à `_resolve_consequence`,
> car cette méthode peut réassigner `chapter` (via `redirect_chapter`).

Les étapes `condition` reçoivent également `chapter_name` (pour permettre le groupement),
mais `word_count: 0` et `dialogue_count: 0` — elles ne contribuent pas au temps :

```gdscript
path.append({
    "uuid": node_uuid,
    "name": node_name,
    "type": "condition",
    "chapter_name": chapter.chapter_name,
    "word_count": 0,
    "dialogue_count": 0,
})
```

Les étapes `choice` reçoivent aussi `chapter_name`, `word_count: 0`, `dialogue_count: 0` :

```gdscript
path.append({
    "uuid": node_uuid,
    "name": "Choix: " + choice.text,
    "type": "choice",
    "choice_index": choice_index,
    "chapter_name": chapter.chapter_name,
    "word_count": 0,
    "dialogue_count": 0,
})
```

### Nouvelle méthode `_count_sequence_words(seq) -> int`

Compte le total des mots de tous les dialogues d'une séquence en utilisant `split_words()`
qui gère correctement les espaces, retours à la ligne et tabulations :

```gdscript
func _count_sequence_words(seq) -> int:
    var total := 0
    for dlg in seq.dialogues:
        total += dlg.text.split_words().size()
    return total
```

### Nouvelle méthode `_compute_chapter_timings(runs) -> Array`

**Algorithme** :
1. Pour chaque run, parcourir **tous** les steps (sequences, conditions, choices confondus —
   les non-sequences contribuant 0, le résultat est identique à filtrer)
2. Accumuler `word_count` et `dialogue_count` par `chapter_name` pour ce run
3. Convertir en secondes avec la formule ci-dessus
4. Stocker `[secondes_run0, secondes_run1, ...]` par chapitre en préservant l'ordre
   de première apparition
5. Résultat : `min = times[0]`, `max = times[-1]` après tri

**Runs inclus** : tous les runs sauf ceux dont `ending_reason` est `"error"` ou
`"loop_detected"`, car ces parcours sont tronqués ou invalides et produiraient des
minimums artificiellement courts. Les runs `"game_over"` sont inclus — ils représentent
un chemin réel dans le chapitre.

Retourne :
```gdscript
[
    { "chapter_name": "Chapitre 1", "min_seconds": 150.0, "max_seconds": 315.0 },
    { "chapter_name": "Chapitre 2", "min_seconds": 105.0, "max_seconds": 240.0 },
]
```

### Nouvelle méthode `_format_duration(seconds: float) -> String`

| Cas | Exemple d'entrée | Sortie |
|---|---|---|
| Moins d'une minute | 45.0 | `"45 sec"` |
| Minutes exactes | 120.0 | `"2 min"` |
| Minutes et secondes | 150.0 | `"2 min 30 sec"` |

```gdscript
func _format_duration(seconds: float) -> String:
    var total_sec := int(round(seconds))
    var m := total_sec / 60
    var s := total_sec % 60
    if m == 0:
        return "%d sec" % s
    if s == 0:
        return "%d min" % m
    return "%d min %d sec" % [m, s]
```

### Modification de `verify()`

Le dictionnaire retourné par `verify()` inclut le nouveau champ :

```gdscript
return {
    "success": all_valid and orphans.is_empty(),
    "runs": runs,
    "orphan_nodes": orphans,
    "total_runs": runs.size(),
    "all_nodes": all_nodes.size(),
    "visited_nodes": visited_nodes.size(),
    "chapter_timings": _compute_chapter_timings(runs),
}
```

### Modification de `_empty_report()`

Ajouter `"chapter_timings": []` pour cohérence de la forme du dictionnaire :

```gdscript
func _empty_report() -> Dictionary:
    return {
        "success": false,
        "runs": [],
        "orphan_nodes": [],
        "total_runs": 0,
        "all_nodes": 0,
        "visited_nodes": 0,
        "chapter_timings": [],
    }
```

## Modifications de `VerifierReportPanel`

### Nouveau bloc d'affichage

Inséré **après le `HSeparator` qui suit `SummaryPanel`** et **avant le bloc des nœuds orphelins**
dans `show_report()`. La structure de la méthode devient :

```
SummaryPanel
HSeparator (existant)
[bloc chapter_timings — si non vide]
HSeparator (nouveau, ajouté seulement si chapter_timings non vide)
[nœuds orphelins — si présents]
...
```

Affiché uniquement si `chapter_timings` est non vide.

Structure visuelle :
```
-- Durée estimée par chapitre --

Chapitre 1    de 2 min 30 sec  à  5 min 15 sec
Chapitre 2    de 1 min 45 sec  à  4 min
```

- Titre de section : même style que "Noeuds orphelins" (`font_size: 15`, couleur gris clair)
- Une ligne par chapitre, couleur blanche neutre

## Tests

Les tests couvrent :

1. `_count_sequence_words` : séquence sans dialogue, avec un dialogue, avec plusieurs dialogues,
   texte contenant des retours à la ligne
2. `_compute_chapter_timings` : histoire à 1 chapitre, histoire à 2 chapitres, runs avec
   chemins de longueurs différentes, exclusion des runs `error` et `loop_detected`
3. `_format_duration` : valeur < 60 sec, valeur exacte en minutes (`"2 min"`), valeur mixte
4. `verify()` : vérifier que `chapter_timings` est présent et correct dans le rapport retourné
5. `_empty_report()` : vérifier la présence de `chapter_timings: []`
6. Intégration UI : `show_report` affiche le bloc timing quand `chapter_timings` est non vide,
   ne l'affiche pas si vide
