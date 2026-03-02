# 035 — Internationalisation des histoires (style .po)

## Contexte

Le projet stocke les textes (dialogues, noms, titres) directement dans les YAML d'histoire. Pour supporter plusieurs langues, on adopte un système de traduction inspiré de `.po` (gettext) : la **chaîne source** (français) sert de clé, la **traduction** comme valeur.

Les fichiers YAML d'histoire ne sont **pas modifiés** : ils contiennent toujours le texte source en français. Un fichier de traduction optionnel est appliqué après chargement si la langue active n'est pas le français.

## Architecture

```
stories/{slug}/
├── story.yaml           ← structure + texte source (inchangé)
├── chapters/            ← inchangé
└── i18n/
    ├── fr.yaml          ← fichier source généré (msgid = msgstr)
    └── en.yaml          ← traductions anglaises
```

## Format des fichiers i18n

Dictionnaire YAML plat : chaîne source → traduction.

```yaml
# stories/epreuve-du-heros/i18n/en.yaml
"L'Épreuve du Héros": "The Hero's Trial"
"Test Intégration": "Integration Test"
"Un voyage vers la gloire": "A journey to glory"
"Les Épreuves de la Cité": "The City's Trials"
"La Salle des Défis": "The Hall of Challenges"
"Héraut Royal": "Royal Herald"
"Bienvenue au Grand Tournoi des Héros!": "Welcome to the Grand Tournament of Heroes!"
"Voie du Guerrier — Maîtriser la force physique": "Warrior's Path — Master physical strength"
"Force augmentée!": "Strength increased!"
```

## Champs traduits par modèle

| Modèle | Champs traduits |
|--------|----------------|
| Story | title, author, description, menu_title, menu_subtitle |
| Chapter | chapter_name, subtitle |
| SceneData | scene_name, subtitle |
| Sequence | seq_name, subtitle |
| Dialogue | character, text |
| Choice | text |
| StoryNotification | message |

## Service : StoryI18nService

Fichier : `src/services/story_i18n_service.gd`

Classe statique (méthodes statiques uniquement, pas de singleton).

### `extract_strings(story) -> Dictionary`

Parcourt tous les champs texte de l'histoire (y compris chapitres, scènes, séquences, dialogues, choix, notifications) et retourne un dictionnaire `{source_string: source_string}` (clé = valeur pour le fichier source fr.yaml).

Les chaînes vides sont exclues. Les doublons sont dédupliqués automatiquement (clés de dictionnaire).

### `load_i18n(story_path: String, lang: String) -> Dictionary`

Charge `{story_path}/i18n/{lang}.yaml`. Retourne un dictionnaire vide si le fichier n'existe pas.

### `save_i18n(strings_dict: Dictionary, story_path: String, lang: String) -> void`

Crée le dossier `{story_path}/i18n/` si nécessaire et écrit `{lang}.yaml`.

### `apply_to_story(story, i18n_dict: Dictionary) -> void`

Pour chaque champ texte de l'histoire, si la chaîne source est présente comme clé dans `i18n_dict`, remplace la valeur par la traduction correspondante. Si la clé est absente ou si la traduction est vide, la valeur source est conservée (fallback).

## Intégration dans StorySaver

### Chargement (`load_story`)

```
1. Charger le YAML normalement (texte source en mémoire)
2. Si lang != "fr" :
   a. charger i18n/{lang}.yaml
   b. apply_to_story(story, i18n_dict)
```

### Sauvegarde (`save_story`)

```
1. Sauvegarder le YAML normalement (texte source préservé)
2. Extraire les chaînes source → extract_strings(story)
3. Sauvegarder i18n/fr.yaml (template pour traducteurs)
```

## Comportement du fallback

- Clé absente dans i18n_dict → valeur source conservée
- Traduction vide (`""`) → valeur source conservée
- Fichier i18n inexistant → aucune traduction, histoire chargée telle quelle

## Critères d'acceptation

- [ ] `extract_strings` collecte tous les champs texte non vides sans doublons
- [ ] `apply_to_story` remplace les champs traduits et conserve les non traduits
- [ ] `apply_to_story` conserve la valeur source si traduction vide
- [ ] `load_i18n` retourne `{}` si le fichier est absent
- [ ] `save_i18n` crée le fichier avec le bon contenu YAML
- [ ] Après `save_story`, `i18n/fr.yaml` contient toutes les chaînes source
- [ ] Après `load_story` avec lang="en", les textes sont traduits si i18n/en.yaml existe
- [ ] Après `load_story` avec lang="fr", les textes sont ceux du YAML source (aucune modification)
