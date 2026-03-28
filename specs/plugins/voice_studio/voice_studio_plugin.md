# Voice Studio Plugin

## Description

Plugin d'intégration ElevenLabs pour la synthese vocale des dialogues.
Permet de generer, gerer et stocker des fichiers audio MP3 pour chaque dialogue
d'une sequence, en utilisant l'API Text-to-Speech d'ElevenLabs.

## Architecture

### Fichiers

- `plugins/voice_studio/plugin.gd` : Point d'entree editeur (onglet sequence "Voix")
- `plugins/voice_studio/game_plugin.gd` : Configuration editeur (association personnage / Voice ID)
- `plugins/voice_studio/elevenlabs_config.gd` : Persistance de la cle API et du modele
- `plugins/voice_studio/elevenlabs_client.gd` : Client HTTP pour l'API ElevenLabs TTS
- `plugins/voice_studio/voice_sequence_tab.gd` : UI de l'onglet "Voix" dans l'editeur de sequence

### Modele de donnees

Le `DialogueModel` est etendu avec deux champs optionnels :

- `voice: String` : Description vocale au format ElevenLabs (avec annotations comme `[sarcastically]`, `[whispers]`, `[giggles]`, etc.)
- `voice_file: String` : Chemin relatif vers le fichier MP3 genere (ex: `assets/voices/{uuid}.mp3`)

Ces champs sont omis du YAML s'ils sont vides (retro-compatible).

### Stockage

Les fichiers MP3 sont stockes dans `{story_base_path}/assets/voices/{dialogue_uuid}.mp3`.

### Configuration

#### Cle API ElevenLabs

Stockee dans `user://elevenlabs_config.cfg` (hors de la story, car sensible).
Configurable dans l'onglet "Voix" de l'editeur de sequence.

#### Voice ID par personnage

Stocke dans `story.yaml` sous `plugin_settings.voice_studio.characters` :

```yaml
plugin_settings:
  voice_studio:
    characters:
      - name: "Narrateur"
        voice_id: "abc123def"
      - name: "Heros"
        voice_id: "xyz789ghi"
```

Configurable dans Configurer le jeu > Plugins > Voice Studio.

## Criteres d'acceptation

### Configuration

- [ ] La cle API ElevenLabs est persistee dans `user://elevenlabs_config.cfg`
- [ ] Le modele TTS est configurable (defaut: `eleven_multilingual_v2`)
- [ ] Dans "Configurer le jeu" > Plugins, on peut ajouter/supprimer des associations personnage/Voice ID
- [ ] Les associations sont sauvegardees dans `plugin_settings.voice_studio`

### Editeur de sequence (onglet Voix)

- [ ] L'onglet "Voix" apparait dans le TabContainer de l'editeur de sequence
- [ ] Chaque dialogue est affiche avec : numero, personnage, texte, statut voix
- [ ] Un champ "voice" permet de saisir la description vocale ElevenLabs
- [ ] Un bouton "Generer la voix" / "Regenerer" est present pour chaque dialogue
- [ ] Un bouton "Supprimer la voix" est present si une voix existe
- [ ] Le statut indique "Voix generee" ou "Pas de voix"
- [ ] Le bouton "Generer toutes les voix" genere sequentiellement toutes les voix
- [ ] Si un personnage n'a pas de Voice ID, un message d'erreur est affiche

### Generation

- [ ] La generation utilise `voice` si defini, sinon `text`
- [ ] Le MP3 est sauvegarde dans `assets/voices/{dialogue_uuid}.mp3`
- [ ] Le champ `voice_file` est mis a jour dans le modele
- [ ] Les erreurs API sont affichees dans le label de statut

### YAML

- [ ] `voice` et `voice_file` sont serialises dans le YAML si non vides
- [ ] `voice` et `voice_file` sont omis du YAML si vides (retro-compatible)
- [ ] Le chargement d'un YAML sans `voice`/`voice_file` fonctionne (defaults a "")
