# 027 — Scaling DPI pour affichage Mac Retina

## Contexte

Le projet visual-builder affiche des boutons et textes trop petits sur les écrans Mac Retina (haute densité de pixels), alors que l'affichage est correct sur un écran Full HD standard. Le projet définit un viewport 1920×1080 mais n'a aucun mode de stretch configuré. Sans stretch, Godot utilise la résolution physique complète du display (ex : 2880×1800 sur Retina), ce qui fait apparaître les éléments UI à une fraction de leur taille prévue.

## Fonctionnalités

### F1 — Stretch mode canvas_items

Le projet active le mode de stretch `canvas_items` dans `project.godot`. Ce mode maintient la résolution de design (1920×1080) comme système de coordonnées pour tous les éléments UI (Controls), puis les rend à la résolution physique native. Les éléments UI conservent ainsi une taille relative constante quel que soit le display.

### F2 — Aspect ratio expand

Le projet utilise le mode d'aspect `expand` pour permettre à la résolution de design de s'étendre au-delà de 16:9 lorsque le display a un ratio différent (ex : 16:10 sur MacBook). Cela évite les bandes noires autour de l'interface de l'éditeur et utilise tout l'espace disponible.

## Critères d'acceptation

- [ ] `project.godot` définit `window/stretch/mode="canvas_items"`
- [ ] `project.godot` définit `window/stretch/aspect="expand"`
- [ ] Les GraphEdit (chapter, scene, sequence) fonctionnent normalement avec le stretch activé
- [ ] L'éditeur visuel de séquence (auto-fit, letterbox) fonctionne normalement
- [ ] Tous les tests existants passent sans régression
