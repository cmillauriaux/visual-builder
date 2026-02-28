# 025 — Effets visuels (FX) de séquence

## Objectif

Permettre d'ajouter des effets visuels (FX) à une séquence. Les FX s'exécutent au début de la séquence, avant le premier dialogue.

## Types de FX

| Type           | Description                                                        |
|----------------|--------------------------------------------------------------------|
| `screen_shake` | Secouer l'écran (oscillation horizontale basée sur intensity)      |
| `fade_in`      | Fondu depuis le noir (ColorRect noir → transparent)                |
| `eyes_blink`   | Fermeture/ouverture des yeux (barres noires haut/bas qui s'ouvrent)|

## Modèle `SequenceFx`

- `uuid: String` — auto-généré
- `fx_type: String` — "screen_shake", "fade_in", "eyes_blink" (validé, défaut "fade_in")
- `duration: float` — 0.1 à 5.0 (clampé, défaut 0.5)
- `intensity: float` — 0.1 à 3.0 (clampé, défaut 1.0)
- `to_dict()` / `from_dict()` — sérialisation

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

## `FxPanel` (UI éditeur)

- Liste des FX de la séquence courante
- Bouton "Ajouter FX" avec menu des types
- Pour chaque FX : type (OptionButton), durée (SpinBox), intensité (SpinBox), bouton supprimer
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

- Modèle : valeurs par défaut, validation, sérialisation, rétrocompat
- Player : play vide émet fx_finished, play avec FX, stop, is_playing
- Panel : ajout, suppression, signal fx_changed, load_sequence
- Contrôleurs : FX jouent avant les dialogues, stop interrompt les FX
