# Système d'affichage des variables

## Résumé

Ajout d'un système d'affichage des variables de l'histoire pendant le jeu. Chaque variable peut être configurée pour apparaître sur l'interface principale (sidebar gauche avec cercle + image + valeur) et/ou sur une page de détails (grille avec image, description, valeur). La visibilité peut être inconditionnelle (dès le début du jeu) ou contrôlée par une autre variable (0 = caché, 1 = visible). On peut associer une image de la galerie et une description internationalisée à chaque variable. À chaque changement de variable (effets, début de jeu, chargement), l'affichage est mis à jour.

## Modèle de données

### VariableDefinition — champs ajoutés (`src/models/variable_definition.gd`)

```
VariableDefinition (RefCounted)
├─ var_name: String (existant)
├─ initial_value: String (existant)
├─ show_on_main: bool (défaut false) — visible sur la sidebar gauche
├─ show_on_details: bool (défaut false) — visible sur la page de détails
├─ visibility_mode: String (défaut "always") — "always" ou "variable"
├─ visibility_variable: String (défaut "") — variable contrôlant la visibilité
├─ image: String (défaut "") — chemin relatif vers l'image (galerie)
└─ description: String (défaut "") — description internationalisée
```

Sérialisation : les champs avec valeur par défaut ne sont pas écrits dans le YAML (compacité). `from_dict()` utilise `d.get()` avec les défauts pour la rétrocompatibilité.

### Story — méthodes ajoutées (`src/models/story.gd`)

- `get_main_display_variables() -> Array` — retourne les variables avec `show_on_main == true`
- `get_details_display_variables() -> Array` — retourne les variables avec `show_on_details == true`

### StoryPlayController — signal ajouté (`src/ui/play/story_play_controller.gd`)

- `signal variables_display_changed(variables: Dictionary)` — émis après initialisation des variables et après chaque application d'effets

## Comportement attendu

### Panneau de variables (éditeur)

Le panneau de variables existant est enrichi. Chaque variable affiche désormais un bloc avec :

1. **Ligne existante** : `[LineEdit nom] = [LineEdit valeur] [×]`
2. **Ligne affichage** : `[CheckBox "Interface principale"] [CheckBox "Page de détails"]`
3. **Ligne visibilité** : `[OptionButton "Toujours visible" / "Conditionnelle"] [OptionButton variable]`
   - Le sélecteur de variable n'est visible que si le mode est "Conditionnelle"
   - Le sélecteur de variable est alimenté par `story.get_variable_names()` (sauf la variable elle-même)
4. **Ligne image/description** : `[Button "Image…"] [Label nom_fichier] [LineEdit "Description…"]`
   - Le bouton image ouvre `ImagePickerDialog` en mode FOREGROUND
   - Le label affiche le nom du fichier sélectionné ou "Aucune image"

Un `HSeparator` sépare visuellement chaque bloc de variable.

Les modifications sont appliquées en temps réel sur le modèle `VariableDefinition`.

### Interface principale — Sidebar gauche

Pendant le jeu, une sidebar verticale est affichée sur le côté gauche de l'écran, centrée verticalement.

Pour chaque variable ayant `show_on_main == true` et étant visible (selon la logique de visibilité) :
- Un cercle contenant l'image de la variable (si image définie) ou un cercle vide
- Sous le cercle, la valeur courante de la variable (label centré)
- Cliquer sur un élément ouvre la page de détails

Le cercle est réalisé via un `PanelContainer` avec `StyleBoxFlat` à `corner_radius` élevé et `clip_contents = true`, contenant un `TextureRect`.

### Page de détails

Un overlay plein écran (même pattern que l'overlay de choix) affiche une grille de variables :
- Titre "Détails" en haut
- `ScrollContainer` avec `GridContainer` (3 colonnes)
- Chaque variable avec `show_on_details == true` et visible affiche une carte contenant :
  - L'image (si définie)
  - La description (si définie)
  - La valeur courante
- Bouton "Fermer" en bas

L'overlay bloque les interactions avec le jeu en dessous (même comportement que l'overlay de choix).

### Logique de visibilité

```
Si visibility_mode == "always" → la variable est visible
Si visibility_mode == "variable" :
  - Récupérer la valeur de _variables[visibility_variable]
  - Si la valeur == "1" → visible
  - Sinon (valeur == "0", absente, ou autre) → caché
```

### Mise à jour de l'affichage

L'affichage des variables est mis à jour dans les cas suivants :
1. **Au démarrage du jeu** — après `_init_variables_from_story()`
2. **Après chaque application d'effets** — dans `_apply_effects()`, après les notifications
3. **Au chargement d'une sauvegarde** — après `start_play_from_save()`

Le signal `variables_display_changed` du `StoryPlayController` est connecté au `GamePlayController` qui met à jour la sidebar.

### Nettoyage

Quand le jeu se termine ou est arrêté (`_cleanup_play()`), la sidebar et l'overlay de détails sont masqués.

### i18n

- Les descriptions de variables sont extraites par `StoryI18nService.extract_strings()` et traduites par `apply_to_story()`.
- Les chaînes UI "Détails" et "Fermer" sont ajoutées à `UI_STRINGS`.

### Persistance

Les nouveaux champs sont sérialisés dans le YAML de l'histoire au niveau de chaque variable :

```yaml
variables:
  - name: "score"
    initial_value: "0"
    show_on_main: true
    show_on_details: true
    image: "assets/foregrounds/coin.png"
    description: "Votre score actuel"
  - name: "has_key"
    initial_value: "false"
    show_on_details: true
    visibility_mode: "variable"
    visibility_variable: "key_found"
    image: "assets/foregrounds/key.png"
    description: "Clé magique"
```

Les images de variables sont relocalisées par `StorySaver._relocate_assets()` dans `assets/foregrounds/`.

La rétrocompatibilité est assurée : les histoires existantes sans ces champs se chargent normalement (tous les défauts = pas d'affichage).

## Critères d'acceptation

### Modèle VariableDefinition
- [ ] `VariableDefinition` possède les champs `show_on_main`, `show_on_details`, `visibility_mode`, `visibility_variable`, `image`, `description`
- [ ] Les valeurs par défaut sont correctes (false, false, "always", "", "", "")
- [ ] `to_dict()` n'inclut pas les champs à valeur par défaut
- [ ] `from_dict()` charge correctement tous les nouveaux champs
- [ ] La rétrocompatibilité est assurée (dictionnaire sans champs d'affichage)

### Modèle Story
- [ ] `get_main_display_variables()` retourne uniquement les variables avec `show_on_main == true`
- [ ] `get_details_display_variables()` retourne uniquement les variables avec `show_on_details == true`
- [ ] Les deux méthodes retournent un tableau vide si aucune variable n'est marquée

### Panneau de variables (éditeur)
- [ ] Chaque variable affiche les checkboxes "Interface principale" et "Page de détails"
- [ ] Les checkboxes modifient le modèle en temps réel
- [ ] Le sélecteur de mode de visibilité propose "Toujours visible" et "Conditionnelle"
- [ ] Le sélecteur de variable apparaît uniquement en mode "Conditionnelle"
- [ ] Le sélecteur de variable est alimenté par les noms de variables (sauf la variable courante)
- [ ] Le bouton "Image…" ouvre l'ImagePickerDialog
- [ ] L'image sélectionnée est enregistrée dans le modèle
- [ ] Le champ description est éditable et modifie le modèle

### Sidebar (jeu)
- [ ] La sidebar est masquée par défaut
- [ ] La sidebar s'affiche au démarrage du jeu si des variables sont configurées
- [ ] Seules les variables avec `show_on_main == true` et visibles sont affichées
- [ ] Chaque élément affiche un cercle avec l'image et la valeur en dessous
- [ ] La visibilité mode "always" fonctionne
- [ ] La visibilité mode "variable" avec valeur "1" affiche la variable
- [ ] La visibilité mode "variable" avec valeur "0" ou absente masque la variable
- [ ] La sidebar se met à jour après chaque changement de variable
- [ ] Cliquer sur un élément ouvre la page de détails
- [ ] La sidebar est masquée quand le jeu se termine

### Page de détails (jeu)
- [ ] L'overlay de détails affiche une grille avec image, description et valeur
- [ ] Seules les variables `show_on_details == true` et visibles sont affichées
- [ ] Le bouton "Fermer" masque l'overlay
- [ ] L'overlay bloque les interactions avec le jeu en dessous

### i18n
- [ ] Les descriptions de variables sont extraites par `extract_strings()`
- [ ] Les descriptions sont traduites par `apply_to_story()`
- [ ] Les chaînes "Détails" et "Fermer" sont dans `UI_STRINGS`

### Persistance
- [ ] Les champs d'affichage sont sauvegardés et rechargés correctement en YAML
- [ ] Les histoires sans champs d'affichage se chargent normalement (rétrocompatibilité)
- [ ] Les images de variables sont relocalisées lors de la sauvegarde

### Intégration play controller
- [ ] Le signal `variables_display_changed` est émis au démarrage du jeu
- [ ] Le signal est émis après chaque application d'effets
- [ ] Le signal est émis après le chargement d'une sauvegarde
