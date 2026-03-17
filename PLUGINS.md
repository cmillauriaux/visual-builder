# Guide de développement de plugins — Visual Builder

Ce document explique comment créer des plugins pour Visual Builder. Il existe deux types de plugins :

- **Plugin éditeur** (`VBPlugin`) — s'intègre dans l'interface de création (menus, toolbars, panneaux, onglets)
- **Plugin in-game** (`VBGamePlugin`) — s'exécute pendant la lecture d'une story (hooks d'événements, transformation de dialogue, UI en jeu)

Un dossier peut contenir les deux types simultanément (ex: `plugins/mon_plugin/plugin.gd` + `plugins/mon_plugin/game_plugin.gd`).

---

## Structure des dossiers

```
plugins/
└── mon_plugin/
    ├── plugin.gd           # Plugin éditeur (optionnel) — extends VBPlugin
    └── game_plugin.gd      # Plugin in-game (optionnel) — extends VBGamePlugin
```

Les plugins sont **découverts automatiquement** au démarrage : le moteur scanne tous les sous-dossiers de `res://plugins/` et charge les fichiers `plugin.gd` et `game_plugin.gd` trouvés.

> Les plugins in-game peuvent aussi être placés dans `res://game_plugins/*/game_plugin.gd` si vous souhaitez les séparer des plugins éditeur.

---

## Plugin éditeur (`VBPlugin`)

### Classe de base

```gdscript
# plugins/mon_plugin/plugin.gd
class_name MonPlugin
extends VBPlugin

func get_plugin_name() -> String:
    return "mon_plugin"  # Identifiant unique, snake_case

func get_menu_entries() -> Array:
    return []  # Entrées dans les menus

func get_toolbar_items() -> Array:
    return []  # Boutons dans les toolbars

func get_dock_panels() -> Array:
    return []  # Panneaux latéraux/inférieurs

func get_sequence_tabs() -> Array:
    return []  # Onglets dans l'éditeur de séquence

func get_background_services() -> Array:
    return []  # Services Node en arrière-plan

func get_image_picker_tabs() -> Array:
    return []  # Onglets dans le sélecteur d'images
```

Seules les méthodes que vous souhaitez utiliser ont besoin d'être surchargées.

### PluginContext

Le `PluginContext` est passé à chaque callback. Il donne accès à la story ouverte et au nœud principal de l'UI.

```gdscript
ctx.story              # Story courante (peut être null)
ctx.story_base_path    # Chemin absolu du dossier de la story
ctx.current_chapter    # Chapitre sélectionné (peut être null)
ctx.current_scene      # Scène sélectionnée (peut être null)
ctx.current_sequence   # Séquence sélectionnée (peut être null)
ctx.main_node          # Control racine de l'éditeur (pour add_child)
```

> **Important** : le contexte n'est valide que pendant l'exécution du callback. Ne pas le stocker.

### Contributions disponibles

#### MenuEntry — Ajouter une entrée dans un menu

```gdscript
func get_menu_entries() -> Array:
    var entry = Contributions.MenuEntry.new()
    entry.menu_id = "parametres"  # "parametres" ou "histoire"
    entry.label = "Mon outil"
    entry.callback = func(ctx: PluginContext):
        if ctx.story == null:
            return
        # Ouvrir une fenêtre, déclencher une action…
        var dlg = Window.new()
        ctx.main_node.add_child(dlg)
        dlg.popup_centered()
    return [entry]
```

#### ToolbarItem — Bouton dans une toolbar

```gdscript
func get_toolbar_items() -> Array:
    var item = Contributions.ToolbarItem.new()
    item.level = "sequence"   # "chapter", "scene" ou "sequence"
    item.label = "Analyser"
    item.icon = null          # Texture2D optionnelle
    item.callback = func(ctx: PluginContext):
        print("Séquence courante : ", ctx.current_sequence)
    return [item]
```

#### DockPanelDef — Panneau latéral ou inférieur

```gdscript
func get_dock_panels() -> Array:
    var panel_def = Contributions.DockPanelDef.new()
    panel_def.position = "right"   # "left", "right" ou "bottom"
    panel_def.title = "Mon panneau"
    panel_def.create_panel = func(ctx: PluginContext) -> Control:
        var panel = Label.new()
        panel.text = "Contenu du panneau"
        return panel
    return [panel_def]
```

#### SequenceTabDef — Onglet dans l'éditeur de séquence

```gdscript
func get_sequence_tabs() -> Array:
    var tab_def = Contributions.SequenceTabDef.new()
    tab_def.title = "Mon onglet"
    tab_def.create_tab = func(ctx: PluginContext) -> Control:
        var label = Label.new()
        label.text = "Contenu de l'onglet"
        return label
    return [tab_def]
```

#### BackgroundServiceDef — Service Node en arrière-plan

```gdscript
func get_background_services() -> Array:
    var svc = Contributions.BackgroundServiceDef.new()
    svc.service_script = preload("res://plugins/mon_plugin/mon_service.gd")
    svc.setup_callback = func(node: Node, ctx: PluginContext):
        node.configure(ctx.story_base_path)
    return [svc]
```

#### ImagePickerTabDef — Onglet dans le sélecteur d'images

```gdscript
func get_image_picker_tabs() -> Array:
    var tab_def = Contributions.ImagePickerTabDef.new()
    tab_def.label = "Ma source d'images"
    tab_def.create_tab = func(ctx: PluginContext) -> Control:
        var panel = VBoxContainer.new()
        return panel
    return [tab_def]
```

### Exemple complet — plugin éditeur

```gdscript
# plugins/mon_outil/plugin.gd
class_name MonOutilPlugin
extends VBPlugin

const MonDialog = preload("res://plugins/mon_outil/mon_dialog.gd")

func get_plugin_name() -> String:
    return "mon_outil"

func get_menu_entries() -> Array:
    var entry = Contributions.MenuEntry.new()
    entry.menu_id = "parametres"
    entry.label = "Mon outil"
    entry.callback = func(ctx: PluginContext):
        _open_dialog(ctx)
    return [entry]

func _open_dialog(ctx: PluginContext) -> void:
    if ctx.story == null:
        return
    var dlg = Window.new()
    dlg.set_script(MonDialog)
    ctx.main_node.add_child(dlg)
    dlg.setup(ctx.story, ctx.story_base_path)
    dlg.popup_centered()
```

---

## Plugin in-game (`VBGamePlugin`)

### Classe de base

```gdscript
# plugins/mon_plugin/game_plugin.gd
class_name MonGamePlugin
extends VBGamePlugin

func get_plugin_name() -> String:
    return "mon_plugin"  # Identifiant unique

func get_plugin_description() -> String:
    return "Description courte affichée dans les options"

func is_configurable() -> bool:
    return true  # true = toggle dans les options ; false = toujours actif
```

### GamePluginContext

Passé à chaque hook et pipeline :

```gdscript
ctx.story                   # Story courante
ctx.story_base_path         # Chemin du dossier de la story
ctx.current_chapter         # Chapitre en cours
ctx.current_scene           # Scène en cours
ctx.current_sequence        # Séquence en cours
ctx.current_dialogue_index  # Index du dialogue affiché (-1 si aucun)
ctx.variables               # Dictionary en lecture/écriture (variables de story)
ctx.game_node               # Control racine du jeu (pour popups/overlays)
ctx.settings                # GameSettings (préférences joueur)
```

### Hooks lifecycle

```gdscript
func on_game_ready(ctx: RefCounted) -> void:
    # Story chargée, UI construite — initialiser vos ressources
    pass

func on_game_cleanup(ctx: RefCounted) -> void:
    # Nettoyage avant fermeture
    pass
```

### Hooks de navigation

Appelés à chaque transition de chapitre, scène et séquence :

```gdscript
func on_before_chapter(ctx: RefCounted) -> void: pass
func on_after_chapter(ctx: RefCounted) -> void: pass

func on_before_scene(ctx: RefCounted) -> void: pass
func on_after_scene(ctx: RefCounted) -> void: pass

func on_before_sequence(ctx: RefCounted) -> void: pass
func on_after_sequence(ctx: RefCounted) -> void: pass
```

### Pipeline de transformation

Ces méthodes peuvent modifier le contenu avant affichage. Elles sont **chaînées** : la sortie du plugin N devient l'entrée du plugin N+1.

#### Transformer un dialogue

```gdscript
func on_before_dialogue(ctx: RefCounted, character: String, text: String) -> Dictionary:
    # Modifier le texte ou le personnage
    text = text.replace("gros mot", "*****")
    return {"character": character, "text": text}

func on_after_dialogue(ctx: RefCounted, character: String, text: String) -> void:
    # Réagir après affichage (analytics, effets…)
    pass
```

> **Important** : `on_before_dialogue` doit toujours retourner `{"character": ..., "text": ...}`.

#### Transformer les choix

```gdscript
func on_before_choice(ctx: RefCounted, choices: Array) -> Array:
    # Filtrer ou modifier les choix disponibles
    return choices  # Retourner la liste (modifiée ou non)

func on_after_choice(ctx: RefCounted, choice_index: int, choice_text: String) -> void:
    pass
```

### Hooks de cycle de vie de la story

```gdscript
func on_story_started(ctx: RefCounted, story_title: String, story_version: String) -> void:
    pass  # Nouvelle partie démarrée

func on_story_finished(ctx: RefCounted, reason: String) -> void:
    pass  # Story terminée ("completed", "abandoned"…)

func on_story_saved(ctx: RefCounted, story_title: String, slot_index: int,
                    chapter: String, scene: String, sequence: String) -> void:
    pass

func on_story_loaded(ctx: RefCounted, story_title: String, slot_index: int) -> void:
    pass

func on_game_quit(ctx: RefCounted, chapter: String, scene: String, sequence: String) -> void:
    pass

func on_quicksave(ctx: RefCounted, story_title: String, chapter: String) -> void:
    pass

func on_quickload(ctx: RefCounted, story_title: String) -> void:
    pass
```

### Contributions UI in-game

#### GameToolbarButton — Bouton dans la toolbar au-dessus du dialogue

```gdscript
func get_toolbar_buttons() -> Array:
    var btn = GameContributions.GameToolbarButton.new()
    btn.label = "Journal"
    btn.icon = null  # Texture2D optionnelle
    btn.callback = func(ctx):
        _show_journal(ctx)
    return [btn]
```

#### GameOverlayPanelDef — Panneau overlay

```gdscript
func get_overlay_panels() -> Array:
    var panel_def = GameContributions.GameOverlayPanelDef.new()
    panel_def.position = "left"   # "left", "right" ou "top"
    panel_def.create_panel = func(ctx) -> Control:
        var panel = VBoxContainer.new()
        return panel
    return [panel_def]
```

#### GameOptionsControlDef — Contrôle personnalisé dans les options

```gdscript
func get_options_controls() -> Array:
    var opt = GameContributions.GameOptionsControlDef.new()
    opt.create_control = func(ctx) -> Control:
        var toggle = CheckBox.new()
        toggle.text = "Activer les notifications"
        return toggle
    return [opt]
```

#### get_editor_config_controls — Configuration dans l'éditeur

Appelé dans l'onglet Plugins du dialogue de configuration du jeu. Reçoit un `Dictionary` avec les `plugin_settings` du plugin.

```gdscript
func get_editor_config_controls() -> Array:
    var opt = GameContributions.GameOptionsControlDef.new()
    opt.create_control = func(settings: Dictionary) -> Control:
        var field = LineEdit.new()
        field.placeholder_text = "API Key"
        field.text = settings.get("api_key", "")
        return field
    return [opt]
```

### Activation et persistance

Si `is_configurable()` retourne `true`, un toggle apparaît automatiquement dans la section **Plugins** du menu Options. L'état activé/désactivé est persisté entre les sessions dans les GameSettings.

Un plugin désactivé ne reçoit **aucun hook** (ni lifecycle, ni pipeline, ni UI).

### Exemple complet — plugin in-game

```gdscript
# plugins/analytics/game_plugin.gd
class_name AnalyticsPlugin
extends VBGamePlugin

func get_plugin_name() -> String:
    return "analytics"

func get_plugin_description() -> String:
    return "Enregistre les événements de jeu pour l'analytics"

func is_configurable() -> bool:
    return false  # Toujours actif (contrôlé par la story)

func on_story_started(ctx: RefCounted, story_title: String, story_version: String) -> void:
    _send_event("story_started", {"title": story_title, "version": story_version})

func on_before_chapter(ctx: RefCounted) -> void:
    if ctx.current_chapter:
        _send_event("chapter_entered", {"chapter": ctx.current_chapter.title})

func on_after_choice(ctx: RefCounted, choice_index: int, choice_text: String) -> void:
    _send_event("choice_made", {"index": choice_index, "text": choice_text})

func _send_event(event_name: String, data: Dictionary) -> void:
    # Envoi à votre service d'analytics
    print("[analytics] ", event_name, " — ", data)
```

---

## Plugins existants

| Dossier | Type | Description |
|---|---|---|
| `plugins/ai_studio/` | Éditeur | Studio IA (génération d'images via ComfyUI) |
| `plugins/censure/` | In-game | Remplace les mots inappropriés par ***** |
| `plugins/playfab_analytics/` | In-game | Envoi d'événements à PlayFab Analytics |

---

## Bonnes pratiques

- **Ne pas stocker le contexte** : `PluginContext` et `GamePluginContext` ne sont valides que pendant l'exécution du callback.
- **Noms uniques** : `get_plugin_name()` doit retourner un identifiant unique en snake_case. Un nom vide fait que le plugin est ignoré.
- **Pipelines** : les méthodes `on_before_dialogue` et `on_before_choice` doivent toujours retourner une valeur (même si inchangée), sinon la chaîne se rompt.
- **Tests** : placer les tests dans `specs/plugins/<nom_plugin>/test_<nom_plugin>_plugin.gd`. Consulter `specs/plugins/test_censure_plugin.gd` pour un exemple.
- **Un plugin = un dossier** : tout le code du plugin (scripts, assets) dans `plugins/<nom>/`.
