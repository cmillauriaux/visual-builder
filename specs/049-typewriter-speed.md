# Spec 049 — Vitesse du texte configurable (typewriter speed)

## Contexte

Le typewriter affiche le texte caractere par caractere a 30ms fixe (hardcode dans `game_ui_builder.gd`). Les joueurs n'ont aucun moyen de personnaliser cette vitesse. C'est un standard des visual novels que de proposer ce reglage.

## Objectif

Permettre au joueur de configurer la vitesse d'affichage du texte (typewriter) dans les options du jeu. Quatre niveaux : Lent (60ms), Normal (30ms), Rapide (15ms), Instantane (0ms). Le reglage est persiste dans `user://settings.cfg` et applique immediatement sans redemarrage.

## Architecture

### Fichiers modifies

| Fichier | Modification |
|---------|-------------|
| `src/ui/menu/game_settings.gd` | Ajout propriete `typewriter_speed`, constantes, persistence |
| `src/ui/menu/options_menu.gd` | Ajout OptionButton "Vitesse texte" dans la section Gameplay |
| `src/controllers/game_play_controller.gd` | Logique vitesse + mode instantane |
| `src/game.gd` | Propagation du setting au controleur |
| `specs/ui/menu/test_game_settings.gd` | Tests unitaires settings |
| `specs/ui/menu/test_options_menu.gd` | Tests unitaires UI |

### Fichiers crees

| Fichier | Role |
|---------|------|
| `specs/049-typewriter-speed.md` | Cette specification |

## Details techniques

### Mode Instantane (0ms)

Quand `typewriter_speed == 0.0`, le Timer n'est jamais demarre. On appelle `skip_typewriter()` directement, ce qui affiche tout le texte d'un coup. Si auto-play est actif, le timer auto-play demarre immediatement apres.

### Propagation du setting

Identique au pattern `auto_play_delay` : le setting est lu dans `game.gd._ready()` et `_on_options_applied()`, puis passe au controleur via `set_typewriter_speed()`.

## Criteres d'acceptation

- [ ] Controle de vitesse dans les options (Lent/Normal/Rapide/Instantane)
- [ ] Valeurs : 60ms (lent), 30ms (normal), 15ms (rapide), 0ms (instantane)
- [ ] Persistance dans `user://settings.cfg` section `[gameplay]`
- [ ] Application immediate sans redemarrage du jeu
- [ ] Mode instantane affiche tout le texte d'un coup sans typewriter
- [ ] Compatible avec l'auto-play (timer auto-play demarre apres affichage instantane)
- [ ] Les tests GUT passent
