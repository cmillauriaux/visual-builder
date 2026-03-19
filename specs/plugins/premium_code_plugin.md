# Plugin : Code Premium (premium_code)

## Résumé

Plugin in-game qui permet de bloquer la progression du joueur sur certains chapitres
s'il ne possède pas un code d'accès valide. Le joueur peut saisir ses codes dans les
options du jeu. Les codes validés sont persistés dans le user storage.

L'auteur configure les codes et les plages de chapitres protégés dans les paramètres
de la story (onglet Plugins du dialogue de configuration).

À l'export, une case à cocher permet de choisir entre une « version limitée »
(plugin actif) et une « version complète » (plugin désactivé/retiré).

## Comportement détaillé

### Configuration éditeur (plugin_settings)

Dans le dialogue de configuration de la story (onglet Plugins), l'auteur peut :

- Ajouter des lignes de codes avec un bouton **+**
- Chaque ligne contient :
  - **Code** : chaîne secrète (ex : `PATRON2024`)
  - **Chapitre de début** : dropdown listant les chapitres de la story
  - **Chapitre de fin** : dropdown listant les chapitres de la story
- Supprimer une ligne avec un bouton **×**

Les données sont stockées dans `story.plugin_settings["premium_code"]` sous la forme :

```json
{
  "codes": [
    {
      "code": "PATRON2024",
      "from_chapter_uuid": "abc123",
      "to_chapter_uuid": "def456"
    }
  ],
  "purchase_message": "Procurez-vous le jeu complet pour débloquer ce contenu !",
  "purchase_url": ""
}
```

Le `purchase_url` est facultatif. S'il est vide, le plugin utilise `story.itchio_url`
ou `story.patreon_url` comme lien d'achat.

### Logique de blocage (in-game)

Au hook `on_before_chapter` :

1. Déterminer si le chapitre courant est protégé par au moins un code.
   - Un chapitre est « protégé » s'il se trouve entre `from_chapter_uuid` et
     `to_chapter_uuid` (inclus) dans l'ordre de la liste `story.chapters`.
   - Si un chapitre n'est couvert par aucun code, il est en **accès libre**.
2. Vérifier si le joueur possède un code valide pour ce chapitre :
   - Les codes validés sont stockés dans `user://codes.json`.
3. Si le chapitre est protégé et aucun code valide n'est trouvé :
   - Afficher un popup modal avec :
     - Le message d'achat configuré
     - Un champ de saisie pour entrer un code
     - Un bouton « Valider »
     - Un lien cliquable vers la page d'achat (itch.io / Patreon)
     - Un bouton « Retour » pour revenir au menu
   - Si le code saisi est valide → le sauvegarder dans `user://codes.json`
     et laisser la progression continuer.
   - Si le code est invalide → afficher un message d'erreur.

### Persistance des codes joueur

Fichier : `user://codes.json`

```json
{
  "validated_codes": ["PATRON2024", "BETAKEY"]
}
```

### Options in-game

Dans la section Plugins des options du jeu, le plugin affiche :

- La liste des codes déjà saisis avec un bouton **+** pour en ajouter
- Un champ de saisie pour entrer un nouveau code
- Un bouton **Supprimer** par code existant
- Validation immédiate du code (feedback visuel OK/erreur)

### Export : version limitée vs complète

Le système de plugins éditeur est étendu avec un nouveau hook :

- `VBGamePlugin.get_export_options() -> Array` : retourne des `GameContributions.ExportOptionDef`
- `ExportOptionDef` : `{ label: String, key: String, default_value: bool }`
- Le `export_dialog.gd` appelle ce hook pour afficher des cases à cocher supplémentaires
- Le `export_service.gd` reçoit les options cochées et peut exclure des plugins

Pour le plugin premium_code :
- Option : « Version limitée (vérification de code) » (cochée par défaut)
- Si décochée → le dossier `plugins/premium_code/` n'est pas copié dans l'export

## Critères d'acceptation

- [ ] Le plugin est chargé automatiquement depuis `res://plugins/premium_code/`
- [ ] L'auteur peut configurer des codes et plages de chapitres dans l'éditeur
- [ ] En jeu, un chapitre protégé sans code valide affiche un popup de blocage
- [ ] Le joueur peut saisir un code dans le popup ou dans les options
- [ ] Les codes validés sont persistés dans `user://codes.json`
- [ ] Un chapitre non couvert par un code est en accès libre
- [ ] L'export propose une case « Version limitée » pour inclure/exclure le plugin
- [ ] Tests unitaires couvrent : validation de code, détection de chapitre protégé,
      persistance, logique d'export
