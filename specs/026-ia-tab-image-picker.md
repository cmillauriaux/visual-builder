# 026 — Onglet IA dans ImagePickerDialog

## Résumé

Intégrer la génération d'images par IA (ComfyUI) comme 3e onglet dans `ImagePickerDialog`, au lieu d'un dialog séparé. L'onglet hérite automatiquement du mode (BACKGROUND/FOREGROUND) du picker, ce qui garantit la sauvegarde dans le bon dossier.

## Motivation

- Simplifier le flux utilisateur : un seul point d'entrée pour toutes les sources d'images
- Supprimer le bouton "IA Foreground" de la toolbar et le `AIGenerateDialog` dédié
- L'IA peut maintenant générer des backgrounds ET des foregrounds via le même onglet

## Spécification

### Onglet IA (3e onglet de ImagePickerDialog)

L'onglet "IA" contient :
- **URL ComfyUI** (`LineEdit`) — URL du serveur ComfyUI
- **Token** (`LineEdit`, secret) — token d'authentification optionnel
- **Image source** — preview (`TextureRect`) + label chemin + bouton "Parcourir..." (ouvre un `FileDialog` natif, PAS un `ImagePickerDialog` pour éviter la récursion)
- **Prompt** (`TextEdit`) — description de l'image à générer
- **Bouton Générer** — désactivé tant que URL + prompt + source ne sont pas remplis
- **Résultat** (`TextureRect`) — aperçu de l'image générée
- **Status** (`Label`) + **Progress** (`ProgressBar`, indéterminée) — feedback de la génération
- **Boutons Accepter / Regénérer** — Accepter sauvegarde l'image dans `_get_assets_dir()` et émet `image_selected`

### Méthode publique `set_source_image(path: String)`

Permet au caller (main.gd) de pré-remplir l'image source de l'onglet IA.

### Comportement au changement d'onglet

Quand l'utilisateur navigue vers l'onglet IA, la configuration ComfyUI est chargée depuis le fichier de config.

### Annulation

Fermer le dialog ou cliquer Annuler annule toute génération en cours (cleanup du client ComfyUI).

### Sauvegarde de l'image générée

L'image est sauvegardée dans `_get_assets_dir()` (qui respecte le mode BACKGROUND/FOREGROUND) avec le préfixe `ai_` et un timestamp.

## Fichiers modifiés

| Fichier | Action |
|---------|--------|
| `src/ui/dialogs/image_picker_dialog.gd` | Ajout onglet IA |
| `src/main.gd` | Suppression AI dialog, ajout pré-remplissage source |
| `src/controllers/main_ui_builder.gd` | Suppression bouton "IA Foreground" |
| `specs/ui/dialogs/test_image_picker_dialog.gd` | Tests onglet IA |

## Fichiers supprimés

| Fichier | Raison |
|---------|--------|
| `src/ui/dialogs/ai_generate_dialog.gd` | Logique absorbée dans l'onglet IA |
| `specs/ui/dialogs/test_ai_generate_dialog.gd` | Remplacé par tests dans test_image_picker_dialog |

## Critères d'acceptation

- [ ] L'onglet IA est le 3e onglet de ImagePickerDialog (index 2)
- [ ] Les champs URL, token, prompt, source image sont présents
- [ ] Le bouton Générer est désactivé tant que URL + prompt + source ne sont pas remplis
- [ ] Le bouton Accepter est désactivé initialement
- [ ] La barre de progression est cachée initialement
- [ ] `set_source_image(path)` pré-remplit le champ source
- [ ] L'image générée est sauvegardée dans le bon dossier selon le mode
- [ ] Le signal `image_selected` est émis à l'acceptation
- [ ] Le bouton "IA Foreground" n'existe plus dans la toolbar
- [ ] Le fichier `ai_generate_dialog.gd` est supprimé
- [ ] Tous les tests passent à 100%
