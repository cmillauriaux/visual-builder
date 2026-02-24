# 010 — Adaptation résolution et letterboxing 16:9

## Contexte

Le projet visual-builder n'a aucun réglage de résolution/stretch. La fenêtre prend n'importe quelle taille sans adaptation. L'éditeur visuel de séquence affiche un canvas 1920x1080 mais sans auto-fit ni centrage. En mode play, le contenu reste dans le split layout de l'éditeur au lieu d'occuper tout l'écran.

## Fonctionnalités

### F1 — Résolution de design et couleur de fond

Le projet définit une résolution de design 1920x1080 (viewport_width/viewport_height) et une couleur de fond noire par défaut. Pas de stretch global pour ne pas affecter les GraphEdit.

### F2 — Auto-fit du canvas dans le visual editor

L'éditeur visuel calcule automatiquement le zoom et le pan pour centrer le background (1920x1080) dans l'espace disponible, en conservant le ratio 16:9. Le calcul produit un zoom = min(width/1920, height/1080) et centre le canvas.

### F3 — Letterbox background

Un `ColorRect` noir est ajouté avant le canvas dans la hiérarchie de l'éditeur visuel. Il couvre tout l'espace (`PRESET_FULL_RECT`) et crée l'effet de bandes noires (letterbox) autour du canvas.

### F4 — Overlay container

Un `Control` nommé `OverlayContainer` est ajouté après le canvas. Sa position et sa taille correspondent au rect écran du canvas (après zoom/pan). Il sert de parent pour les overlays en mode play (dialogue, choix) afin qu'ils soient dimensionnés par rapport au canvas et non à la fenêtre.

### F5 — Désactivation de l'auto-fit lors du zoom/pan manuel

Quand l'utilisateur zoom (molette) ou pan (clic milieu) manuellement, l'auto-fit est désactivé. L'auto-fit est réactivé par `reset_view()` ou lors du chargement d'une nouvelle séquence.

### F6 — Mode play plein écran

En mode play (séquence ou story), le visual editor est retiré de son conteneur habituel et placé dans une couche plein écran (ColorRect noir, PRESET_FULL_RECT). Un bouton Stop flottant permet d'arrêter la lecture. À l'arrêt, le visual editor est restauré dans sa position d'origine.

### F7 — Overlays dans l'overlay container

Les overlays de play (dialogue, choix) sont ajoutés dans l'`_overlay_container` du visual editor au lieu du visual editor lui-même. Cela permet aux overlays de se positionner correctement par rapport au canvas 16:9.

## Critères d'acceptation

- [ ] `project.godot` définit viewport_width=1920 et viewport_height=1080
- [ ] `project.godot` définit default_clear_color noir
- [ ] `compute_auto_fit()` retourne zoom et pan corrects pour un ratio exact (960x540 → zoom=0.5, pan=0,0)
- [ ] `compute_auto_fit()` centre horizontalement pour une fenêtre plus large
- [ ] `compute_auto_fit()` centre verticalement pour une fenêtre plus haute
- [ ] `compute_auto_fit()` gère le cas fenêtre carrée
- [ ] `compute_auto_fit()` gère les tailles nulles sans crash
- [ ] L'auto-fit se désactive après zoom/pan manuel
- [ ] `reset_view()` réactive l'auto-fit
- [ ] Le `LetterboxBackground` (ColorRect noir) existe dans la hiérarchie
- [ ] L'`OverlayContainer` existe dans la hiérarchie
- [ ] L'`OverlayContainer` correspond au rect écran du canvas
- [ ] En mode play fullscreen, une couche noire plein écran est créée
- [ ] Le visual editor est reparenté dans la couche fullscreen
- [ ] À la sortie du fullscreen, la hiérarchie est restaurée
- [ ] Un bouton Stop est visible en mode fullscreen
- [ ] Tous les tests passent sans régression
