# Générer un foreground avec l'IA (ComfyUI)

## Résumé

Ajout d'un bouton "Générer avec l'IA" dans la toolbar de l'éditeur de séquence. Ce bouton ouvre un dialogue qui permet de générer des foregrounds avec fond transparent via ComfyUI (Flux 2 Klein + BiRefNet) à partir d'une image source et d'un prompt texte.

## Architecture

### Nouveaux fichiers

| Fichier | Rôle |
|---------|------|
| `src/services/comfyui_config.gd` | Persistance URL et token ComfyUI (`user://comfyui_config.cfg`) via `ConfigFile` |
| `src/services/comfyui_client.gd` | Client HTTP ComfyUI (extends Node) : upload, prompt, poll, download |
| `src/ui/ai_generate_dialog.gd` | Dialog UI complète (config + prompt + preview + accept) |

### Fichier modifié

- `src/main.gd` — Ajout du bouton dans la toolbar et handlers associés.

## Persistance de la configuration

### `comfyui_config.gd`

Utilise `ConfigFile` pour persister dans `user://comfyui_config.cfg` :
- `comfyui/url` : URL du serveur ComfyUI (défaut : `"http://localhost:8188"`)
- `comfyui/token` : Token d'authentification (défaut : `""`)

API :
- `get_url() -> String`
- `set_url(url: String) -> void`
- `get_token() -> String`
- `set_token(token: String) -> void`
- `get_full_url(endpoint: String) -> String` — construit l'URL complète avec token si présent

## Client HTTP ComfyUI

### `comfyui_client.gd` extends `Node`

Le client utilise des noeuds `HTTPRequest` enfants pour les appels réseau.

#### Signaux

- `generation_completed(image: Image)` — image générée reçue
- `generation_failed(error: String)` — erreur pendant la génération
- `generation_progress(status: String)` — mise à jour du statut

#### Séquence HTTP

1. **Upload** : `POST /upload/image` — multipart form data (body construit manuellement avec `request_raw()`)
2. **Prompt** : `POST /prompt` — JSON `{"prompt": workflow_dict}` → reçoit `prompt_id`
3. **Poll** : `GET /history/{prompt_id}` — polling toutes les 1.5s via Timer
4. **Download** : `GET /view?filename=X&type=output` — télécharge les bytes PNG

#### Authentification

Le token est envoyé via le header `Authorization: Bearer <token>` sur chaque requête HTTP. Cela évite les problèmes de redirect 302 avec les proxies comme Caddy qui convertissent les query parameters en cookies.

#### Workflow template

Dictionnaire `const` statique dans le fichier. 3 paramètres dynamiques :
- Noeud `76` → nom du fichier uploadé
- Noeud `75:74` → texte du prompt
- Noeud `75:73` → seed aléatoire (entier)

#### Méthodes publiques

- `generate(config: RefCounted, source_image_path: String, prompt_text: String) -> void` — lance la génération complète
- `cancel() -> void` — annule la génération en cours
- `build_workflow(filename: String, prompt_text: String, seed: int) -> Dictionary` — construit le workflow (testable)
- `build_multipart_body(filename: String, file_bytes: PackedByteArray) -> Array` — retourne `[body_bytes, boundary]`

## Dialog UI

### `ai_generate_dialog.gd` extends `Window`

Popup modale 700x600.

#### Layout

```
Window (popup 700x600)
  VBoxContainer
    [URL ComfyUI]     LineEdit (pré-rempli depuis config)
    [Token]           LineEdit (pré-rempli depuis config, secret=true)
    [Image source]    HBox: TextureRect + Label path + Button "Choisir..."
    [Prompt]          TextEdit (multi-ligne, 3 lignes)
    [Générer]         Button
    ---
    [Résultat]        TextureRect (preview du résultat)
    [Status]          Label + ProgressBar (indeterminate)
    [Accepter]        Button → sauve PNG + émet signal
    [Regénérer]       Button → relance avec nouveau seed
```

#### Comportement

- **Pré-remplissage** : si un foreground est sélectionné dans l'éditeur visuel, son chemin image est passé au dialogue.
- **Configuration** : URL et token sont sauvegardés quand l'utilisateur lance la génération.
- **Génération** : désactive le bouton Générer, affiche la ProgressBar, attend le résultat.
- **Accepter** : sauve l'Image en PNG dans `user://stories/<nom>/assets/foregrounds/ai_<timestamp>.png`, émet `foreground_accepted(path)`.
- **Regénérer** : relance la génération avec un nouveau seed aléatoire.

#### Signaux

- `foreground_accepted(image_path: String)` — émis quand l'utilisateur accepte l'image générée

## Intégration dans main.gd

### Toolbar

Ajout d'un bouton "IA Foreground" après le bouton "+ Foreground" dans la toolbar de séquence.

### Handlers

- `_on_ai_generate_pressed()` : ouvre le dialogue AI, pré-remplit l'image source si un foreground est sélectionné.
- `_on_ai_fg_accepted(image_path)` : appelle `_sequence_editor_ctrl.add_foreground_to_current("", image_path)` puis met à jour la preview.

### Intégration système foreground

1. "Accepter" sauve l'Image en PNG dans `user://stories/<nom>/assets/foregrounds/ai_<timestamp>.png`
2. Émet `foreground_accepted(path)`
3. `main.gd` appelle `_sequence_editor_ctrl.add_foreground_to_current("", path)`
4. `_load_texture()` dans `sequence_visual_editor.gd` charge déjà les fichiers externes → rien à modifier

## Critères d'acceptation

- [x] Le bouton "IA Foreground" apparaît dans la toolbar de l'éditeur de séquence, après "+ Foreground"
- [x] Cliquer sur le bouton ouvre le dialogue de génération IA
- [x] Le dialogue affiche les champs URL ComfyUI, token, image source, prompt
- [x] L'URL et le token sont persistés dans `user://comfyui_config.cfg`
- [x] La configuration est rechargée à l'ouverture du dialogue
- [x] L'image source est pré-remplie si un foreground est sélectionné
- [x] Le bouton "Générer" lance la séquence upload → prompt → poll → download
- [x] Le statut de progression est affiché pendant la génération
- [x] L'image générée est affichée en preview
- [x] Le bouton "Accepter" sauve le PNG et l'ajoute comme foreground au dialogue courant
- [x] Le bouton "Regénérer" relance avec un nouveau seed
- [x] Les erreurs réseau sont affichées clairement à l'utilisateur
- [x] Le workflow ComfyUI utilise Flux 2 Klein + BiRefNet pour le fond transparent
- [x] Le token d'authentification est envoyé via le header Authorization Bearer sur chaque requête
