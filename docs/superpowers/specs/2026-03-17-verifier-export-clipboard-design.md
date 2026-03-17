# Spec : Export et Copie du Rapport de Vérification

**Date** : 2026-03-17
**Statut** : Approuvé

## Contexte

Le panneau de vérification d'histoire (`verifier_report_panel.gd`) affiche un rapport riche après l'analyse de la story. L'utilisateur a besoin de partager ce rapport avec un LLM pour corriger les problèmes détectés. Deux boutons sont ajoutés en haut à droite de la fenêtre : **Exporter** (sauvegarde en `.txt`) et **Copier** (presse-papier).

## Architecture

### Nouveau fichier : `src/services/story_verifier_formatter.gd`

Classe `StoryVerifierFormatter` — responsabilité unique : transformer un dictionnaire de rapport en texte lisible par un humain/LLM.

**Interface publique :**

```gdscript
class_name StoryVerifierFormatter

func format(report: Dictionary) -> String
```

Aucune dépendance UI. Testable unitairement de façon isolée.

### Modifications : `src/ui/editors/verifier_report_panel.gd`

- Instancie `StoryVerifierFormatter` comme **variable membre** (`var _formatter := StoryVerifierFormatter.new()`), une seule fois dans `_ready()`
- Ajoute deux boutons dans le header HBoxContainer, entre le `StatusLabel` et le bouton "Fermer" :
  - **"Exporter"** (`Button`) — déclenche export fichier
  - **"Copier"** (`Button`) — copie dans le presse-papier
- Stocke la référence au rapport courant dans `_report: Dictionary` (initialisé à `{}`, mis à jour en début de `show_report()`)

## Format du texte généré

```
=== RAPPORT DE VÉRIFICATION ===
Résultat : SUCCÈS
Nœuds visités : 12 / 15
Parcours effectués : 8

--- DURÉE ESTIMÉE PAR CHAPITRE ---
  Chapitre 1 (Suite) : de 3 min 20 sec à 5 min 10 sec
  Chapitre 1 (Game Over) : de 1 min 5 sec à 2 min 30 sec

--- NŒUDS ORPHELINS (1) ---
  [Sequence] Intro abandonnee  (Chapitre 1 > Scene 2)

--- PARCOURS ---
Parcours #1 : VALIDE — A suivre...
    Sequence de bienvenue
    -> Choix: Partir a gauche
    Sequence Foret

Parcours #2 : INVALIDE — Boucle infinie detectee
    ...
```

Règles de formatage :
- **Encodage** : le texte exporté n'utilise pas d'accents (correspondance avec le panel existant qui n'en utilise pas). Ex : `"Sequence"` et non `"Séquence"`, `"a"` et non `"à"`.
- Sections absentes si vides (pas d'orphelins → pas de section orphelins, pas de timings → pas de section durées)
- Durées formatées identiquement à `_format_duration` existant : `X min Y sec`, `X min`, `X sec` (jamais `< 1 sec` — valeur sub-seconde donne `"0 sec"`). Format de ligne timing : `"  <chapitre> (Suite) : de <min> a <max>"` et `"  <chapitre> (Game Over) : de <min> a <max>"`
- En-tête de parcours : le label `VALIDE` / `INVALIDE` est un **enrichissement textuel absent du panel UI** (le panel utilise uniquement une couleur verte/rouge). Il est ajouté ici pour aider un LLM à identifier les parcours problématiques. Dérivé du champ `is_valid` du run :
  - `is_valid == true` → `"VALIDE"`
  - `is_valid == false` → `"INVALIDE"`
  - Note : `game_over` et `to_be_continued` sont tous deux `is_valid=true` ; `error`, `no_ending`, `loop_detected` sont `is_valid=false`
  - Format complet : `"Parcours #N : VALIDE — <raison>"` ou `"Parcours #N : INVALIDE — <raison>"`
  - Mapping des raisons (identique au panel) :
    - `"game_over"` → `"Game Over"`
    - `"to_be_continued"` → `"A suivre..."`
    - `"error"` → `"Erreur (cible introuvable)"`
    - `"no_ending"` → `"Pas de terminaison"`
    - `"loop_detected"` → `"Boucle infinie detectee"`
    - Valeur inconnue → affichée telle quelle
- Étapes d'un parcours — utiliser `step["name"]` verbatim avec le même préfixe que le panel :
  - `type == "choice"` → `"    -> %s"` (le `name` contient déjà `"Choix: texte"`)
  - `type == "condition"` → `"    [Condition] %s"`
  - autres → `"    %s"`
- Type d'orphelin affiché entre crochets : `[Sequence]` (type `"sequence"`) ou `[Condition]` (type `"condition"`)

## Comportement des boutons

### Bouton "Exporter"

1. Appelle `StoryVerifierFormatter.format(_report)`
2. Ouvre un `FileDialog` en mode `FILE_MODE_SAVE_FILE`
   - Filtre : `*.txt`
   - Nom de fichier par défaut : `rapport_verification.txt`
3. Sur confirmation : écrit le texte via `FileAccess.open(path, FileAccess.WRITE)` — en cas d'échec d'écriture, l'erreur est silencieusement ignorée
4. Le `FileDialog` est ajouté comme enfant du panneau et libéré avec `queue_free()` après confirmation **et** après annulation (signal `canceled`)

### Bouton "Copier"

1. Appelle `StoryVerifierFormatter.format(_report)`
2. Appelle `DisplayServer.clipboard_set(text)`
3. Aucun retour visuel requis (comportement standard OS)

## Layout du header

```
HBoxContainer (Header)
├─ Label "Rapport de vérification"  (font_size=18)
├─ Control (spacer, SIZE_EXPAND_FILL)
├─ Label (StatusLabel)              "SUCCÈS" (vert) / "ÉCHEC" (rouge)
├─ Button "Exporter"
├─ Button "Copier"
└─ Button "Fermer"
```

## Tests

### `specs/services/test_story_verifier_formatter.gd`

Cas couverts :
- Rapport de succès minimal (aucun orphelin, aucune durée) → entête contient "SUCCÈS", visited/all/total_runs corrects
- Rapport d'échec → entête contient "ÉCHEC"
- Avec orphelins → section `--- NOEUDS ORPHELINS (N) ---` présente, chaque ligne au format `  [Sequence] Nom  (Chapitre > Scene)`
- Sans orphelins → section orphelins absente du texte
- Avec timings → section `--- DURÉE ESTIMÉE PAR CHAPITRE ---` présente, format `X min Y sec`
- Sans timings → section durées absente du texte
- Parcours valide `to_be_continued` (`is_valid=true`) → ligne `"Parcours #1 : VALIDE — A suivre..."`
- Parcours valide `game_over` (`is_valid=true`) → ligne `"Parcours #1 : VALIDE — Game Over"`
- Parcours invalide `loop_detected` (`is_valid=false`) → ligne `"Parcours #1 : INVALIDE — Boucle infinie detectee"`
- Parcours invalide `error` (`is_valid=false`) → ligne `"Parcours #1 : INVALIDE — Erreur (cible introuvable)"`
- Parcours invalide `no_ending` (`is_valid=false`) → ligne `"Parcours #1 : INVALIDE — Pas de terminaison"`
- Étape de type `choice` → ligne `"    -> Choix: texte du choix"`
- Étape de type `condition` → ligne `"    [Condition] nom_condition"`
- Étape de type `sequence` → ligne `"    nom_sequence"`
- Avec orphelins → section `--- NOEUDS ORPHELINS (N) ---` présente, chaque ligne au format `  [Sequence] Nom  (Chapitre > Scene)`
- Rapport vide `{}` → ne crashe pas, retourne au moins l'entête `=== RAPPORT DE VÉRIFICATION ===`

### `specs/ui/editors/test_verifier_report_panel.gd` (existant — à étendre)

Cas ajoutés :
- Panel possède un bouton "Exporter" dans le header
- Panel possède un bouton "Copier" dans le header
- Clic "Copier" après `show_report()` → presse-papier contient le texte du rapport (vérifiable via `DisplayServer.clipboard_get()`)
- Clic "Copier" sans appel préalable à `show_report()` → ne crashe pas (rapport vide `{}`)

## Fichiers impactés

| Fichier | Statut |
|---|---|
| `src/services/story_verifier_formatter.gd` | Nouveau |
| `src/ui/editors/verifier_report_panel.gd` | Modifié |
| `specs/services/test_story_verifier_formatter.gd` | Nouveau |
| `specs/ui/editors/test_verifier_report_panel.gd` | Modifié |

## Critères d'acceptation

- [x] Le bouton "Exporter" ouvre une boîte de dialogue de sauvegarde avec filtre `.txt`
- [x] Le fichier exporté contient le rapport complet en texte lisible
- [x] Le `FileDialog` est libéré (`queue_free`) après confirmation et après annulation
- [x] Le bouton "Copier" place le rapport dans le presse-papier système
- [x] Cliquer "Copier" ou "Exporter" sans rapport chargé ne produit pas d'erreur
- [x] `StoryVerifierFormatter` n'a aucune dépendance UI (pas de Node, pas de Control)
- [x] Tous les tests passent
