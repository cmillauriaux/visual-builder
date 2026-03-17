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

- Instancie `StoryVerifierFormatter`
- Ajoute deux boutons dans le header HBoxContainer, entre le `StatusLabel` et le bouton "Fermer" :
  - **"Exporter"** (`Button`) — déclenche export fichier
  - **"Copier"** (`Button`) — copie dans le presse-papier
- Stocke la référence au rapport courant dans `_report: Dictionary`

## Format du texte généré

```
=== RAPPORT DE VÉRIFICATION ===
Résultat : SUCCÈS
Nœuds visités : 12 / 15
Parcours effectués : 8

--- DURÉE ESTIMÉE PAR CHAPITRE ---
  Chapitre 1 (Suite) : de 3 min 20 sec à 5 min 10 sec
  Chapitre 1 (Game Over) : de 1 min 5 sec à 2 min 30 sec

--- NŒUDS ORPHELINS (2) ---
  [Séquence] Intro abandonnée  (Chapitre 1 > Scène 2)

--- PARCOURS ---
Parcours #1 : VALIDE (suite)
    Séquence : Intro
    -> Choix : Partir à gauche
    Séquence : Forêt
    ...

Parcours #2 : INVALIDE (loop_detected)
    ...
```

Règles de formatage :
- Sections absentes si vides (pas d'orphelins → pas de section orphelins, pas de timings → pas de section durées)
- Durées formatées `X min Y sec` (ou `< 1 sec` si inférieur à 1 seconde)
- Type de nœud affiché entre crochets : `[Séquence]`, `[Condition]`
- Choix préfixés par `-> Choix :`
- Raison de fin de parcours entre parenthèses : `suite`, `game_over`, `erreur`, `pas_de_fin`, `boucle_détectée`

## Comportement des boutons

### Bouton "Exporter"

1. Appelle `StoryVerifierFormatter.format(_report)`
2. Ouvre un `FileDialog` en mode `FILE_MODE_SAVE_FILE`
   - Filtre : `*.txt`
   - Nom de fichier par défaut : `rapport_verification.txt`
3. Sur confirmation : écrit le texte via `FileAccess.open(path, FileAccess.WRITE)`
4. Le `FileDialog` est ajouté comme enfant du panneau et libéré après usage

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
- Rapport de succès minimal (aucun orphelin, aucune durée) → entête correct
- Rapport d'échec → "ÉCHEC" dans le texte
- Avec orphelins → section orphelins présente avec bon contenu
- Sans orphelins → section orphelins absente
- Avec timings → section durées présente, formatage `X min Y sec` correct
- Sans timings → section durées absente
- Parcours valide (suite) → libellé "VALIDE (suite)"
- Parcours invalide (loop_detected) → libellé "INVALIDE (boucle_détectée)"
- Choix dans un parcours → préfixe `-> Choix :`
- Condition dans un parcours → préfixe `[Condition]`

### `specs/ui/editors/test_verifier_report_panel.gd` (existant — à étendre)

Cas ajoutés :
- Panel possède un bouton "Exporter" dans le header
- Panel possède un bouton "Copier" dans le header
- Clic "Copier" après `show_report()` → presse-papier contient le texte du rapport (vérifiable via `DisplayServer.clipboard_get()`)

## Fichiers impactés

| Fichier | Statut |
|---|---|
| `src/services/story_verifier_formatter.gd` | Nouveau |
| `src/ui/editors/verifier_report_panel.gd` | Modifié |
| `specs/services/test_story_verifier_formatter.gd` | Nouveau |
| `specs/ui/editors/test_verifier_report_panel.gd` | Modifié |

## Critères d'acceptation

- [ ] Le bouton "Exporter" ouvre une boîte de dialogue de sauvegarde avec filtre `.txt`
- [ ] Le fichier exporté contient le rapport complet en texte lisible
- [ ] Le bouton "Copier" place le rapport dans le presse-papier système
- [ ] `StoryVerifierFormatter` n'a aucune dépendance UI (pas de Node, pas de Control)
- [ ] Tous les tests passent
