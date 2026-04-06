# Plugin Bug Report

## Résumé

Plugin in-game permettant au joueur de signaler un bug via un bouton « Bug ? » dans la toolbar. Le rapport est envoyé par email via le service [FormSubmit.co](https://formsubmit.co/) (requête HTTP POST) et contient automatiquement les informations système et de navigation (OS, version du jeu, version du moteur, chapitre, scène, séquence) ainsi que le commentaire du joueur.

## Configuration (plugin_settings)

Dans `story.yaml` :

```yaml
plugin_settings:
  bug_report:
    email: "bugs@example.com"
```

- `email` (String, requis) : adresse email de destination du rapport de bug (utilisée comme endpoint FormSubmit.co).

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
- Bouton OK : « Envoyer » — envoie le rapport via FormSubmit.co (requête HTTP).
- Bouton Annuler : ferme la fenêtre sans action.

### Feedback utilisateur

Après le clic sur « Envoyer » :
- Le bouton « Envoyer » est désactivé et son texte passe à « Envoi en cours... ».
- **En cas de succès** (code HTTP 200) : le dialog affiche un message de confirmation (« Rapport envoyé ! Merci. ») pendant 2 secondes, puis se ferme automatiquement.
- **En cas d'erreur** (code HTTP != 200 ou erreur réseau) : un label d'erreur s'affiche (« Erreur lors de l'envoi. Veuillez réessayer. ») et le bouton redevient actif.

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

### Envoi via FormSubmit.co

- **Endpoint** : `https://formsubmit.co/ajax/{email}` (POST)
- **Content-Type** : `application/json`
- **Body JSON** :
  ```json
  {
    "_subject": "[Bug Report] {story_title} v{story_version}",
    "_captcha": "false",
    "_template": "box",
    "Commentaire": "{commentaire}",
    "OS": "{os}",
    "Version du jeu": "{game_version}",
    "Version du moteur": "{engine_version}",
    "Chapitre": "{chapter}",
    "Scène": "{scene}",
    "Séquence": "{sequence}"
  }
  ```

L'envoi utilise un nœud `HTTPRequest` Godot pour envoyer la requête POST. Aucun client email local n'est nécessaire.

## Comportement

- Le plugin est **toujours actif** (`is_configurable() -> false`) — il se désactive silencieusement si aucun email n'est configuré (pas de bouton toolbar).
- `on_game_ready()` : charge les `plugin_settings` pour récupérer l'email.
- Le contexte (`ctx`) est mis à jour à chaque appel du callback toolbar pour refléter la navigation courante.

## Critères d'acceptation

- [ ] Le plugin est découvert automatiquement par le `GamePluginManager`.
- [ ] Le bouton « Bug ? » apparaît dans la toolbar quand un email est configuré.
- [ ] Le bouton n'apparaît PAS si aucun email n'est configuré.
- [ ] La fenêtre affiche les infos système correctes.
- [ ] Le clic sur « Envoyer » envoie une requête POST à `https://formsubmit.co/ajax/{email}` avec le JSON correct.
- [ ] Le bouton est désactivé pendant l'envoi (« Envoi en cours... »).
- [ ] Un message de succès s'affiche après un envoi réussi, puis le dialog se ferme.
- [ ] Un message d'erreur s'affiche en cas d'échec, et le bouton redevient actif.
- [ ] Le plugin expose un contrôle éditeur pour configurer l'email.
- [ ] Les tests unitaires couvrent : identité du plugin, chargement config, génération du JSON, construction de l'URL endpoint, toolbar button conditionnel, feedback succès/erreur.
