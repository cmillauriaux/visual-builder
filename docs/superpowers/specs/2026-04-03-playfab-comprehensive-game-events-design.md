# PlayFab — Événements complets de tracking joueur

## Contexte

On veut pouvoir reconstruire la configuration et le parcours complet du joueur via PlayFab Analytics. Les hooks existants couvrent la navigation story (chapter, scene, sequence, choice) et le cycle de vie (start, finish, save, load, quit). Il manque les interactions UI, les options, les liens externes, les écrans de fin, le premium code, le skip, l'auto-play, l'historique et le PWA prompt.

## Architecture — Hook générique `on_game_event`

Plutôt que d'ajouter un hook typé par événement (11 hooks × 4 fichiers), on ajoute un **unique hook générique** dans le système de plugins :

```gdscript
func on_game_event(ctx: RefCounted, event_name: String, data: Dictionary) -> void:
    pass
```

Les hooks existants (`on_before_chapter`, `on_story_started`, etc.) restent inchangés — le hook générique est complémentaire, pas un remplacement.

### Dispatch dans le manager

```gdscript
func dispatch_on_game_event(ctx: RefCounted, event_name: String, data: Dictionary) -> void:
    for plugin in _get_active_plugins():
        plugin.on_game_event(ctx, event_name, data)
```

### Implémentation PlayFab

```gdscript
func on_game_event(_ctx: RefCounted, event_name: String, data: Dictionary) -> void:
    if _service == null or not _service.is_active():
        return
    _service.track_event(event_name, data)
```

Le namespace PlayFab sera `custom.visualbuilder.<event_name>`.

## Événements ajoutés

### 1. `options_changed`

**Déclencheur :** Joueur applique les options (game.gd `_on_options_applied()`).

**Payload :**
```
{
    "music_enabled": bool, "music_volume": int,
    "voice_enabled": bool, "voice_volume": int, "voice_language": String,
    "fx_enabled": bool, "fx_volume": int,
    "language": String, "fullscreen": bool,
    "auto_play_enabled": bool, "auto_play_delay": float,
    "typewriter_speed": float, "dialogue_opacity": int,
    "autosave_enabled": bool, "ui_scale_mode": int,
    "toolbar_visible": bool
}
```

### 2. `external_link_opened`

**Déclencheur :** Joueur clique sur un lien Patreon ou itch.io.

**Sources :** `main_menu.gd`, `pause_menu.gd`, `ending_screen.gd`, `premium_code/game_plugin.gd`.

**Mécanisme :** Chaque script émet un nouveau signal `external_link_opened(link_type: String, context: String)`. `game.gd` se connecte à ces signaux et dispatch via `dispatch_on_game_event`.

**Payload :**
```
{ "link_type": "patreon" | "itchio", "context": "main_menu" | "pause" | "ending" | "premium_code" }
```

### 3. `ending_screen_displayed`

**Déclencheur :** Écran Game Over ou To Be Continued affiché (game.gd, là où on appelle `show_screen()`).

**Payload :**
```
{ "type": "game_over" | "to_be_continued" }
```

### 4. `ending_screen_action`

**Déclencheur :** Joueur clique un bouton sur l'écran de fin (game.gd handlers de `back_to_menu_pressed` / `load_last_autosave_pressed`).

**Payload :**
```
{ "type": "game_over" | "to_be_continued", "action": "back_to_menu" | "load_autosave" }
```

### 5. `premium_code_attempt`

**Déclencheur :** Joueur valide un code dans le plugin premium code.

**Mécanisme :** Le plugin `premium_code/game_plugin.gd` émet un nouveau signal `code_attempt(success: bool, chapter_uuid: String)`. `game.gd` se connecte et dispatch.

**Payload :**
```
{ "success": bool, "chapter_uuid": String }
```

### 6. `premium_code_purchase_link`

**Déclencheur :** Joueur clique "Obtenir le jeu complet" dans le popup premium code.

**Mécanisme :** Le plugin émet un signal `purchase_link_opened(url: String)`. `game.gd` dispatch.

**Payload :**
```
{ "url": String }
```

### 7. `skip_used`

**Déclencheur :** Joueur clique Skip (game.gd via play controller).

**Payload :**
```
{ "chapter": String, "scene": String, "sequence": String }
```

### 8. `auto_play_toggled`

**Déclencheur :** Joueur active/désactive l'auto-play (game.gd via play controller signal).

**Payload :**
```
{ "enabled": bool, "delay": float }
```

### 9. `history_opened`

**Déclencheur :** Joueur ouvre le panneau d'historique (game.gd via play controller).

**Payload :**
```
{ "entry_count": int }
```

### 10. `pwa_prompt_response`

**Déclencheur :** Joueur répond au prompt d'installation PWA (game.gd `_on_pwa_prompt_closed()`).

**Payload :**
```
{ "dismissed": bool, "platform": "iOS" | "Android" }
```

### 11. `save_deleted`

**Déclencheur :** Joueur supprime une sauvegarde (game.gd `_on_delete_slot()`).

**Payload :**
```
{ "slot_index": int }
```

## Points de dispatch

| Événement | Script source | Mécanisme |
|-----------|--------------|-----------|
| `options_changed` | `game.gd` — `_on_options_applied()` | Dispatch direct |
| `external_link_opened` | `main_menu.gd`, `pause_menu.gd`, `ending_screen.gd`, `premium_code` | Signal → game.gd → dispatch |
| `ending_screen_displayed` | `game.gd` — appels à `show_screen()` | Dispatch direct |
| `ending_screen_action` | `game.gd` — handlers signaux ending screens | Dispatch direct |
| `premium_code_attempt` | `premium_code/game_plugin.gd` | Signal → game.gd → dispatch |
| `premium_code_purchase_link` | `premium_code/game_plugin.gd` | Signal → game.gd → dispatch |
| `skip_used` | `game.gd` — handler skip | Dispatch direct |
| `auto_play_toggled` | `game.gd` — handler auto-play | Dispatch direct |
| `history_opened` | `game.gd` — handler history | Dispatch direct |
| `pwa_prompt_response` | `game.gd` — `_on_pwa_prompt_closed()` | Dispatch direct |
| `save_deleted` | `game.gd` — `_on_delete_slot()` | Dispatch direct |

8 dispatches sont directs dans game.gd. 3 nécessitent de nouveaux signaux (liens externes × 4 scripts, premium code × 2 signaux).

## Signaux ajoutés

### Scripts UI existants

**`main_menu.gd`** : `signal external_link_opened(link_type: String, context: String)`
- Émis dans `_on_patreon_pressed()` avec `("patreon", "main_menu")`
- Émis dans `_on_itchio_pressed()` avec `("itchio", "main_menu")`

**`pause_menu.gd`** : `signal external_link_opened(link_type: String, context: String)`
- Émis dans `_on_patreon_pressed()` avec `("patreon", "pause")`
- Émis dans `_on_itchio_pressed()` avec `("itchio", "pause")`

**`ending_screen.gd`** : `signal external_link_opened(link_type: String, context: String)`
- Émis dans `_on_patreon_pressed()` avec `("patreon", "ending")`
- Émis dans `_on_itchio_pressed()` avec `("itchio", "ending")`

### Plugin premium code

**`plugins/premium_code/game_plugin.gd`** :
- `signal code_attempt(success: bool, chapter_uuid: String)` — émis après validation du code
- `signal purchase_link_opened(url: String)` — émis au clic "Obtenir le jeu complet"
- `signal external_link_opened(link_type: String, context: String)` — émis avec `("itchio", "premium_code")` ou `("patreon", "premium_code")` au clic sur le lien d'achat

**Note :** Le premium_code plugin étend `RefCounted` (via `VBGamePlugin`), pas `Node`. Les signaux ne sont pas disponibles sur `RefCounted` en Godot. Il faudra donc passer par un callback ou stocker les événements à dispatcher dans le contexte. L'approche la plus simple : ajouter un `Callable` dans le `GamePluginContext` que les plugins peuvent appeler pour émettre des game events. Voir section suivante.

## Mécanisme de dispatch depuis les plugins

Les plugins (`RefCounted`) n'ont pas de signaux Godot. Pour qu'un plugin (comme premium_code) puisse émettre des game events, on ajoute un `Callable` au contexte :

```gdscript
# Dans GamePluginContext
var emit_game_event: Callable = Callable()  # (event_name: String, data: Dictionary)
```

`game.gd` configure ce callable lors de la construction du contexte :

```gdscript
func _build_game_plugin_context() -> RefCounted:
    var ctx := GamePluginContextScript.new()
    # ... existant ...
    ctx.emit_game_event = func(event_name: String, data: Dictionary):
        if _game_plugin_manager:
            _game_plugin_manager.dispatch_on_game_event(ctx, event_name, data)
    return ctx
```

Le premium_code plugin utilise alors :

```gdscript
ctx.emit_game_event.call("premium_code_attempt", {"success": true, "chapter_uuid": uuid})
ctx.emit_game_event.call("external_link_opened", {"link_type": "itchio", "context": "premium_code"})
```

## Fichiers modifiés

| Fichier | Modification |
|---------|-------------|
| `src/plugins/game_plugin.gd` | Ajout hook `on_game_event(ctx, event_name, data)` |
| `src/plugins/game_plugin_manager.gd` | Ajout `dispatch_on_game_event(ctx, event_name, data)` |
| `src/plugins/game_plugin_context.gd` | Ajout `var emit_game_event: Callable` |
| `plugins/playfab_analytics/game_plugin.gd` | Implémente `on_game_event` → `track_event` |
| `src/game.gd` | Configure `emit_game_event` dans le contexte + 8 dispatches directs |
| `src/ui/menu/main_menu.gd` | Signal `external_link_opened` + émission |
| `src/ui/menu/pause_menu.gd` | Signal `external_link_opened` + émission |
| `src/ui/menu/ending_screen.gd` | Signal `external_link_opened` + émission |
| `plugins/premium_code/game_plugin.gd` | Appels `ctx.emit_game_event.call(...)` |
| `specs/plugins/test_game_plugin_manager.gd` | Tests dispatch `on_game_event` |
| `specs/plugins/playfab_analytics/test_playfab_analytics_plugin.gd` | Tests `on_game_event` PlayFab |

## Ce qui ne change pas

- `playfab_analytics_service.gd` : aucune modification, on utilise `track_event()` existant
- Tous les hooks existants : inchangés (`on_before_chapter`, `on_story_started`, etc.)
- Le hook `on_main_menu_displayed` récemment ajouté : inchangé
- Le namespace PlayFab reste `custom.visualbuilder.*`

## Tests

### Hook générique
- `on_game_event` existe dans la base class (no-op)
- `dispatch_on_game_event` dispatche aux plugins actifs, skip les désactivés
- PlayFab `on_game_event` appelle `track_event(event_name, data)`, safe sans service

### Signaux UI
- `main_menu.gd` émet `external_link_opened` au clic Patreon/itch.io
- `pause_menu.gd` idem
- `ending_screen.gd` idem

### Contexte emit_game_event
- Le callable `emit_game_event` dans le contexte dispatche correctement
- Un plugin appelant `ctx.emit_game_event.call(...)` déclenche bien le dispatch
