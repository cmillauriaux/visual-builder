# 067 — Détection automatique de la locale au lancement

## Objectif

Quand le joueur ouvre le jeu (web ou desktop) pour la première fois, détecter la locale système/navigateur et sélectionner automatiquement la langue correspondante parmi celles disponibles dans la story.

## Règles

1. **Première ouverture** (aucun fichier `settings.cfg` existant) : détecter la locale courante.
2. **Chaîne de fallback** :
   - Locale détectée → si disponible dans les langues de la story, la sélectionner.
   - Sinon → `"en"` si disponible.
   - Sinon → langue source de la story (`default` dans `languages.yaml`).
3. **Préférence explicite** : si le joueur a déjà choisi une langue via les Options (valeur sauvegardée dans `settings.cfg`), ce choix est respecté — pas d'auto-détection.
4. **Détection de la locale** :
   - **Web** : `navigator.language` via `JavaScriptBridge` (ex: `"fr-FR"` → `"fr"`).
   - **Desktop** : `OS.get_locale_language()` (retourne un code 2 lettres, ex: `"fr"`).

## Architecture

### Nouveau fichier : `src/services/locale_detector.gd`

Classe statique avec deux méthodes :

- `detect_locale() -> String` : retourne un code langue 2 lettres ou `""` en cas d'échec.
- `resolve_language(detected: String, available: Array, default_lang: String) -> String` : fonction pure implémentant la chaîne de fallback.

### Modifications

- **`game_settings.gd`** : le défaut de `language` passe de `"fr"` à `""` (sentinelle = auto-détection). Nouvelle méthode `is_language_auto()`.
- **`game.gd`** : appel à `_auto_detect_language()` dans `_load_story_and_show_menu()` si `is_language_auto()`. Correction du `!= "fr"` hardcodé dans `_reload_i18n()` pour utiliser la langue source configurée.

## Critères d'acceptation

- [ ] `LocaleDetector.detect_locale()` retourne un code 2 lettres sur desktop, utilise `navigator.language` sur web.
- [ ] `LocaleDetector.resolve_language("en", ["fr", "en"], "fr")` retourne `"en"`.
- [ ] `LocaleDetector.resolve_language("de", ["fr", "en"], "fr")` retourne `"en"` (fallback).
- [ ] `LocaleDetector.resolve_language("de", ["fr", "ja"], "fr")` retourne `"fr"` (langue source).
- [ ] `LocaleDetector.resolve_language("", ["fr", "en"], "fr")` retourne `"en"` (fallback quand détection échoue).
- [ ] Au premier lancement sans `settings.cfg`, la langue est auto-détectée.
- [ ] Si le joueur a sauvegardé une préférence de langue, elle est respectée.
- [ ] `_reload_i18n()` utilise la langue source configurée au lieu de `"fr"` hardcodé.
