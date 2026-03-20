# 072 — Plugin Launcher (in-game)

## Résumé

Plugin in-game qui affiche une séquence d'écrans de lancement avant le démarrage de la story :

1. **Logo studio** — Logo personnalisé sur fond noir plein écran pendant 2 secondes (image configurable via asset/galerie)
2. **Logo moteur** — Logo Godot (activable/désactivable, **coché par défaut**)
3. **Disclaimer** — Texte « DISCLAIMER » en gros en rouge
4. **Texte libre** — Texte personnalisable affiché en blanc sur fond noir

Chaque étape peut être activée/désactivée individuellement. Par défaut, seul le logo moteur est activé.

## Modèle de données

### Configuration (stockée dans `story.plugin_settings["launcher"]`)

```yaml
launcher:
  studio_logo_enabled: false
  studio_logo_path: ""           # Chemin relatif vers l'image (assets/)
  studio_logo_duration: 2.0      # Durée d'affichage en secondes
  engine_logo_enabled: true      # Coché par défaut
  engine_logo_duration: 2.0
  disclaimer_enabled: false
  disclaimer_text: "DISCLAIMER"
  disclaimer_duration: 3.0
  free_text_enabled: false
  free_text_content: ""
  free_text_duration: 3.0
```

## Comportement attendu

### Séquence de lancement

1. Quand le jeu est prêt (`on_game_ready`, avant l'affichage du menu principal), le plugin crée un overlay plein écran noir
2. Les étapes activées sont jouées dans l'ordre : logo studio → logo moteur → disclaimer → texte libre
3. Chaque étape s'affiche avec un fade-in de 0.3s, reste visible pendant la durée configurée, puis fait un fade-out de 0.3s
4. Après la dernière étape, l'overlay est supprimé et le jeu continue normalement
5. Un clic ou appui sur une touche pendant une étape permet de passer à l'étape suivante (skip)

### Affichage de chaque étape

- **Logo studio** : Image centrée sur fond noir, taille maximale 512×512 pixels, aspect ratio préservé
- **Logo moteur** : Texte « Made with Godot Engine » centré avec le logo Godot intégré (ou texte seul si l'icône n'est pas disponible)
- **Disclaimer** : Texte en majuscules, rouge (`Color(1, 0, 0)`), grande police (taille 48), centré
- **Texte libre** : Texte blanc, police normale (taille 24), centré, multiligne

### Configuration éditeur

Le plugin fournit des contrôles dans le dialogue de configuration du jeu (onglet Plugins) :

- 4 sections pliables, une par étape
- Chaque section contient un toggle activé/désactivé et les champs spécifiques

## Critères d'acceptation

- [ ] Le plugin s'enregistre avec le nom `"launcher"`
- [ ] Le plugin est configurable (`is_configurable() == true`)
- [ ] Par défaut seul le logo moteur est activé
- [ ] `on_game_ready` déclenche la séquence de lancement (avant le menu principal)
- [ ] Chaque étape peut être activée/désactivée indépendamment
- [ ] Le logo studio affiche l'image configurée sur fond noir
- [ ] Le logo moteur affiche le texte « Made with Godot Engine »
- [ ] Le disclaimer affiche le texte en rouge, grande police
- [ ] Le texte libre affiche le contenu configuré
- [ ] Un clic ou appui touche permet de skipper une étape
- [ ] Les contrôles éditeur permettent de configurer chaque étape
- [ ] Les tests couvrent l'identité, la configuration par défaut, la génération des étapes et les contrôles éditeur
