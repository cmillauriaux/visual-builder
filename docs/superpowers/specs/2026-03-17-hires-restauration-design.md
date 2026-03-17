# Design — Onglet "Restauration" (HiRes Fix) dans le Studio IA

**Date :** 2026-03-17
**Statut :** Approuvé

## Contexte et problème

Les onglets "Décliner" et "Expressions" produisent des images avec artefacts, bruit et pixelisation. Lorsqu'on reprend ces sorties pour une nouvelle déclinaison, la qualité se dégrade davantage. Il faut un moyen de restaurer les détails d'une image existante avant de la réutiliser.

## Objectif

Ajouter un 4e onglet "Restauration" dans le Studio IA permettant de :
- Charger une image source (importée ou depuis la galerie)
- Lancer un pass img2img (même résolution, diffusion pure) pour restaurer les détails et supprimer les artefacts
- Prévisualiser le résultat en plein écran avant de décider
- Remplacer le fichier source par le résultat, avec backup automatique de l'original

## Décisions de design

### Approche retenue : Nouvel onglet dédié (Option A)

Un 4e onglet indépendant dans `ai_studio_dialog.gd`, avec son propre fichier GDScript. Pas de modification des onglets existants.

**Raison :** cohérent avec l'architecture modulaire existante, aucun impact sur l'Upscale tab.

### Ce qui est hors scope

- Pas de changement de résolution (même taille que la source, contrairement à l'Upscale tab)
- Pas de génération par lot
- Pas de sélection de modèle ESRGAN (diffusion pure uniquement)
- Pas d'historique des restaurations

## Architecture

### Nouveau fichier

`plugins/ai_studio/ai_studio_hires_tab.gd`

Suit le même pattern que `ai_studio_upscale_tab.gd` et `ai_studio_decliner_tab.gd` :
- Hérite de `VBoxContainer` (ou `Control`)
- Reçoit une référence au `ComfyUIClient` et aux champs partagés (URL, token, negative prompt) depuis `ai_studio_dialog.gd`
- Émet des signaux standards vers le dialog parent

### Nouveau workflow ComfyUI

Ajout de `WorkflowType.HIRES` dans `src/services/comfyui_client.gd`.

Paramètres du workflow :
- Image uploadée (multipart, comme les autres workflows)
- `positive_prompt` (string)
- `negative_prompt` (string, depuis le champ global du dialog)
- `cfg` (float, 1.0–30.0)
- `steps` (int, 1–50)
- `denoise` (float, 0.0–1.0)
- Pas de paramètre de taille — le workflow retourne la même résolution que l'entrée

### Intégration dans le dialog

Dans `ai_studio_dialog.gd`, instancier le tab Restauration de la même façon que les tabs existants (lignes ~134–147). Le tab partage les champs globaux : URL, token, negative prompt.

## Interface utilisateur

### Layout (deux colonnes)

**Colonne gauche — Paramètres :**
- Sélecteur d'image source : miniature + boutons "Importer…" et "Galerie…" + nom/dimensions affichés
- Champ Prompt de restauration (TextEdit multiline)
- Slider CFG (1.0–30.0, défaut 7.0)
- Slider Steps (1–50, défaut 25)
- Slider Denoise (0.0–1.0, défaut 0.3) avec légende "0.0 = fidèle à la source · 1.0 = libre"
- Bouton "✨ Restaurer"

**Colonne droite — Résultat :**
- Zone de prévisualisation cliquable (ouvre `ImagePreviewPopup` plein écran)
- Dimensions affichées (confirmant que la résolution est identique à la source)
- Bouton "✓ Accepter et remplacer" (vert)
- Bouton "✕ Rejeter"
- Note informative sur le backup : `nom_fichier_original.png`
- Bouton "🔄 Regénérer"

### États du tab

| État | UI visible |
|------|-----------|
| Vide | Sélecteur source + paramètres, zone résultat vide |
| En cours | Spinner/progress dans la zone résultat, bouton "Annuler" |
| Terminé | Image résultat + boutons Accepter/Rejeter/Regénérer |
| Accepté | Reset vers état Vide (source mise à jour) |

## Comportement "Accepter et remplacer"

1. Vérifier qu'un fichier `{nom}_original.png` n'existe pas déjà dans le même dossier
   - S'il n'existe pas → copier l'original vers `{nom}_original.png`
   - S'il existe déjà → ne pas l'écraser (protège le vrai original)
2. Écraser le fichier source avec l'image restaurée (PNG)
3. Mettre à jour la miniature dans le sélecteur source
4. Afficher une confirmation dans l'interface

**Exemple :**
- Source : `assets/foregrounds/perso_001.png`
- Backup créé : `assets/foregrounds/perso_001_original.png`
- Fichier remplacé : `assets/foregrounds/perso_001.png`

"Rejeter" ou fermer le dialog → aucune modification du disque.

## Tests

Fichiers à créer/modifier :
- `specs/plugins/ai_studio/test_ai_studio_hires_tab.gd` — tests unitaires du tab (sélection source, génération, backup, remplacement)
- `specs/services/test_comfyui_client.gd` — ajouter tests pour `WorkflowType.HIRES`
- `specs/plugins/ai_studio/test_ai_studio_dialog.gd` — vérifier que le 4e tab est bien instancié

## Fichiers à modifier

| Fichier | Modification |
|---------|-------------|
| `plugins/ai_studio/ai_studio_dialog.gd` | Instancier et câbler `HiResTab` |
| `src/services/comfyui_client.gd` | Ajouter `WorkflowType.HIRES` + template workflow |
| `plugins/ai_studio/plugin.gd` | Si nécessaire, exposer le nouveau tab |

## Fichiers à créer

| Fichier | Rôle |
|---------|------|
| `plugins/ai_studio/ai_studio_hires_tab.gd` | Logique et UI de l'onglet Restauration |
| `specs/plugins/ai_studio/test_ai_studio_hires_tab.gd` | Tests GUT du nouvel onglet |
