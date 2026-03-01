# 027 — Verificateur d'histoire

## Objectif

Permettre a l'auteur de verifier automatiquement que son histoire est coherente :
- Tous les chemins possibles menent a une terminaison valide (game_over ou to_be_continued)
- Tous les noeuds (sequences + conditions) sont atteignables
- Identifier les noeuds orphelins et les scenarios qui n'aboutissent pas

## Algorithme

### Simulation realiste

Le verificateur simule plusieurs parcours complets de l'histoire :
1. Les variables sont initialisees aux valeurs par defaut de la story
2. Les conditions sont evaluees normalement avec l'etat des variables
3. Les effets (choice effects + consequence effects) sont appliques
4. A chaque point de choix, le verificateur essaie une option differente des runs precedents

### Boucle multi-runs

```
verify(story):
  all_nodes = collecter tous les noeuds (sequences + conditions) de toute l'histoire
  visited_nodes = {}
  choice_history = {}  # sequence_uuid -> set de choice_index deja essayes
  runs = []

  Pour chaque run (max 100):
    result = simuler_run(story, choice_history)
    Marquer les noeuds visites
    Si tous les noeuds visites ET plus de choix non essayes: arreter
    Si plus de choix non essayes: arreter

  Construire le rapport
```

### Simulation d'un run

Chaque run reprend la logique de `story_play_controller.gd` en synchrone :
1. Trouver le chapitre d'entree (entry_point_uuid ou fallback position)
2. Trouver la scene d'entree du chapitre
3. Trouver le noeud d'entree de la scene (sequence ou condition)
4. Boucle de traversee (max 10000 steps) :
   - Si condition : evaluer avec les variables, resoudre la consequence
   - Si sequence : verifier l'ending
     - `auto_redirect` : resoudre la consequence automatique
     - `choices` : choisir un choix non encore essaye (via choice_history)
   - Appliquer les effets avant chaque resolution
5. Detection de boucle : cle composite `uuid + "|" + variables_serialisees`
6. Fin : game_over, to_be_continued, error, no_ending, ou loop_detected

### Selection de choix

```
pick_choice(sequence_uuid, nb_choix, choice_history):
  Pour chaque index de 0 a nb_choix-1:
    Si cet index n'a pas encore ete essaye pour cette sequence: le choisir
  Si tous essayes: choisir 0 (round-robin)
```

## Modele de rapport

```gdscript
{
  "success": bool,        # true si tous les runs valides ET aucun orphelin
  "runs": [               # Liste des parcours simules
    {
      "run_index": int,
      "path": [           # Chemin emprunte
        {"uuid": String, "name": String, "type": "sequence"|"condition"|"choice", "choice_index": int}
      ],
      "ending_reason": String,  # game_over, to_be_continued, error, no_ending, loop_detected
      "is_valid": bool          # true si game_over ou to_be_continued
    }
  ],
  "orphan_nodes": [       # Noeuds jamais visites
    {"uuid": String, "name": String, "type": "sequence"|"condition", "chapter": String, "scene": String}
  ],
  "total_runs": int,
  "all_nodes": int,
  "visited_nodes": int
}
```

## Interface utilisateur

### Bouton

- Texte : "Verifier l'histoire"
- Visible uniquement au niveau `chapters` (vue histoire)
- Place dans la top bar avec les autres boutons d'action

### Panel de rapport

Panel dedie dans la zone de contenu (meme pattern que condition_editor_panel) :

```
HBoxContainer (header)
  Label "Rapport de verification"
  [spacer]
  Label statut (vert/rouge)
  Button "Fermer"
HSeparator
ScrollContainer
  VBoxContainer
    PanelContainer (resume)
      Label "Resultat: Succes/Echec"
      Label "Noeuds visites: X / Y"
      Label "Parcours effectues: N"
    HSeparator
    Section "Noeuds orphelins" (si presents)
      Liste avec nom + chapitre/scene
    HSeparator
    Section "Parcours"
      Pour chaque run: statut + chemin detaille
```

### Couleurs

- Vert : terminaisons valides (game_over, to_be_continued)
- Rouge : terminaisons invalides (error, no_ending, loop_detected)
- Orange : noeuds orphelins

## Fichiers

| Fichier | Role |
|---------|------|
| `src/services/story_verifier.gd` | Moteur de verification (RefCounted) |
| `src/ui/editors/verifier_report_panel.gd` | Panel de rapport |
| `specs/services/test_story_verifier.gd` | Tests unitaires moteur |
| `specs/ui/editors/test_verifier_report_panel.gd` | Tests panel |
| `specs/integration/test_story_verifier_integration.gd` | Tests integration |

## Criteres d'acceptation

- [x] Le bouton "Verifier l'histoire" est visible au niveau chapters uniquement
- [x] Le verificateur simule plusieurs parcours avec des choix differents
- [x] Les variables et conditions sont evaluees de maniere realiste
- [x] Les boucles infinies sont detectees (detection par etat + garde max steps)
- [x] Le rapport identifie les noeuds orphelins avec leur localisation (chapitre/scene)
- [x] Le rapport identifie les parcours qui n'aboutissent pas a une fin valide
- [x] Le panel de rapport est scrollable et affiche toutes les informations
- [x] Le bouton "Fermer" du panel restaure la vue normale
- [x] Tous les tests passent
