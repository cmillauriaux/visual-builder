# 025 — Effets visuels (FX) de séquence

## Objectif

Permettre d'ajouter des effets visuels (FX) à une séquence. Les FX s'exécutent au début de la séquence, avant le premier dialogue.

## Types de FX

| Type           | Description                                                                          |
|----------------|--------------------------------------------------------------------------------------|
| `screen_shake` | Secouer l'écran (oscillation horizontale basée sur intensity)                        |
| `fade_in`      | Fondu depuis le noir (ColorRect noir → transparent)                                  |
| `eyes_blink`   | Fermeture/ouverture des yeux (barres noires haut/bas qui s'ouvrent)                  |
| `flash`        | Flash coloré (blanc par défaut) — explosion, éclair, souvenir                        |
| `zoom`         | Zoom pulsé (zoom in + hold + zoom out) — emphasis dramatique                         |
| `vignette`     | Assombrissement des bords — tension, focus                                           |
| `desaturation` | Passage en niveaux de gris — flashback, drame                                        |
| `zoom_in`      | Zoom progressif de `zoom_from` vers `zoom_to` (≥ 1.0) sur background + foreground   |
| `zoom_out`     | Dézoom progressif de `zoom_from` vers `zoom_to` (≥ 1.0) sur background + foreground |
| `pan_right`    | Mouvement de caméra vers la droite — part du bord gauche du background               |
| `pan_left`     | Mouvement de caméra vers la gauche — part du bord droit du background                |
| `pan_down`     | Mouvement de caméra vers le bas — part du bord haut du background                   |
| `pan_up`       | Mouvement de caméra vers le haut — part du bord bas du background                   |

## Modèle `SequenceFx`

- `uuid: String` — auto-généré
- `fx_type: String` — l'un des 13 types valides (validé, défaut "fade_in")
- `duration: float` — 0.1 à 5.0 (clampé, défaut 0.5)
- `intensity: float` — 0.1 à 3.0 (clampé, défaut 1.0) ; pour pan_* représente la fraction de défilement (0.0–1.0)
- `color: Color` — couleur pour les FX colorés (défaut Color.WHITE, utilisé par flash)
- `zoom_from: float` — niveau de zoom initial pour zoom_in/zoom_out, ou zoom pendant pan_* (≥ 1.0, défaut 1.0)
- `zoom_to: float` — niveau de zoom final pour zoom_in/zoom_out (≥ 1.0, défaut 1.5)
- `continue_during_fx: bool` — si `true`, le FX démarre sans bloquer la suite : la scène continue en parallèle (UI visible, dialogues, voix). Défaut `false` (bloquant).
- `to_dict()` / `from_dict()` — sérialisation (color en hex string, zoom_from, zoom_to et continue_during_fx inclus)

## Intégration dans `Sequence`

- Nouvelle propriété `fx: Array` (tableau de `SequenceFx`)
- Sérialisé dans `to_dict()` / désérialisé dans `from_dict()`
- Rétrocompatibilité : si `fx` absent du dict → tableau vide

## `SequenceFxPlayer`

- `play_fx_list(fx_list: Array, target: Control)` — joue séquentiellement
- `stop_fx()` — annule les FX en cours
- `is_playing() -> bool`
- Signal `fx_finished` — émis quand terminé (ou si liste vide)

### Détails d'animation

**screen_shake** : amplitude = intensity * 10px, N oscillations via tween sur target.position, retour à l'origine.

**fade_in** : ColorRect noir plein écran ajouté, alpha 1.0 → 0.0 via tween, puis queue_free.

**eyes_blink** : 2 ColorRect noirs (haut/bas) couvrant tout, phase fermée (25% durée), phase ouverture (75% durée) via tween, puis queue_free.

**flash** : ColorRect plein écran de la couleur choisie (défaut blanc). Alpha 0 → intensity (plafonné à 1.0) sur 30% de la durée, puis maintien 20%, puis intensity → 0 sur 50% de la durée. queue_free à la fin.

**zoom** : Modifie target.scale et target.pivot_offset (centré). Scale 1.0 → (1.0 + intensity * 0.15) sur 40% de la durée, maintien 20%, puis retour à 1.0 sur 40%. Restaure scale et pivot à la fin.

**zoom_in** : Anime scale de `zoom_from` vers `zoom_to` sur toute la durée (EASE_IN_OUT QUAD). Pivot centré sur le transform_target. Restaure scale, pivot et position à la fin. Les deux niveaux de zoom sont clampés ≥ 1.0. Affecte background ET foreground (via le transform_target = canvas).

**zoom_out** : Même comportement que zoom_in mais destiné à dézoomer (`zoom_from` > `zoom_to`).

**pan_right / pan_left / pan_down / pan_up** : Mouvement de caméra sur le background+foreground. Paramètres : `zoom_from` (niveau de zoom pour disposer d'espace de défilement, ≥ 1.0), `intensity` (fraction de défilement 0–1, clampée à 1.0 dans le player), `duration`.

Position de départ auto-calculée pour ne jamais dépasser l'image du background :
- `pan_right` : part du bord gauche (`position.x = original_x + extra_x`) et pan vers la droite
- `pan_left` : part du bord droit (`position.x = original_x - extra_x`) et pan vers la gauche
- `pan_down` : part du bord haut (`position.y = original_y + extra_y`) et pan vers le bas
- `pan_up` : part du bord bas (`position.y = original_y - extra_y`) et pan vers le haut

Avec `extra_x = canvas_width * (zoom - 1) / 2` et `extra_y = canvas_height * (zoom - 1) / 2`.

L'animation de la position utilise EASE_IN_OUT SINE. Scale, pivot et position sont restaurés à la fin.

**vignette** *(persistant)* : ColorRect plein écran avec shader vignette. Paramètre `strength` animé de 0 → intensity sur la durée. L'overlay reste en place jusqu'à la séquence suivante. Si la séquence suivante contient aussi un FX `vignette`, l'overlay est conservé (pas de clignotement). Sinon, il est supprimé.

**desaturation** *(persistant)* : ColorRect plein écran avec shader desaturation. Paramètre `amount` animé de 0 → intensity (plafonné à 1.0) sur la durée. L'overlay reste en place jusqu'à la séquence suivante. Si la séquence suivante contient aussi un FX `desaturation`, l'overlay est conservé. Sinon, il est supprimé.

### FX persistants vs transitoires

Les FX `vignette` et `desaturation` sont **persistants** : ils restent affichés après leur animation d'entrée, jusqu'à ce que :
- La séquence suivante ne contienne pas le même type de FX → l'overlay est supprimé
- `stop_fx()` soit appelé explicitement (ex: changement de scène)

Les autres FX (`screen_shake`, `fade_in`, `eyes_blink`, `flash`, `zoom`) sont **transitoires** : ils jouent leur animation complète puis se nettoient automatiquement.

## `FxPanel` (UI éditeur)

- Liste des FX de la séquence courante
- Bouton "Ajouter FX" avec menu des 13 types
- Pour chaque FX : type (OptionButton), durée (SpinBox), bouton supprimer
- Champs conditionnels selon le type :
  - `flash` : ColorPickerButton couleur + intensité SpinBox
  - `zoom_in` / `zoom_out` : SpinBox "De x" (zoom_from ≥ 1.0) + SpinBox "À x" (zoom_to ≥ 1.0), pas d'intensité
  - `pan_*` : SpinBox "Zoom" (zoom_from ≥ 1.0) + SpinBox "Défilement" (intensity 0.0–1.0)
  - autres FX avec intensity : SpinBox intensité standard (0.1–3.0)
- Signal `fx_changed`
- `load_sequence(seq)` / `clear()`

## Flux de lecture

```
start_play() déclenché
       │
       ▼
  séquence.fx.size() > 0 ?
       │
  OUI  │  NON
  ▼    │   ▼
play_fx_list() │ start_play() direct
  │            │
  ▼            │
fx_finished    │
  │            │
  ▼            │
start_play()   │
```

## Tests requis

- Modèle : valeurs par défaut, validation, sérialisation (incluant color, zoom_from, zoom_to, continue_during_fx), rétrocompat
- Modèle : les 13 types sont acceptés comme fx_type valides
- Modèle : zoom_from et zoom_to clampés ≥ 1.0, sérialisés et restaurés en roundtrip
- Modèle : continue_during_fx défaut false, sérialisé et restauré en roundtrip
- Player : play vide émet fx_finished, play avec FX, stop, is_playing
- Player : flash crée un overlay ColorRect, zoom modifie le scale, vignette/desaturation créent des overlays shader
- Player : zoom_in et zoom_out modifient le scale et restaurent à la fin (stop)
- Player : pan_* applique zoom + position initiale correcte + restaure tout à la fin (stop)
- Player : stop nettoie les overlays et restaure scale/position
- Player : FX avec continue_during_fx=true démarre sans bloquer (fx_finished émis immédiatement après), tween dans _detached_tweens, stop_fx le nettoie
- Panel : ajout des 13 types, suppression, signal fx_changed, load_sequence, checkbox "En parallèle" par FX
- Contrôleurs : FX jouent avant les dialogues, stop interrompt les FX
