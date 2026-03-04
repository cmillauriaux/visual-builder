# Système de sauvegarde / chargement en jeu

## Résumé

Le joueur peut sauvegarder sa progression en cours de partie depuis le menu pause, et la reprendre ultérieurement depuis le menu principal ou le menu pause. Chaque sauvegarde capture un screenshot, la position exacte dans l'histoire (chapitre, scène, séquence, dialogue) ainsi que l'état de toutes les variables. Six slots de sauvegarde fixes sont disponibles, présentés dans une grille 3 × 2.

## Comportement attendu

### Sauvegarde

- Le bouton **Sauvegarder** est accessible uniquement depuis le menu pause (en cours de partie).
- Au moment où le joueur ouvre le menu pause, un screenshot de la scène en cours est capturé (sans l'overlay du menu).
- En cliquant sur **Sauvegarder**, le menu pause se ferme et la grille de sauvegarde s'affiche en **mode sauvegarde**.
- La grille comporte 6 slots (3 colonnes × 2 lignes).
  - Un slot **vide** affiche un label "+ Vide" et est cliquable pour sauvegarder.
  - Un slot **occupé** affiche le screenshot, le nom du chapitre, le nom de la scène et la date/heure de la sauvegarde.
- Cliquer sur un slot **vide** sauvegarde immédiatement et ferme la grille (la partie reprend, le jeu se dépause).
- Cliquer sur un slot **occupé** affiche un dialogue de confirmation "Écraser cette sauvegarde ?" avec les boutons **Oui** et **Non**.
  - **Oui** : écrase la sauvegarde, ferme la grille, la partie reprend.
  - **Non** : ferme le dialogue, la grille reste affichée.
- Un bouton **Fermer** (×) sur la grille retourne au menu pause.

### Format de sauvegarde sur disque

```
user://saves/
├── slot_0/save.json
├── slot_0/screenshot.png
├── slot_1/save.json
...
```

`save.json` contient :
```json
{
  "version": 1,
  "timestamp": "2026-03-03 14:30:00",
  "story_path": "user://stories/mon_histoire",
  "chapter_uuid": "...",
  "chapter_name": "Chapitre 1",
  "scene_uuid": "...",
  "scene_name": "Scène 1",
  "sequence_uuid": "...",
  "sequence_name": "Séquence A",
  "dialogue_index": 2,
  "variables": { "hero_trust": 5 }
}
```

### Chargement

- Le bouton **Charger** est accessible depuis le menu pause et depuis le menu principal.
- En cliquant sur **Charger**, la grille de sauvegarde s'affiche en **mode chargement**.
- Chaque slot occupé affiche : screenshot, nom du chapitre, nom de la scène, date/heure, et deux boutons : **Charger** et **Supprimer**.
- Cliquer sur **Charger** :
  - Depuis le menu pause : la partie en cours est abandonnée, la story est rechargée, le jeu reprend au chapitre / scène / séquence / dialogue sauvegardés avec les variables restaurées.
  - Depuis le menu principal : identique, la partie démarre directement au point sauvegardé.
- Cliquer sur **Supprimer** supprime le slot (les fichiers `save.json` et `screenshot.png` sont effacés) et rafraîchit la grille.
- Un bouton **Fermer** (×) retourne au menu pause ou au menu principal selon le contexte.

### Sauvegardes invalides

- Au chargement de la grille, si la `story_path` d'une sauvegarde ne correspond plus à un fichier existant, la sauvegarde est **supprimée automatiquement** et le slot s'affiche comme vide.

### Reprise après chargement

- Le jeu navigue directement jusqu'à la séquence sauvegardée (via UUID) et reprend à l'index de dialogue exact.
- Les variables sont restaurées telles qu'elles étaient au moment de la sauvegarde.
- Les transitions d'entrée de la séquence sont jouées normalement.

## Critères d'acceptation

- [ ] Le screenshot est capturé avant l'affichage du menu pause (la scène est visible sans overlay).
- [ ] La grille affiche 6 slots (3 × 2), vides ou occupés selon les données sur disque.
- [ ] En mode sauvegarde, cliquer un slot vide crée `save.json` et `screenshot.png` dans `user://saves/slot_N/`.
- [ ] En mode sauvegarde, cliquer un slot occupé affiche un dialogue de confirmation avant d'écraser.
- [ ] Après une sauvegarde réussie, le menu se ferme et la partie reprend (jeu dépausé).
- [ ] En mode chargement, chaque slot occupé affiche le bouton **Charger** et le bouton **Supprimer**.
- [ ] Le bouton **Charger** restaure la story, les variables, le chapitre, la scène, la séquence et l'index de dialogue.
- [ ] Le bouton **Supprimer** supprime les fichiers du slot et rafraîchit la grille.
- [ ] Le bouton **Fermer** (×) retourne au contexte précédent (menu pause ou menu principal).
- [ ] Une sauvegarde dont la `story_path` est introuvable est automatiquement supprimée au chargement de la grille.
- [ ] Le chargement depuis le menu pause abandonne la partie en cours et restaure la sauvegarde sans passer par le menu principal.
- [ ] Le chargement depuis le menu principal démarre directement au point sauvegardé.
- [ ] `GameSaveManager` est une classe statique testable indépendamment (sans Godot SceneTree).
