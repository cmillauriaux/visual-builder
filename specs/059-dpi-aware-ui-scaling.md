# 059 — Mise à l'échelle UI en mode jeu (DPI-aware)

## Contexte

Le projet visual-builder utilise un viewport virtuel de 1920×1080 avec le mode de stretch `canvas_items` + `expand`. Sur un petit écran ou un appareil mobile, Godot réduit le contenu proportionnellement à la taille de la fenêtre physique. Cela rend les textes et boutons physiquement très petits (parfois illisibles) sur les appareils à petits écrans ou haute densité de pixels.

L'objectif est que les éléments UI du mode jeu (textes, boutons, panneaux) aient une **taille physique constante** : en plaçant deux appareils côte à côte (ex : un téléphone et un moniteur de bureau), les boutons et textes doivent apparaître à la même taille en millimètres.

## Principe technique

Avec le mode `canvas_items` + `expand`, le facteur de scaling interne de Godot est :

```
godot_canvas_scale = min(physical_window_w / 1920, physical_window_h / 1080)
```

Pour conserver une taille physique constante, le facteur d'échelle UI doit être :

```
ui_scale = (screen_dpi / 96) / godot_canvas_scale
```

Où 96 DPI est la densité de référence (moniteur 1920×1080 standard).

La valeur est clampée entre 0.5 et 5.0 pour éviter les extrêmes.

## Fonctionnalités

### F1 — Module UIScale

Un module statique `UIScale` (fichier `src/ui/themes/ui_scale.gd`) :
- Calcule le facteur d'échelle UI au premier appel via `UIScale.get_scale()`
- Utilise `DisplayServer.window_get_size()` et `DisplayServer.screen_get_dpi()`
- Expose `UIScale.scale(pixels)` pour convertir une valeur en pixels virtuels en pixels virtuels scalés

### F2 — Application au thème Godot

`GameTheme.create_theme()` utilise le scale pour toutes les tailles de police définies dans le thème (via `theme.set_font_size()`).

### F3 — Application aux tailles hardcodées dans GameUIBuilder

Dans `game_ui_builder.gd`, toutes les valeurs de pixels hardcodées (tailles minimales de boutons, offsets de layout, tailles de panneaux) sont multipliées par `UIScale.get_scale()`.

### F4 — Application aux menus

Les scripts de menu (`pause_menu.gd`, `main_menu.gd`, `options_menu.gd`, `ending_screen.gd`) utilisent `UIScale.scale(N)` pour leurs tailles de police overrides et tailles minimales de boutons.

### F5 — Comportement sur référence

Sur un écran 1920×1080 à 96 DPI, `UIScale.get_scale()` retourne exactement `1.0`, ce qui préserve le comportement actuel.

## Critères d'acceptation

- [ ] `UIScale.get_scale()` retourne `1.0` pour une fenêtre 1920×1080 à 96 DPI
- [ ] `UIScale.get_scale()` retourne une valeur > 1.0 pour une fenêtre de 800×600 à 96 DPI
- [ ] `UIScale.get_scale()` retourne une valeur > 1.0 pour un écran haute densité (DPI > 96)
- [ ] `UIScale.get_scale()` est clampé entre 0.5 et 5.0
- [ ] `UIScale.scale(16)` retourne `16` quand le scale est 1.0
- [ ] `UIScale.scale(16)` retourne `32` quand le scale est 2.0
- [ ] `GameTheme.create_theme()` utilise des tailles de police scalées
- [ ] `GameUIBuilder` utilise des tailles de boutons et offsets scalés
- [ ] Les menus (`pause_menu`, `main_menu`, `options_menu`, `ending_screen`) utilisent des tailles scalées
- [ ] Tous les tests existants passent sans régression
