# 060 - Clic souris pour dialogues et navigation clavier pour choix

## Contexte

Actuellement, seule la barre d'espace permet d'avancer les dialogues. Les choix ne sont sélectionnables qu'au clic souris sur les boutons.

## Objectifs

1. **Clic souris pour avancer les dialogues** : un clic gauche n'importe où sur l'écran avance le dialogue (même comportement que la barre d'espace).
2. **Navigation clavier pour les choix** : les flèches haut/bas permettent de naviguer entre les choix, le premier choix est préselectionné par défaut, et Espace/Entrée valide le choix sélectionné.

## Spécification

### Clic souris pour dialogues

- Un clic gauche (`InputEventMouseButton`, `button_index == MOUSE_BUTTON_LEFT`, `pressed == true`) déclenche la même logique que la barre d'espace :
  - Si le typewriter n'a pas fini : skip du typewriter (affichage complet).
  - Si le texte est entièrement affiché : avance au dialogue suivant.
- Le clic fonctionne aussi pour passer l'écran titre de séquence.
- Le clic est ignoré si :
  - Le panneau de choix est visible (`_choice_overlay.visible`).
  - Le panneau d'historique est ouvert (`_history_open`).
- L'événement est consommé (`set_input_as_handled()`).

### Navigation clavier pour les choix

- Quand les choix s'affichent, le premier bouton reçoit le focus automatiquement (`grab_focus()`).
- Les propriétés `focus_neighbor_top` / `focus_neighbor_bottom` sont configurées pour que :
  - Flèche Bas depuis le dernier choix revient au premier.
  - Flèche Haut depuis le premier choix va au dernier.
- Espace et Entrée valident le choix focalisé (comportement natif des `Button` Godot).

## Critères d'acceptation

- [ ] `_input()` traite `InputEventMouseButton` clic gauche pour avancer les dialogues.
- [ ] Le clic gauche passe l'écran titre.
- [ ] Le clic est ignoré quand les choix ou l'historique sont affichés.
- [ ] Les boutons de choix ont le focus cyclique configuré.
- [ ] Le premier bouton de choix a le focus par défaut.
- [ ] Tests unitaires couvrent les nouvelles fonctionnalités.
