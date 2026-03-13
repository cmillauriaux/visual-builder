# Spec 068 — Mode de flip pour les foregrounds

## Contexte

Dans l'editeur de sequence, quand un foreground est selectionne, le panneau de proprietes (`transition_panel`) affiche les options de fondu, duree et z-order. Les proprietes `flip_h` et `flip_v` existent deja dans le modele `Foreground` et sont appliquees visuellement, mais aucun controle UI ne permet de les modifier depuis l'editeur.

## Objectif

Ajouter un menu deroulant "Flip" dans le panneau de proprietes du foreground selectionne, avec 4 options :
- **Aucun** (defaut) — pas de retournement
- **Horizontal** — retournement gauche/droite (`flip_h = true`)
- **Vertical** — retournement haut/bas (`flip_v = true`)
- **Les deux** — retournement horizontal et vertical (`flip_h = true, flip_v = true`)

## Architecture

### Fichiers modifies

| Fichier | Modification |
|---------|-------------|
| `src/ui/sequence/transition_panel.gd` | Ajout OptionButton "Flip" avec 4 options, getters/setters, mise a jour du foreground |
| `specs/ui/sequence/test_transition_panel.gd` | Tests unitaires pour le flip |

### Fichiers crees

| Fichier | Role |
|---------|------|
| `specs/068-foreground-flip.md` | Cette specification |

## Details techniques

### OptionButton Flip

L'OptionButton est ajoute dans la meme ligne (HBoxContainer) que les autres controles, avec un label "Flip :".

Les 4 options correspondent a des combinaisons de `flip_h` et `flip_v` :

| Index | Label | flip_h | flip_v |
|-------|-------|--------|--------|
| 0 | Aucun | false | false |
| 1 | Horizontal | true | false |
| 2 | Vertical | false | true |
| 3 | Les deux | true | true |

### Methodes ajoutees

- `get_displayed_flip() -> int` — retourne l'index selectionne (0-3)
- `set_flip(flip_index: int)` — met a jour le foreground et l'OptionButton

### Signal

Le signal `transition_changed` existant est emis lors du changement de flip, comme pour les autres proprietes.

### Mapping flip_h/flip_v vers index

Dans `show_for_foreground()`, l'index est calcule a partir de `fg.flip_h` et `fg.flip_v` :
- `index = (1 if flip_h else 0) + (2 if flip_v else 0)`

## Criteres d'acceptation

- [ ] OptionButton "Flip" visible dans le panneau de proprietes du foreground
- [ ] 4 options : Aucun, Horizontal, Vertical, Les deux
- [ ] Valeur par defaut : Aucun (index 0)
- [ ] Changement met a jour `fg.flip_h` et `fg.flip_v` sur le foreground
- [ ] Affichage correct de l'etat actuel du foreground a l'ouverture
- [ ] Signal `transition_changed` emis lors du changement
- [ ] Les tests GUT passent
