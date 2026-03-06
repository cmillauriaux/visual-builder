# Onglets du menu Charger une partie

## Résumé

Le menu de chargement (mode LOAD de `SaveLoadMenu`) est organisé en trois onglets :
1. **Sauvegardes** — les 6 slots de sauvegarde manuelle (comportement existant)
2. **Automatiques** — les sauvegardes automatiques (non implémentées, placeholder "À venir")
3. **Rapides** — la sauvegarde rapide (quicksave)

En mode **sauvegarde** (mode SAVE), la barre d'onglets est masquée et seul le contenu
de l'onglet "Sauvegardes" (les 6 slots manuels) est affiché, comme avant.

## Comportement attendu

### Mode chargement

- Un `TabContainer` est affiché sous l'en-tête.
- **Onglet 0 "Sauvegardes"** : grille 3×2 des 6 slots de sauvegarde manuelle (comportement inchangé).
- **Onglet 1 "Automatiques"** : contenu placeholder affichant un label "À venir".
- **Onglet 2 "Rapides"** : affiche une carte unique pour la sauvegarde rapide.
  - Si la quicksave existe : screenshot (si disponible), nom du chapitre, nom de la scène, date/heure, bouton **Charger**.
  - Si aucune quicksave : label "Aucune sauvegarde rapide".
  - Pas de bouton Supprimer pour la quicksave (suppression non exposée dans ce menu).
- Le signal `load_slot_pressed` est réutilisé pour la quicksave avec l'index spécial `-1`.

### Mode sauvegarde

- La barre d'onglets (`tabs_visible = false`) est masquée.
- L'onglet actif est forcé sur 0 (sauvegardes manuelles).
- Le comportement est identique à l'ancienne implémentation sans onglets.

## Structure UI

```
SaveLoadMenu (Control)
  Overlay (ColorRect)
  CenterContainer
    PanelContainer
      VBoxContainer
        Header (HBoxContainer)
          _title_label (Label)
          CloseButton (Button)
        _tab_container (TabContainer)
          "Sauvegardes" → ScrollContainer → _grid (GridContainer, 3 col)
          "Automatiques" → Label "À venir"
          "Rapides" → ScrollContainer → _quick_content (VBoxContainer)
  _confirm_overlay (Control)
```

## Critères d'acceptation

- [ ] En mode chargement, un `TabContainer` avec 3 onglets est affiché.
- [ ] L'onglet "Sauvegardes" contient la grille des 6 slots manuels (`_grid`).
- [ ] L'onglet "Automatiques" affiche un label "À venir".
- [ ] L'onglet "Rapides" affiche une carte quicksave si une sauvegarde rapide existe.
- [ ] L'onglet "Rapides" affiche "Aucune sauvegarde rapide" si aucune quicksave n'existe.
- [ ] Cliquer "Charger" dans l'onglet "Rapides" émet `load_slot_pressed` avec l'index `-1`.
- [ ] En mode sauvegarde, `_tab_container.tabs_visible == false`.
- [ ] En mode sauvegarde, l'onglet actif est 0 (sauvegardes manuelles).
- [ ] `_grid` est toujours accessible et contient les 6 slots manuels après `refresh()`.
