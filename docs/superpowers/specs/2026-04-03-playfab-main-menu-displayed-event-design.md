# PlayFab — Événement `main_menu_displayed`

## Contexte

Quand un joueur ouvre le jeu et que le menu principal s'affiche, on veut envoyer un événement PlayFab contenant la plateforme et la version du jeu. Cela permet d'avoir des analytics sur la répartition des plateformes et versions utilisées par les joueurs.

## Comportement

- L'événement est envoyé **une seule fois par session** (au premier affichage du menu principal).
- Les retours au menu principal (après quitter une partie, fermer la sélection de chapitres, etc.) ne déclenchent **pas** de nouvel événement.

## Données de l'événement

| Champ | Type | Source | Exemple |
|-------|------|--------|---------|
| `platform` | String | `OS.get_name()` + détection mobile browser pour Web | `"Windows"`, `"macOS"`, `"Web_mobile"` |
| `app_version` | String | `ProjectSettings.get_setting("application/config/version", "")` | `"1.2.0"` |
| `story_version` | String | `story.version` | `"1.0.0"` |
| `story_title` | String | `story.title` | `"L'épreuve du héros"` |

### Valeurs de `platform`

- `"Windows"`, `"macOS"`, `"Linux"` — plateformes desktop natives
- `"iOS"`, `"Android"` — plateformes mobiles natives
- `"Web_desktop"` — navigateur desktop (Web + user-agent sans mobile/android/iphone/ipad)
- `"Web_mobile"` — navigateur mobile (Web + user-agent contenant mobile/android/iphone/ipad)

La détection mobile browser réutilise le pattern existant dans `GameSettings._is_mobile_browser()` qui utilise le JavaScript bridge pour lire `navigator.userAgent`.

## Architecture — Nouveau hook plugin

### 1. Classe de base `VBGamePlugin` (`src/plugins/game_plugin.gd`)

Nouveau hook virtuel :

```gdscript
func on_main_menu_displayed(ctx: RefCounted, platform: String, app_version: String, story_version: String) -> void:
    pass
```

### 2. Manager `GamePluginManager` (`src/plugins/game_plugin_manager.gd`)

Nouveau dispatch :

```gdscript
func dispatch_on_main_menu_displayed(ctx: RefCounted, platform: String, app_version: String, story_version: String) -> void:
    for plugin in _get_active_plugins():
        plugin.on_main_menu_displayed(ctx, platform, app_version, story_version)
```

### 3. Point de dispatch dans `game.gd`

- Ajout d'un flag `var _main_menu_event_sent: bool = false`
- Dans `_show_main_menu()`, après l'affichage du menu, si `_main_menu_event_sent == false` :
  - Calculer la plateforme via un helper `_get_platform_string() -> String`
  - Récupérer `app_version` depuis `ProjectSettings`
  - Récupérer `story_version` depuis `_current_story.version`
  - Dispatcher `dispatch_on_main_menu_displayed(ctx, platform, app_version, story_version)`
  - Mettre `_main_menu_event_sent = true`

Helper `_get_platform_string()` — réutilise `GameSettings._is_mobile_browser()` déjà preloadé dans `game.gd` :

```gdscript
func _get_platform_string() -> String:
    var os_name := OS.get_name()
    if os_name == "Web":
        if GameSettings._is_mobile_browser():
            return "Web_mobile"
        return "Web_desktop"
    return os_name
```

### 4. Plugin PlayFab (`plugins/playfab_analytics/game_plugin.gd`)

Implémente le hook :

```gdscript
func on_main_menu_displayed(_ctx: RefCounted, platform: String, app_version: String, story_version: String) -> void:
    if _service == null or not _service.is_active():
        return
    _service.track_event("main_menu_displayed", {
        "platform": platform,
        "app_version": app_version,
        "story_version": story_version,
        "story_title": _story_title,
    })
```

Note : `_story_title` est déjà stocké dans le plugin lors de `on_game_ready()`.

## Tests

### Test unitaire du plugin PlayFab

Dans `specs/plugins/playfab_analytics/test_playfab_analytics_plugin.gd` :

- `test_on_main_menu_displayed_tracks_event` : vérifie que `track_event("main_menu_displayed", ...)` est appelé avec les bonnes données.
- `test_on_main_menu_displayed_inactive_service_does_nothing` : vérifie qu'aucun événement n'est envoyé si le service n'est pas actif.

### Test unitaire du dispatch manager

Dans `specs/plugins/test_game_plugin_manager.gd` (existant) :

- `test_dispatch_on_main_menu_displayed` : vérifie que le hook est bien dispatché aux plugins actifs.

### Test de `_get_platform_string()` dans game.gd

Dans les tests existants de game ou un nouveau fichier si nécessaire :

- `test_get_platform_string_returns_os_name_for_native` : vérifie que les plateformes natives retournent `OS.get_name()` directement.

## Ce qui ne change pas

- `playfab_analytics_service.gd` : aucune modification, on utilise `track_event()` existant
- `main_menu.gd` : aucune modification UI
- Tous les hooks existants : inchangés
- Le namespace de l'événement reste `custom.visualbuilder.main_menu_displayed`
