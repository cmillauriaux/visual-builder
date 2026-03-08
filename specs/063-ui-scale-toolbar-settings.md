# 063 — Échelle UI et visibilité barre d'outils

## Contexte

Le joueur doit pouvoir ajuster la taille de l'interface utilisateur du jeu (petit, moyen, gros) et choisir d'afficher ou non la barre d'outils (Save, Load, Auto, Skip, Histo) pendant le jeu.

## Exigences

### Échelle UI

1. Ajouter un paramètre `ui_scale_mode` (int) dans `GameSettings` avec 3 options : Petit (0, défaut), Moyen (1), Gros (2).
2. Les facteurs correspondants sont : 1.0, 1.25, 1.5.
3. Ajouter une liste déroulante "Échelle UI" dans la section Affichage du menu Options.
4. Le changement d'échelle est appliqué via `UIScale.set_user_multiplier()` et nécessite un rechargement de la scène pour prendre effet.
5. `UIScale._compute_scale()` multiplie le facteur automatique par `_user_multiplier`.
6. Le paramètre est persisté dans `settings.cfg` sous `[display] ui_scale_mode`.

### Barre d'outils

7. Ajouter un paramètre `toolbar_visible` (bool, défaut `true`) dans `GameSettings`.
8. Ajouter une case à cocher "Barre d'outils" dans la section Affichage du menu Options.
9. Quand `toolbar_visible` est `false`, la barre de boutons de jeu (Save, Load, Auto, Skip, Histo) est masquée pendant le jeu.
10. Le changement prend effet immédiatement sans rechargement.
11. Le paramètre est persisté dans `settings.cfg` sous `[display] toolbar_visible`.

## Critères d'acceptation

- [ ] `GameSettings` a les propriétés `ui_scale_mode` (défaut 0) et `toolbar_visible` (défaut true).
- [ ] `GameSettings` a les constantes `UI_SCALE_FACTORS` et `UI_SCALE_LABELS`.
- [ ] `GameSettings.get_ui_scale_factor()` retourne le facteur correspondant au mode.
- [ ] Les deux paramètres sont sauvegardés et chargés via `ConfigFile`.
- [ ] `UIScale` supporte un `_user_multiplier` appliqué dans `_compute_scale()`.
- [ ] `UIScale.set_user_multiplier()` invalide le cache.
- [ ] `UIScale.reset()` remet aussi le multiplicateur à 1.0.
- [ ] Le menu Options affiche les contrôles pour les deux nouveaux paramètres.
- [ ] `load_from_settings` charge correctement les valeurs dans les contrôles.
- [ ] `apply_to_settings` écrit correctement les valeurs depuis les contrôles.
- [ ] Le play controller respecte `toolbar_visible` lors de l'affichage de la barre.
