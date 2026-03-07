# 025 — Effets visuels (FX) de séquence

## Objectif

Permettre d'ajouter des effets visuels (FX) à une séquence. Les FX s'exécutent au début de la séquence, avant le premier dialogue.

## Types de FX

| Type           | Description                                                        |
|----------------|--------------------------------------------------------------------|
| `screen_shake` | Secouer l'écran (oscillation horizontale basée sur intensity)      |
| `fade_in`      | Fondu depuis le noir (ColorRect noir → transparent)                |
| `eyes_blink`   | Fermeture/ouverture des yeux (barres noires haut/bas qui s'ouvrent)|
| `flash`        | Flash coloré (blanc par défaut) — explosion, éclair, souvenir      |
| `zoom`         | Zoom progressif sur l'écran — emphasis dramatique                  |
| `vignette`     | Assombrissement des bords — tension, focus                         |
| `desaturation` | Passage en niveaux de gris — flashback, drame                      |

## Modèle `SequenceFx`

- `uuid: String` — auto-généré
- `fx_type: String` — "screen_shake", "fade_in", "eyes_blink", "flash", "zoom", "vignette", "desaturation" (validé, défaut "fade_in")
- `duration: float` — 0.1 à 5.0 (clampé, défaut 0.5)
- `intensity: float` — 0.1 à 3.0 (clampé, défaut 1.0)
- `color: Color` — couleur pour les FX colorés (défaut Color.WHITE, utilisé par flash)
- `to_dict()` / `from_dict()` — sérialisation (color sérialisé en hex string)

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

**vignette** *(persistant)* : ColorRect plein écran avec shader vignette. Paramètre `strength` animé de 0 → intensity sur la durée. L'overlay reste en place jusqu'à la séquence suivante. Si la séquence suivante contient aussi un FX `vignette`, l'overlay est conservé (pas de clignotement). Sinon, il est supprimé.

**desaturation** *(persistant)* : ColorRect plein écran avec shader desaturation. Paramètre `amount` animé de 0 → intensity (plafonné à 1.0) sur la durée. L'overlay reste en place jusqu'à la séquence suivante. Si la séquence suivante contient aussi un FX `desaturation`, l'overlay est conservé. Sinon, il est supprimé.

### FX persistants vs transitoires

Les FX `vignette` et `desaturation` sont **persistants** : ils restent affichés après leur animation d'entrée, jusqu'à ce que :
- La séquence suivante ne contienne pas le même type de FX → l'overlay est supprimé
- `stop_fx()` soit appelé explicitement (ex: changement de scène)

Les autres FX (`screen_shake`, `fade_in`, `eyes_blink`, `flash`, `zoom`) sont **transitoires** : ils jouent leur animation complète puis se nettoient automatiquement.

## `FxPanel` (UI éditeur)

- Liste des FX de la séquence courante
- Bouton "Ajouter FX" avec menu des types (incluant les 7 types)
- Pour chaque FX : type (OptionButton), durée (SpinBox), intensité (SpinBox), bouton supprimer
- Pour les FX qui utilisent la couleur (flash) : un ColorPickerButton supplémentaire
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

- Modèle : valeurs par défaut, validation, sérialisation (incluant color), rétrocompat
- Modèle : les 4 nouveaux types sont acceptés comme fx_type valides
- Player : play vide émet fx_finished, play avec FX, stop, is_playing
- Player : flash crée un overlay ColorRect, zoom modifie le scale, vignette/desaturation créent des overlays shader
- Player : stop nettoie les overlays et restaure scale/position
- Panel : ajout des 7 types, suppression, signal fx_changed, load_sequence
- Contrôleurs : FX jouent avant les dialogues, stop interrompt les FX
