# Spec 039 — Musique et FX Audio

## Contexte

Le moteur de visual novel doit pouvoir jouer de la musique d'ambiance en boucle et des effets sonores (FX) déclenchés à l'entrée d'une séquence. Le système audio utilise les paramètres existants de `GameSettings` (music_enabled, music_volume, fx_enabled, fx_volume) et les bus audio Godot ("Music" et "FX").

## Import et galerie audio

### Import d'un fichier audio

- L'utilisateur peut importer un fichier audio depuis le système de fichiers via `AudioPickerDialog`
- Formats supportés : OGG, MP3, WAV
- Le fichier est automatiquement **copié** dans le dossier de l'histoire :
  - Musique → `assets/music/`
  - FX → `assets/fx/`
- Les conflits de nommage sont résolus avec un suffixe `_N` (ex: `theme_1.ogg`)
- Le chemin absolu du fichier copié est stocké dans le modèle

### Galerie audio

- L'onglet "Galerie" liste les fichiers audio déjà présents dans le dossier correspondant (`assets/music/` ou `assets/fx/`)
- Chaque item affiche le nom du fichier
- Un clic sur un item le sélectionne (pas de copie supplémentaire)
- Double-clic : aperçu audio (lecture courte)

## Séquence — Musique

### Propriétés du modèle `SequenceModel`

```gdscript
var music: String = ""        # chemin absolu vers le fichier audio
var audio_fx: String = ""     # chemin absolu vers le fichier FX
var stop_music: bool = false  # arrêter la musique en cours
```

### Comportement en lecture

- **Musique** : boucle en continu jusqu'à être remplacée par une autre musique ou arrêtée. Jouée sur le bus "Music".
- **FX** : joué une seule fois à l'apparition de la séquence (pas de boucle). Joué sur le bus "FX".
- **Stop music** : si coché, stoppe la musique en cours à l'entrée de cette séquence (même si `music` est vide).
- Si `stop_music` est faux et `music` est renseigné, la nouvelle musique remplace l'ancienne.
- Le FX est joué indépendamment de la musique.
- Les paramètres `music_enabled` et `fx_enabled` de `GameSettings` sont respectés.

### Ordre d'exécution au démarrage d'une séquence

1. Transition d'entrée (si configurée)
2. FX visuels (si configurés)
3. Audio : stop_music → nouvelle musique → FX audio
4. Écran titre (si titre/sous-titre)
5. Dialogues

### UI dans l'éditeur de séquence

L'onglet "Musique" (Tab 2) du panneau droit de l'éditeur de séquence affiche :

**Section Musique**
- Libellé du fichier sélectionné (ou "Aucune musique")
- Bouton [Choisir...] → ouvre `AudioPickerDialog` en mode MUSIC
- Bouton [✕] → efface la sélection
- Case à cocher "Arrêter la musique" (`stop_music`)

**Section FX Audio**
- Libellé du fichier sélectionné (ou "Aucun FX")
- Bouton [Choisir...] → ouvre `AudioPickerDialog` en mode FX
- Bouton [✕] → efface la sélection

## Menu principal — Musique

### Propriété du modèle `StoryModel`

```gdscript
var menu_music: String = ""  # chemin absolu vers la musique du menu
```

### Comportement

- La musique du menu est jouée en boucle dès l'ouverture du menu principal
- Elle est arrêtée (ou remplacée) dès que le jeu démarre
- La sélection se fait depuis la galerie audio du dossier `assets/music/`

### UI dans le dialogue de configuration du menu

Dans `MenuConfigDialog` :
- Champ "Musique du menu" avec libellé du fichier sélectionné
- Bouton [Choisir...] → ouvre `AudioPickerDialog` en mode MUSIC
- Bouton [✕] → efface la sélection

## Service MusicPlayer

### Rôle

`MusicPlayer` est un `Node` qui gère la lecture audio en jeu :
- Un `AudioStreamPlayer` pour la musique (bus "Music", loop = true)
- Un `AudioStreamPlayer` pour les FX (bus "FX", loop = false)

### API

```gdscript
func play_music(path: String) -> void    # joue une musique en boucle
func stop_music() -> void                # arrête la musique
func play_fx(path: String) -> void       # joue un FX (one-shot)
func apply_sequence(seq, base_path: String) -> void  # applique les params audio d'une séquence
func play_menu_music(path: String) -> void  # joue la musique du menu
```

### Chargement audio externe

Les fichiers audio sont chargés depuis le système de fichiers (hors ressources Godot) :
- OGG → `AudioStreamOggVorbis.load_from_file(path)`
- MP3 → lecture des bytes + `AudioStreamMP3`
- WAV → lecture des bytes + `AudioStreamWAV`

## Persistance YAML

Le modèle `SequenceModel.to_dict()` inclut :
```yaml
music: "chemin/absolu/ou/vide"
audio_fx: "chemin/absolu/ou/vide"
stop_music: false
```

Le modèle `StoryModel.to_dict()` inclut :
```yaml
menu_music: "chemin/absolu/ou/vide"
```

La rétrocompatibilité est assurée : les champs manquants prennent leur valeur par défaut.

## Critères d'acceptation

1. `sequence.music`, `sequence.audio_fx` et `sequence.stop_music` sont persistés en YAML (to_dict/from_dict)
2. `story.menu_music` est persisté en YAML
3. L'éditeur de séquence permet de choisir une musique et un FX depuis l'onglet "Musique"
4. La case "Arrêter la musique" est disponible dans l'onglet "Musique"
5. `AudioPickerDialog` permet d'importer un fichier audio (copie dans assets) ou de le choisir en galerie
6. `MusicPlayer` joue la musique en boucle et le FX en one-shot
7. Les paramètres `music_enabled` / `fx_enabled` de `GameSettings` sont respectés (via les bus audio Godot)
8. La musique du menu se configure via le dialogue de configuration du menu
9. La musique du menu est jouée à l'affichage du menu principal
10. La musique s'arrête / est remplacée correctement lors des transitions de séquence
