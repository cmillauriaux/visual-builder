# Sélection du workflow IA (Création / Expression)

## Résumé

Ajout d'un sélecteur de workflow dans l'onglet IA du dialog image picker. Deux workflows disponibles :
- **Création** : workflow existant (Flux 2 Klein + BiRefNet) — génération d'images à partir d'un prompt
- **Expression** : nouveau workflow (Flux 2 Klein + edit d'expression faciale + BiRefNet) — modification d'expression sur une image source

## Architecture

### Fichiers modifiés

| Fichier | Modification |
|---------|-------------|
| `src/services/comfyui_client.gd` | Ajout `EXPRESSION_WORKFLOW_TEMPLATE`, enum `WorkflowType`, support workflow_type dans `build_workflow()` et `generate()` |
| `src/ui/dialogs/image_picker_dialog.gd` | Ajout d'un `OptionButton` pour choisir le workflow dans l'onglet IA |

## Workflow Expression

Le workflow Expression est basé sur Flux 2 Klein en mode img2img edit. Il :
1. Charge l'image source et l'encode en latent via VAE
2. Applique un prompt fixe "keep everything same" + le prompt utilisateur (expression à changer)
3. Utilise ReferenceLatent pour guider la génération depuis l'image source
4. Applique BiRefNetRMBG pour le fond transparent (foreground mode uniquement)

### Paramètres dynamiques

| Noeud | Champ | Paramètre |
|-------|-------|-----------|
| `1` | `inputs.image` | Nom du fichier uploadé |
| `9` | `inputs.text` | Prompt utilisateur (description de l'expression) |
| `16` | `inputs.noise_seed` | Seed aléatoire |
| `17` | `inputs.cfg` | Valeur CFG |
| `15` | `inputs.steps` | Nombre de steps |

### Post-traitement (noeuds 21-24)

Pipeline après le VAEDecode (noeud `19`) :
1. **Noeud 21** `ImageScale` — redimensionne l'image générée à la taille exacte de l'originale
2. **Noeud 22** `ImageBlend` — mélange l'originale (scaled) avec la générée à 20% d'opacité pour stabiliser
3. **Noeud 23** `ColorMatch` — harmonise les couleurs/luminosité du résultat avec l'image de référence
4. **Noeud 24** `BiRefNetRMBG` — supprime le fond (foreground mode uniquement)

En mode background, le noeud RMBG (24) est retiré et SaveImage pointe vers ColorMatch (23).

## UI

### Sélecteur de workflow

`OptionButton` ajouté dans l'onglet IA, entre le token et l'image source :
- Item 0 : "Création" (défaut)
- Item 1 : "Expression"

Le sélecteur est désactivé pendant la génération (comme les autres inputs).

## Critères d'acceptation

- [ ] Un sélecteur de workflow apparaît dans l'onglet IA
- [ ] Le sélecteur propose "Création" et "Expression"
- [ ] "Création" est sélectionné par défaut
- [ ] Le workflow Expression utilise le bon template avec RMBG
- [ ] Les paramètres dynamiques (prompt, seed, cfg, steps, image) sont correctement mappés
- [ ] Le sélecteur est désactivé pendant la génération
- [ ] Le mode background retire le noeud RMBG du workflow Expression
- [ ] Tests couvrent le nouveau workflow et le sélecteur UI
