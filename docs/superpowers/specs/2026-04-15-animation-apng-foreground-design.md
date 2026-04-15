# Design : Foregrounds animés APNG

**Date** : 2026-04-15  
**Statut** : Approuvé

## Résumé

Intégration des animations APNG comme type de foreground dans le visual-builder, avec options de lecture (Reverse, Speed, Loop, Reverse Loop) fonctionnelles dans l'éditeur et dans le player/export.

---

## Contexte

Les assets story contiennent désormais un répertoire `animation/` avec des fichiers `.apng`. La galerie doit les exposer dans la section Foregrounds (avec un filtre dédié), et l'éditeur doit les lire avec les options configurées par l'auteur.

Les foregrounds statiques utilisent `TextureRect` + `ImageTexture`. Les APNG nécessitent un lecteur de frames cycliques. Les assets story ne passent pas par l'import Godot (ils sont hors `res://`), donc l'approche retenue est un **parser APNG binaire GDScript** + un **lecteur de frames custom**.

Le `ForegroundBlinkPlayer` existant est **désactivé pour les foregrounds APNG** (une animation APNG gère sa propre animation).

---

## Architecture

5 zones de changement :

```
ApngLoader (nouveau)            src/ui/shared/apng_loader.gd
ForegroundAnimPlayer (nouveau)  src/ui/visual/foreground_anim_player.gd
Foreground model (modifié)      src/models/foreground.gd
Gallery dialog (modifié)        src/ui/dialogs/gallery_dialog.gd
Foreground properties (modifié) panneau de propriétés foreground existant
```

---

## Composant 1 : ApngLoader

**Fichier** : `src/ui/shared/apng_loader.gd`  
**Classe** : statique, aucun état, aucun node.

### Responsabilité

Lire un fichier `.apng` depuis le disque, parser ses chunks binaires, retourner les frames et leurs délais.

### Sortie

```gdscript
# Succès :
{ "frames": Array[ImageTexture], "delays": Array[float] }
# Échec (fichier illisible, format invalide) :
{}
```

Les délais sont en secondes. Exemple : `fcTL` avec `delay_num=1, delay_den=12` → `0.0833s`.

### Algorithme de parsing

1. Lire les 8 octets de signature PNG (`\x89PNG\r\n\x1a\n`) — abandonner si invalide.
2. Parcourir les chunks dans l'ordre :
   - `IHDR` → dimensions (utilisées pour le premier frame)
   - `acTL` → nombre de frames (informatif)
   - `fcTL` → stocker le délai de la frame à venir (numérateur/dénominateur uint16 big-endian)
   - `IDAT` → données du premier frame (rétrocompatibilité PNG)
   - `fdAT` → données des frames suivantes (skip les 4 premiers octets = sequence_number)
   - `IEND` → stop
3. Chaque bloc IDAT/fdAT est reconstruit en PNG complet (signature + IHDR + IDAT/fdAT + IEND), puis chargé via `Image.load_png_from_buffer()`.
4. Convertir chaque `Image` en `ImageTexture` via `ImageTexture.create_from_image()`.

### Gestion des délais manquants

Si `fcTL` est absent pour une frame, délai par défaut = `1.0 / 12.0` (~12 fps).

---

## Composant 2 : ForegroundAnimPlayer

**Fichier** : `src/ui/visual/foreground_anim_player.gd`  
**Type** : `Control` node (remplace `TextureRect` pour les foregrounds APNG).

### Propriétés

```gdscript
var anim_speed: float = 1.0        # multiplicateur de vitesse
var anim_reverse: bool = false     # lecture inverse (mode non-boucle)
var anim_loop: bool = true         # boucle avant
var anim_reverse_loop: bool = false # boucle arrière (priorité sur loop et reverse)
```

### État interne

```gdscript
var _frames: Array[ImageTexture]
var _delays: Array[float]
var _current_frame: int = 0
var _elapsed: float = 0.0
var _playing: bool = false
var _tex_rect: TextureRect
```

### Logique de lecture (`_process(delta)`)

```
elapsed += delta

si elapsed >= delays[current_frame] / anim_speed :
    elapsed = 0.0
    si reverse_loop :
        current_frame -= 1
        si current_frame < 0 : current_frame = frames.size() - 1
    sinon si loop :
        current_frame += 1
        si current_frame >= frames.size() : current_frame = 0
    sinon si anim_reverse :
        current_frame -= 1
        si current_frame < 0 : stop(), current_frame = 0
    sinon :
        current_frame += 1
        si current_frame >= frames.size() : stop(), current_frame = frames.size() - 1

    _tex_rect.texture = _frames[current_frame]
```

### API publique

```gdscript
func load_apng(path: String) -> bool   # charge via ApngLoader, retourne false si échec
func play() -> void
func stop() -> void
func set_frame(n: int) -> void         # utile pour preview first frame
```

---

## Modèle Foreground

**Fichier** : `src/models/foreground.gd`

### Nouveaux champs

```gdscript
var anim_speed: float = 1.0           # plage : 0.1 → 4.0
var anim_reverse: bool = false
var anim_loop: bool = true            # défaut boucle
var anim_reverse_loop: bool = false
```

### Sérialisation YAML

`to_dict()` : les 4 champs ne sont écrits dans le dict **que si** `image.ends_with(".apng")`.

`from_dict()` : toujours lus avec valeurs par défaut si absents.

---

## Galerie

**Fichier** : `src/ui/dialogs/gallery_dialog.gd`

### Extensions

Ajouter `"apng"` à la liste des extensions acceptées dans **`gallery_dialog.gd`** (ligne ~257) et dans **`gallery_cleaner_service.gd`** si ce service filtre aussi par extension :
```gdscript
GalleryCacheService.get_file_list(dir_path, ["png", "jpg", "jpeg", "webp", "apng"])
```

### Filtre "Animations"

Un `CheckBox` labellisé **"Animations"** est ajouté dans le header de la grille Foregrounds.

- **Décoché** (défaut) : affiche tous les foregrounds (PNG + APNG mélangés)
- **Coché** : filtre la liste en mémoire pour n'afficher que les `.apng`

Le filtrage est côté GDScript sur la liste déjà chargée (pas de rechargement disque).

### Aperçu (vignette)

`GalleryCacheService` détecte `.apng` et charge la **première frame uniquement** pour la vignette. L'APNG est rétrocompatible PNG : `Image.load_png_from_buffer()` sur les données brutes lit le premier frame sans parser les chunks animés, ce qui est suffisant pour la vignette.

### Badge visuel

Les vignettes APNG affichent un petit badge **"▶"** (Label ou icon overlay) pour les distinguer des PNG statiques dans la vue non filtrée.

---

## Panneau de propriétés Foreground

Une section **"Animation"** est ajoutée dans le panneau de propriétés foreground existant. Elle est **visible uniquement** si `fg.image.ends_with(".apng")`.

### Layout

```
┌─ Animation ──────────────────────────────┐
│ □ Reverse                                │
│ Vitesse  [━━━●━━━━━] 1.0×  (0.1 → 4.0) │
│ □ Loop                    □ Reverse Loop │
└──────────────────────────────────────────┘
```

### Règles d'interaction

- **Reverse** est grisé (`disabled`) si **Loop** ou **Reverse Loop** est coché.
- **Loop** et **Reverse Loop** sont mutuellement exclusifs : cocher l'un décoche l'autre.
- Tout changement déclenche immédiatement `ForegroundAnimPlayer.set_*()` → preview live dans l'éditeur.

---

## Intégration dans sequence_visual_editor

Dans `_create_fg_wrapper()` :

```gdscript
if fg.image.ends_with(".apng"):
    var player = ForegroundAnimPlayer.new()
    player.anim_speed = fg.anim_speed
    player.anim_reverse = fg.anim_reverse
    player.anim_loop = fg.anim_loop
    player.anim_reverse_loop = fg.anim_reverse_loop
    player.load_apng(fg.image)
    player.play()
    wrapper.add_child(player)
else:
    var tex_rect = TextureRect.new()
    # ... comportement existant
    wrapper.add_child(tex_rect)
```

Le blink player n'est pas instancié pour les foregrounds APNG.

---

## Tests

| Fichier de test | Ce qui est testé |
|---|---|
| `specs/models/test_foreground.gd` | `to_dict()`/`from_dict()` avec les 4 nouveaux champs ; champs absents du YAML si non-APNG |
| `specs/ui/shared/test_apng_loader.gd` | Parse d'un APNG de référence : nb frames, délais, dimensions |
| `specs/ui/visual/test_foreground_anim_player.gd` | Cycle de frames en mode loop / reverse_loop / one-shot ; respect du speed ; stop en fin de lecture |
| `specs/ui/dialogs/test_gallery_dialog.gd` | Filtre Animations : seuls les .apng restent quand coché |

---

## Hors scope

- Combinaison APNG + blink player
- Pingpong loop (A→B→A)
- Aperçu animé dans la vignette galerie
- Export web : le player/export lit les mêmes fichiers APNG via le même `ApngLoader` — pas de traitement spécifique web
