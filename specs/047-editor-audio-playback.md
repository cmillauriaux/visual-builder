# Spec 047 — Audio en mode Play de l'editeur

## Contexte

En mode jeu standalone, la musique et les FX audio sont joues grace a `GamePlayController` qui utilise un `MusicPlayer`. En mode editeur Play, aucun audio n'etait joue. Cette spec ajoute le support audio au mode Play de l'editeur pour que l'auteur puisse previsualiser le rendu sonore de son histoire.

## Comportement attendu

### Lecture audio pendant le Play

- Quand l'utilisateur lance le Play (sequence unique ou story play), la musique et les FX audio de chaque sequence sont joues exactement comme dans le jeu standalone.
- L'ordre d'execution est identique a la spec 039 : transition_in -> FX visuels -> audio (stop_music -> musique -> FX audio) -> titre -> dialogues.
- La musique boucle en continu entre les sequences (sauf si `stop_music` est active).

### Arret au Stop

- Quand l'utilisateur clique sur le bouton Stop (sequence ou story), toute la musique s'arrete immediatement.
- Les FX en cours s'arretent egalement (le stream player est stoppe).

## Implementation

### MusicPlayer dans l'editeur

- Un `MusicPlayer` est cree dans `main.gd` lors du `_setup_controllers()`.
- Il est assigne a `_play_ctrl._music_player`.
- Le `MusicPlayer` utilise les bus audio "Music" et "FX" definis dans `default_bus_layout.tres`.

### Integration dans PlayController

- `_apply_sequence_audio()` est appele apres les FX visuels, avant le titre/dialogues.
- `on_stop_pressed()` et `_stop_story_play()` appellent `_music_player.stop_music()`.

## Bus audio

Le fichier `default_bus_layout.tres` definit 3 bus :
- **Master** (index 0) — bus par defaut
- **Music** (index 1) — musique d'ambiance, route vers Master
- **FX** (index 2) — effets sonores, route vers Master

## Criteres d'acceptation

- [x] AC1 : Un `MusicPlayer` est cree et branche dans l'editeur
- [x] AC2 : La musique joue pendant le Play editeur (sequence unique)
- [x] AC3 : La musique joue pendant le Story Play editeur
- [x] AC4 : Les FX audio jouent pendant le Play editeur
- [x] AC5 : Toute la musique s'arrete au clic sur Stop
- [x] AC6 : `_apply_sequence_audio()` ne crash pas si music_player ou sequence est null
- [x] AC7 : Le fichier `default_bus_layout.tres` definit les bus Music et FX
