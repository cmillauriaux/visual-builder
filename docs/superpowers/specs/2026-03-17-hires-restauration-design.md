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

### Pas de fichier `.tscn`

Comme tous les onglets existants, le tab est construit entièrement en GDScript (pas de scène Godot séparée).

### Ce qui est hors scope

- Pas de changement de résolution (même taille que la source, contrairement à l'Upscale tab)
- Pas de génération par lot
- Pas de sélection de modèle ESRGAN (diffusion pure uniquement)
- Pas d'historique des restaurations

## Architecture

### Nouveau fichier

`plugins/ai_studio/ai_studio_hires_tab.gd`

Suit le même pattern que `ai_studio_upscale_tab.gd` et `ai_studio_decliner_tab.gd` :
- Hérite de `RefCounted` (UI construite programmatiquement, comme tous les tabs existants)
- Reçoit une référence au `ComfyUIClient` et aux champs partagés (URL, token, negative prompt) depuis `ai_studio_dialog.gd`
- Expose les méthodes publiques requises par `ai_studio_dialog.gd` (voir ci-dessous)

### Interface publique requise

Le dialog appelle ces méthodes sur tous les tabs :

| Méthode | Description |
|---------|-------------|
| `update_generate_button()` | Active/désactive le bouton Restaurer selon l'état de connexion |
| `update_cfg_hint()` | Met à jour le hint du slider CFG (applicable car CFG est exposé) |
| `cancel_generation()` | Annule toute génération en cours ; appelé par `_on_close()` du dialog |

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

`plugin.gd` **ne nécessite pas de modification** — l'ajout du tab se fait entièrement dans `ai_studio_dialog.gd`.

## Interface utilisateur

### Layout (deux colonnes via HBoxContainer)

Le tab Restauration utilise un layout deux colonnes (HBoxContainer), contrairement aux autres tabs qui sont en VBoxContainer. Ce choix est justifié par la nécessité d'afficher paramètres et résultat en vis-à-vis, pour que l'utilisateur puisse comparer visuellement avant d'accepter.

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
| Vide | Sélecteur source + paramètres actifs, zone résultat vide |
| En cours | Spinner/progress dans la zone résultat, bouton "Annuler" (paramètres désactivés) |
| Terminé | Image résultat + boutons Accepter/Rejeter/Regénérer |
| Erreur | Message d'erreur dans la zone résultat, bouton Regénérer actif, paramètres réactivés |
| Accepté | Reset vers état Vide (sélecteur source vidé) |

**État Erreur :** affiché quand ComfyUI est injoignable ou retourne une erreur. Correspond au signal `generation_failed` du `ComfyUIClient`. Boutons Accepter/Rejeter masqués ; bouton Regénérer visible. Message d'erreur affiché dans la zone résultat.

**État Annulé :** cliquer "Annuler" pendant "En cours" → appel `cancel_generation()` → reset vers état Vide. Aucune modification du fichier source.

## Comportement "Accepter et remplacer"

**Pré-condition :** le backup doit réussir avant toute écriture sur la source.

1. Vérifier qu'un fichier `{nom}_original.png` n'existe pas déjà dans le même dossier
   - S'il n'existe pas → copier l'original vers `{nom}_original.png`
   - S'il existe déjà → ne pas l'écraser (protège le vrai original)
2. **Si la copie backup échoue** (disque plein, permission refusée, etc.) → afficher une erreur, **ne pas écraser la source**, rester en état Terminé
3. Écraser le fichier source avec l'image restaurée (PNG)
4. Vider le sélecteur source (reset état Vide)
5. Afficher une confirmation brève

**Exemple :**
- Source : `assets/foregrounds/perso_001.png`
- Backup créé : `assets/foregrounds/perso_001_original.png`
- Fichier remplacé : `assets/foregrounds/perso_001.png`
- Après acceptation : tab repart en état Vide (sélecteur source vide)

"Rejeter" ou fermer le dialog → aucune modification du disque.

## Tests

Fichiers à créer/modifier :
- `specs/plugins/ai_studio/test_ai_studio_hires_tab.gd` — tests unitaires du tab (sélection source, génération, états, backup réussi, backup échoué, remplacement, annulation, cancel_generation)
- `specs/services/test_comfyui_client.gd` — ajouter tests pour `WorkflowType.HIRES`
- `specs/plugins/ai_studio/test_ai_studio_plugin.gd` — vérifier que le 4e tab est bien instancié dans le dialog

## Fichiers à modifier

| Fichier | Modification |
|---------|-------------|
| `plugins/ai_studio/ai_studio_dialog.gd` | Instancier et câbler `HiResTab` |
| `src/services/comfyui_client.gd` | Ajouter `WorkflowType.HIRES` + template workflow |
| `specs/services/test_comfyui_client.gd` | Ajouter tests pour `WorkflowType.HIRES` |
| `specs/plugins/ai_studio/test_ai_studio_plugin.gd` | Vérifier instanciation du 4e tab |

## Fichiers à créer

| Fichier | Rôle |
|---------|------|
| `plugins/ai_studio/ai_studio_hires_tab.gd` | Logique et UI de l'onglet Restauration |
| `specs/plugins/ai_studio/test_ai_studio_hires_tab.gd` | Tests GUT du nouvel onglet |
