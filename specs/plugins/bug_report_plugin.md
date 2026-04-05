# Plugin Bug Report

## Résumé

Plugin in-game permettant au joueur de signaler un bug via un bouton « Bug ? » dans la toolbar. Le rapport est envoyé par email via `mailto:` et contient automatiquement les informations système et de navigation (OS, version du jeu, version du moteur, chapitre, scène, séquence) ainsi que le commentaire du joueur.

## Configuration (plugin_settings)

Dans `story.yaml` :

```yaml
plugin_settings:
  bug_report:
    email: "bugs@example.com"
```

- `email` (String, requis) : adresse email de destination du rapport de bug.

### Configuration éditeur

Le plugin expose un contrôle éditeur (`get_editor_config_controls()`) avec un champ `LineEdit` pour saisir l'adresse email.

## Interface utilisateur

### Bouton toolbar

- Un `GameToolbarButton` avec le label **« Bug ? »** est ajouté dans la toolbar au-dessus du dialogue (côté gauche).
- Au clic, ouvre la fenêtre de rapport de bug.

### Fenêtre de rapport

- `AcceptDialog` modale ajoutée au `game_node`.
- Titre : « Signaler un bug »
- Contenu :
  - Label d'instructions : « Décrivez le problème rencontré : »
  - `TextEdit` multiligne pour le commentaire du joueur (minimum 4 lignes visibles).
  - Label récapitulatif (read-only) affichant les informations système collectées automatiquement.
- Bouton OK : « Envoyer » — ouvre le client email via `mailto:` avec le rapport pré-rempli.
- Bouton Annuler : ferme la fenêtre sans action.

### Informations collectées

Le rapport inclut automatiquement :

| Champ | Source |
|-------|--------|
| OS | `OS.get_name()` |
| Version du jeu | `ProjectSettings.get_setting("application/config/version", "inconnue")` |
| Version du moteur | `Engine.get_version_info().string` |
| Chapitre | `ctx.current_chapter.chapter_name` (ou « Aucun ») |
| Scène | `ctx.current_scene.scene_name` (ou « Aucune ») |
| Séquence | `ctx.current_sequence.title` (ou « Aucune ») |

### Format du mail

- **To** : adresse configurée dans `plugin_settings`
- **Subject** : `[Bug Report] {story_title} v{story_version}`
- **Body** :
  ```
  Commentaire du joueur :
  {commentaire}

  --- Informations système ---
  OS : {os}
  Version du jeu : {game_version}
  Version du moteur : {engine_version}
  Chapitre : {chapter}
  Scène : {scene}
  Séquence : {sequence}
  ```

L'envoi utilise `OS.shell_open("mailto:...")` qui ouvre le client email par défaut du joueur.

## Comportement

- Le plugin est **toujours actif** (`is_configurable() -> false`) — il se désactive silencieusement si aucun email n'est configuré (pas de bouton toolbar).
- `on_game_ready()` : charge les `plugin_settings` pour récupérer l'email.
- Le contexte (`ctx`) est mis à jour à chaque appel du callback toolbar pour refléter la navigation courante.

## Critères d'acceptation

- [ ] Le plugin est découvert automatiquement par le `GamePluginManager`.
- [ ] Le bouton « Bug ? » apparaît dans la toolbar quand un email est configuré.
- [ ] Le bouton n'apparaît PAS si aucun email n'est configuré.
- [ ] La fenêtre affiche les infos système correctes.
- [ ] Le clic sur « Envoyer » appelle `OS.shell_open` avec une URL `mailto:` correctement encodée.
- [ ] Le plugin expose un contrôle éditeur pour configurer l'email.
- [ ] Les tests unitaires couvrent : identité du plugin, chargement config, génération du body, génération de l'URL mailto, toolbar button conditionnel.
