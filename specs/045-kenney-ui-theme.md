# 045 — Thème UI Kenney Adventure pour le jeu

## Objectif

Appliquer le pack **Kenney UI Pack Adventure** (style brun/beige aventure) à toute l'interface du **jeu** (pas de l'éditeur) : menus, dialogues, choix, boutons et fenêtres.

## Assets utilisés

Pack : `kenney_ui-pack-adventure/PNG/Double/` (textures 2x pour résolution 1920x1080).

| Élément UI | Texture Kenney |
|------------|----------------|
| Fenêtres / panels | `panel_brown.png` (128x128, NinePatch) |
| Cards / slots | `panel_brown_dark.png` (128x128, NinePatch) |
| Boutons standard | `button_brown.png` (96x48, NinePatch) |
| Boutons destructifs | `button_red.png` (96x48, NinePatch) |
| Bouton fermer | `button_red_close.png` (96x48, NinePatch) |
| Bannière titre | `banner_hanging.png` (512x128, TextureRect) |
| Checkbox vide | `checkbox_brown_empty.png` (48x48, icône) |
| Checkbox coché | `checkbox_brown_checked.png` (48x48, icône) |
| Scrollbar | `scrollbar_brown.png` (32x128, NinePatch) |

## Écrans concernés

1. **Menu principal** (`main_menu.gd`) — bannière titre, boutons marron, "Quitter" rouge
2. **Menu pause** (`pause_menu.gd`) — panel marron, boutons marron, "Quitter" rouge
3. **Menu options** (`options_menu.gd`) — panel marron, checkboxes Kenney, bouton close rouge
4. **Save/Load** (`save_load_menu.gd`) — panel marron, slot cards sombres, "Supprimer" rouge
5. **Dialogue** (play overlay) — panel marron en bas de l'écran, texte brun foncé
6. **Choix** (choice overlay) — panel marron centré, boutons marron
7. **Sélecteur de story** — panel marron, boutons marron
8. **Bouton menu** (☰) — bouton marron en haut à droite

## Approche technique

- **Theme Godot programmatique** : Un script `game_theme.gd` construit un `Theme` qui utilise les textures Kenney via `StyleBoxTexture` (NinePatch 9-patch).
- **Application par héritage** : Le thème est appliqué au noeud racine `Game`. Tous les enfants héritent automatiquement.
- **États des boutons** : normal / hover / pressed / disabled via `modulate_color` sur le StyleBoxTexture.
- **Variante danger** : Méthode utilitaire `apply_danger_style(button)` pour les boutons rouges.

## Palette de couleurs

| Usage | Couleur |
|-------|---------|
| Texte sur panel beige | Brun foncé `#3D2B1F` |
| Texte sur boutons marron | Blanc `#FFFFFF` |
| Texte titre principal | Blanc `#FFFFFF` (sur fond sombre/bannière) |
| Texte secondaire | Brun moyen `#6B4E37` |
| Overlay fond | Noir semi-transparent (inchangé) |

## Critères d'acceptation

- [ ] Les assets Kenney Double sont copiés dans `assets/ui/kenney/`
- [ ] `game_theme.gd` crée un `Theme` valide avec StyleBoxTexture pour Button, PanelContainer, Label, CheckButton, OptionButton, HSlider, HSeparator
- [ ] Le thème est appliqué au noeud racine Game dans `game_ui_builder.gd`
- [ ] **Menu principal** : bannière titre visible, boutons marron, "Quitter" en rouge
- [ ] **Menu pause** : panel marron avec bordure visible, boutons stylés
- [ ] **Menu options** : panel marron, bouton close rouge, checkboxes Kenney
- [ ] **Save/Load** : panel marron, slot cards en panel_brown_dark, boutons stylés
- [ ] **Dialogue** : overlay panel marron en bas, texte lisible brun foncé
- [ ] **Choix** : panel marron centré, boutons de choix marron
- [ ] **Bouton menu** et **sélecteur story** : stylés avec le thème
- [ ] L'UI de l'éditeur (main.tscn) n'est **pas** affectée
- [ ] Tous les tests GUT passent
- [ ] Les textes restent lisibles (contraste suffisant texte/fond)
