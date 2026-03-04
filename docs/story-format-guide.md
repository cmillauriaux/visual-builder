# Guide du format YAML des histoires

Ce guide explique comment écrire des histoires interactives au format YAML pour le lecteur **visual-builder**. Aucune connaissance de l'éditeur n'est requise — vous pouvez créer vos histoires entièrement à la main avec un simple éditeur de texte.

---

## Table des matières

1. [Organisation des fichiers](#organisation-des-fichiers)
2. [Structure générale](#structure-générale)
3. [Le fichier principal — story.yaml](#le-fichier-principal--storyyaml)
4. [Les chapitres](#les-chapitres)
5. [Les scènes](#les-scènes)
6. [Les séquences](#les-séquences)
7. [Les dialogues](#les-dialogues)
8. [Les avant-plans (foregrounds)](#les-avant-plans-foregrounds)
9. [Les effets visuels (FX)](#les-effets-visuels-fx)
10. [Les fins de séquence](#les-fins-de-séquence)
11. [Les choix](#les-choix)
12. [Les conséquences](#les-conséquences)
13. [Les variables](#les-variables)
14. [Les effets sur les variables](#les-effets-sur-les-variables)
15. [Les notifications](#les-notifications)
16. [Les conditions](#les-conditions)
17. [Les connexions](#les-connexions)
18. [L'internationalisation (i18n)](#linternationalisation-i18n)
19. [Exemple complet](#exemple-complet)

---

## Organisation des fichiers

Une histoire est un dossier structuré comme suit :

```
mon_histoire/
├── story.yaml                          # Fichier principal de l'histoire
├── assets/
│   ├── backgrounds/                    # Images de fond
│   │   ├── foret.png
│   │   └── chateau.png
│   └── foregrounds/                    # Images de personnages / objets
│       ├── hero.png
│       └── vilain.png
├── chapters/
│   └── ch-001/
│       ├── chapter.yaml                # Définition du chapitre
│       └── scenes/
│           ├── scene-001.yaml          # Première scène
│           └── scene-002.yaml          # Deuxième scène
└── i18n/                               # Traductions (optionnel)
    ├── languages.yaml                  # Configuration des langues
    ├── fr.yaml                         # Texte source (français)
    └── en.yaml                         # Traduction anglaise
```

Les images (backgrounds et foregrounds) sont placées dans le dossier `assets/`. Les fichiers YAML décrivent la structure narrative. Le dossier `i18n/` est optionnel et permet de traduire l'histoire en plusieurs langues (voir [Internationalisation](#linternationalisation-i18n)).

---

## Structure générale

L'histoire s'organise en une hiérarchie à quatre niveaux :

```
Histoire (story.yaml)
  └── Chapitres
        └── Scènes
              └── Séquences (dialogues + choix)
```

- Une **histoire** contient un ou plusieurs **chapitres**.
- Un **chapitre** contient une ou plusieurs **scènes**.
- Une **scène** contient une ou plusieurs **séquences**.
- Une **séquence** contient des **dialogues** et se termine par des **choix** ou une redirection automatique.

Chaque élément est identifié par un `uuid` unique (un identifiant de votre choix, par exemple `"ch-001"`, `"scene-intro"`, `"seq-combat-final"`).

---

## Le fichier principal — story.yaml

C'est le point d'entrée de votre histoire.

```yaml
title: "La Forêt Maudite"
author: "Jean Dupont"
description: "Une aventure interactive dans une forêt mystérieuse."
version: "1.0.0"
created_at: "2026-01-15T10:00:00Z"
updated_at: "2026-02-27T14:30:00Z"
entry_point: "ch-001"
menu_title: "La Forêt Maudite"
menu_subtitle: "Une aventure interactive"
menu_background: "menu_bg.png"
chapters:
  - uuid: "ch-001"
    name: "Chapitre 1 — L'entrée de la forêt"
    subtitle: "Où tout commence"
    position: { x: 0, y: 0 }
    entry_point: "scene-001"
  - uuid: "ch-002"
    name: "Chapitre 2 — Le cœur des ténèbres"
    position: { x: 400, y: 0 }
    entry_point: "scene-010"
variables:
  - name: "score"
    initial_value: "0"
  - name: "a_la_cle"
    initial_value: "false"
notifications:
  - pattern: "score"
    message: "Votre score a changé !"
  - pattern: "*_affinity"
    message: "Une relation a évolué..."
connections:
  - from: "ch-001"
    to: "ch-002"
```

| Champ | Obligatoire | Description |
|-------|:-----------:|-------------|
| `title` | oui | Titre de l'histoire |
| `author` | oui | Nom de l'auteur |
| `description` | non | Résumé de l'histoire |
| `version` | non | Numéro de version (défaut : `"1.0.0"`) |
| `created_at` | non | Date de création au format ISO 8601 |
| `updated_at` | non | Date de dernière modification |
| `entry_point` | oui | UUID du chapitre de départ |
| `menu_title` | non | Titre affiché sur l'écran de menu du jeu |
| `menu_subtitle` | non | Sous-titre affiché sur l'écran de menu |
| `menu_background` | non | Image de fond du menu (dans `assets/backgrounds/`) |
| `chapters` | oui | Liste des en-têtes de chapitres |
| `variables` | non | Variables globales de l'histoire |
| `notifications` | non | Notifications déclenchées par les changements de variables |
| `connections` | non | Liens entre chapitres (pour l'éditeur graphique) |

---

## Les chapitres

Chaque chapitre a son propre fichier : `chapters/{uuid}/chapter.yaml`.

```yaml
uuid: "ch-001"
name: "Chapitre 1 — L'entrée de la forêt"
subtitle: "Où tout commence"
position: { x: 0, y: 0 }
entry_point: "scene-001"
scenes:
  - uuid: "scene-001"
    name: "Arrivée"
    subtitle: "Premier pas dans la forêt"
    position: { x: 0, y: 0 }
    entry_point: "seq-001"
  - uuid: "scene-002"
    name: "La clairière"
    position: { x: 300, y: 0 }
    entry_point: "seq-010"
connections:
  - from: "scene-001"
    to: "scene-002"
```

| Champ | Obligatoire | Description |
|-------|:-----------:|-------------|
| `uuid` | oui | Identifiant unique du chapitre |
| `name` | oui | Nom affiché du chapitre |
| `subtitle` | non | Sous-titre |
| `position` | non | Position dans l'éditeur graphique |
| `entry_point` | oui | UUID de la première scène |
| `scenes` | oui | Liste des en-têtes de scènes |
| `connections` | non | Liens entre scènes |

---

## Les scènes

Chaque scène est un fichier : `chapters/{chapter_uuid}/scenes/{scene_uuid}.yaml`.

C'est dans les scènes que se trouvent les séquences (le contenu narratif).

```yaml
uuid: "scene-001"
name: "Arrivée"
subtitle: "Premier pas dans la forêt"
position: { x: 0, y: 0 }
entry_point: "seq-001"
sequences:
  - uuid: "seq-001"
    name: "Découverte"
    # ... (voir section Séquences)
  - uuid: "seq-002"
    name: "Exploration"
    # ...
conditions: []
connections:
  - from: "seq-001"
    to: "seq-002"
```

| Champ | Obligatoire | Description |
|-------|:-----------:|-------------|
| `uuid` | oui | Identifiant unique de la scène |
| `name` | oui | Nom affiché |
| `subtitle` | non | Sous-titre |
| `position` | non | Position dans l'éditeur graphique |
| `entry_point` | oui | UUID de la première séquence |
| `sequences` | oui | Liste des séquences |
| `conditions` | non | Nœuds de condition (voir section Conditions) |
| `connections` | non | Liens entre séquences/conditions |

---

## Les séquences

Une séquence est l'unité de base de la narration. Elle combine un décor (background), des personnages (foregrounds), des lignes de dialogue et une fin (choix ou redirection).

```yaml
uuid: "seq-001"
name: "Découverte"
title: "Chapitre 1"
subtitle: "Entrée dans la forêt"
position: { x: 0, y: 0 }
background: "foret.png"
background_color: "1a3d2aff"
transition_in_type: "fade"
transition_in_duration: 0.8
transition_out_type: "none"
transition_out_duration: 0.5
foregrounds:
  - uuid: "fg-hero"
    name: "Héros"
    image: "hero.png"
    z_order: 1
    opacity: 1.0
    flip_h: false
    flip_v: false
    scale: 1.0
    anchor_bg: { x: 0.5, y: 0.5 }
    anchor_fg: { x: 0.5, y: 1.0 }
    transition_type: "fade"
    transition_duration: 0.5
dialogues:
  - uuid: "dlg-001"
    character: "Narrateur"
    text: "Vous pénétrez dans une forêt sombre et silencieuse."
    foregrounds: []
  - uuid: "dlg-002"
    character: "Héros"
    text: "Il fait froid ici..."
    foregrounds: []
fx:
  - uuid: "fx-001"
    fx_type: "screen_shake"
    duration: 1.0
    intensity: 0.5
ending:
  type: "choices"
  choices:
    - text: "Avancer prudemment"
      consequence:
        type: "redirect_sequence"
        target: "seq-002"
        effects: []
      effects: []
      conditions: {}
    - text: "Faire demi-tour"
      consequence:
        type: "game_over"
        effects: []
      effects: []
      conditions: {}
```

| Champ | Obligatoire | Défaut | Description |
|-------|:-----------:|:------:|-------------|
| `uuid` | oui | — | Identifiant unique |
| `name` | oui | — | Nom de la séquence |
| `title` | non | `""` | Titre affiché au lecteur (par ex. un titre de chapitre) |
| `subtitle` | non | `""` | Sous-titre |
| `position` | non | `{x: 0, y: 0}` | Position dans l'éditeur |
| `background` | non | `""` | Nom du fichier image de fond (dans `assets/backgrounds/`) |
| `background_color` | non | `"00000000"` | Couleur de fond en hexadécimal RGBA (8 caractères). Transparent par défaut |
| `foregrounds` | non | `[]` | Personnages/objets affichés par défaut |
| `dialogues` | oui | — | Liste des lignes de dialogue |
| `fx` | non | `[]` | Effets visuels appliqués à la séquence (voir [Effets visuels](#les-effets-visuels-fx)) |
| `transition_in_type` | non | `"none"` | Transition d'entrée : `"none"`, `"fade"`, `"pixelate"` |
| `transition_in_duration` | non | `0.5` | Durée de la transition d'entrée en secondes |
| `transition_out_type` | non | `"none"` | Transition de sortie : `"none"`, `"fade"`, `"pixelate"` |
| `transition_out_duration` | non | `0.5` | Durée de la transition de sortie en secondes |
| `ending` | oui | — | Fin de la séquence (choix ou redirection) |

### Transitions de séquence

Les transitions contrôlent l'effet visuel lors du passage d'une séquence à une autre.

| Type | Description |
|------|-------------|
| `"none"` | Changement instantané |
| `"fade"` | Fondu au noir (entrée/sortie) |
| `"pixelate"` | Effet de pixellisation progressif |

---

## Les dialogues

Les dialogues sont affichés un par un au lecteur, dans l'ordre.

```yaml
dialogues:
  - uuid: "dlg-001"
    character: "Narrateur"
    text: "Le vent souffle à travers les arbres."
    foregrounds: []
  - uuid: "dlg-002"
    character: "Héros"
    text: "Je dois trouver un abri avant la nuit."
    foregrounds:
      - uuid: "fg-pluie"
        name: "Pluie"
        image: "pluie.png"
        z_order: 10
        opacity: 0.6
        flip_h: false
        flip_v: false
        scale: 1.0
        anchor_bg: { x: 0.5, y: 0.5 }
        anchor_fg: { x: 0.5, y: 0.5 }
        transition_type: "fade"
        transition_duration: 1.0
```

| Champ | Obligatoire | Description |
|-------|:-----------:|-------------|
| `uuid` | oui | Identifiant unique |
| `character` | oui | Nom du personnage qui parle |
| `text` | oui | Texte du dialogue |
| `foregrounds` | non | Avant-plans spécifiques à cette réplique (remplacent temporairement ceux de la séquence) |

Chaque dialogue peut modifier les avant-plans affichés. Par exemple, un personnage peut changer d'expression ou un nouvel élément peut apparaître pendant une réplique.

---

## Les avant-plans (foregrounds)

Les foregrounds sont des images superposées au fond (personnages, objets, effets visuels). Ils peuvent être définis au niveau de la séquence (affichage par défaut) ou au niveau d'un dialogue spécifique.

```yaml
foregrounds:
  - uuid: "fg-hero"
    name: "Héros"
    image: "hero.png"
    z_order: 1
    opacity: 1.0
    flip_h: false
    flip_v: false
    scale: 1.0
    anchor_bg: { x: 0.3, y: 0.8 }
    anchor_fg: { x: 0.5, y: 1.0 }
    transition_type: "fade"
    transition_duration: 0.5
```

| Champ | Obligatoire | Défaut | Description |
|-------|:-----------:|:------:|-------------|
| `uuid` | oui | — | Identifiant unique |
| `name` | oui | — | Nom de l'élément |
| `image` | oui | — | Fichier image (dans `assets/foregrounds/`) |
| `z_order` | non | `0` | Ordre de profondeur (plus élevé = devant) |
| `opacity` | non | `1.0` | Opacité de 0.0 (invisible) à 1.0 (opaque) |
| `flip_h` | non | `false` | Retourner horizontalement |
| `flip_v` | non | `false` | Retourner verticalement |
| `scale` | non | `1.0` | Facteur d'échelle |
| `anchor_bg` | non | `{x: 0.5, y: 0.5}` | Point d'ancrage sur le fond (0.0 à 1.0) |
| `anchor_fg` | non | `{x: 0.5, y: 1.0}` | Point d'ancrage sur l'image (0.0 à 1.0) |
| `transition_type` | non | `"none"` | Type de transition : `"none"`, `"fade"` |
| `transition_duration` | non | `0.5` | Durée de la transition en secondes (0.1 à 5.0) |

### Positionnement avec les ancres

Le système d'ancrage fonctionne avec deux points :

- **`anchor_bg`** : où placer l'image sur le fond. `{x: 0.0, y: 0.0}` = coin haut-gauche, `{x: 1.0, y: 1.0}` = coin bas-droit, `{x: 0.5, y: 0.5}` = centre.
- **`anchor_fg`** : quel point de l'image aligner sur la position. `{x: 0.5, y: 1.0}` = bas-centre (utile pour les personnages debout).

**Exemple** : Pour placer un personnage au centre-bas de l'écran, pieds au sol :
```yaml
anchor_bg: { x: 0.5, y: 0.9 }   # Position sur le fond : centre, presque en bas
anchor_fg: { x: 0.5, y: 1.0 }   # Point d'ancrage du personnage : bas-centre (les pieds)
```

### Types de transition

| Type | Description |
|------|-------------|
| `"none"` | Apparition instantanée, disparition en fondu |
| `"fade"` | Fondu en apparition et disparition |

---

## Les effets visuels (FX)

Les effets visuels ajoutent des animations à une séquence (tremblement d'écran, fondu, clignement). Ils sont définis dans le champ `fx` de la séquence.

```yaml
fx:
  - uuid: "fx-001"
    fx_type: "screen_shake"
    duration: 1.0
    intensity: 0.8
  - uuid: "fx-002"
    fx_type: "fade_in"
    duration: 0.5
    intensity: 1.0
```

| Champ | Obligatoire | Défaut | Description |
|-------|:-----------:|:------:|-------------|
| `uuid` | oui | — | Identifiant unique |
| `fx_type` | oui | `"fade_in"` | Type d'effet (voir ci-dessous) |
| `duration` | non | `0.5` | Durée de l'effet en secondes (0.1 à 5.0) |
| `intensity` | non | `1.0` | Intensité de l'effet (0.1 à 3.0) |

### Types d'effets disponibles

| Type | Description |
|------|-------------|
| `"screen_shake"` | Tremblement de l'écran (ex. explosion, séisme) |
| `"fade_in"` | Fondu en apparition |
| `"eyes_blink"` | Effet de clignement d'yeux |

---

## Les fins de séquence

Chaque séquence se termine d'une des deux manières :

### 1. Choix (`choices`)

Le lecteur doit choisir parmi plusieurs options :

```yaml
ending:
  type: "choices"
  choices:
    - text: "Explorer la grotte"
      consequence:
        type: "redirect_sequence"
        target: "seq-grotte"
        effects: []
      effects:
        - variable: "courage"
          operation: "increment"
          value: "1"
      conditions: {}
    - text: "Fuir"
      consequence:
        type: "redirect_sequence"
        target: "seq-fuite"
        effects: []
      effects: []
      conditions: {}
```

### 2. Redirection automatique (`auto_redirect`)

La séquence enchaîne automatiquement vers la suite, sans intervention du lecteur :

```yaml
ending:
  type: "auto_redirect"
  consequence:
    type: "redirect_sequence"
    target: "seq-002"
    effects: []
```

---

## Les choix

Chaque choix proposé au lecteur est composé de :

```yaml
text: "Texte affiché sur le bouton"
consequence:                        # Que se passe-t-il si on choisit cette option
  type: "redirect_sequence"
  target: "seq-002"
  effects: []
effects:                            # Variables modifiées lors du choix
  - variable: "score"
    operation: "increment"
    value: "10"
conditions: {}                      # Conditions d'affichage (optionnel)
```

| Champ | Obligatoire | Description |
|-------|:-----------:|-------------|
| `text` | oui | Texte du bouton de choix |
| `consequence` | oui | Action déclenchée par le choix |
| `effects` | non | Modifications de variables |
| `conditions` | non | Conditions pour afficher ce choix |

> **Limite** : une séquence peut proposer entre **1 et 8 choix** maximum.

---

## Les conséquences

Une conséquence détermine ce qui se passe après un choix ou une redirection automatique.

| Type | Description | `target` requis ? |
|------|-------------|:-----------------:|
| `redirect_sequence` | Aller à une autre séquence | oui |
| `redirect_scene` | Aller à une autre scène | oui |
| `redirect_chapter` | Aller à un autre chapitre | oui |
| `redirect_condition` | Évaluer un nœud de condition | oui |
| `game_over` | Fin de partie | non |
| `to_be_continued` | À suivre (fin temporaire) | non |

```yaml
# Rediriger vers une séquence
consequence:
  type: "redirect_sequence"
  target: "seq-002"
  effects: []

# Rediriger vers une scène
consequence:
  type: "redirect_scene"
  target: "scene-005"
  effects: []

# Rediriger vers un chapitre
consequence:
  type: "redirect_chapter"
  target: "ch-002"
  effects: []

# Fin de partie
consequence:
  type: "game_over"
  effects: []

# À suivre
consequence:
  type: "to_be_continued"
  effects: []
```

Les conséquences peuvent aussi contenir des `effects` pour modifier des variables au moment de la transition.

---

## Les variables

Les variables permettent de suivre l'état du jeu : score, objets collectés, choix passés, etc. Elles sont déclarées dans `story.yaml` et leurs valeurs sont toujours stockées sous forme de texte.

### Déclaration

```yaml
# Dans story.yaml
variables:
  - name: "score"
    initial_value: "0"
  - name: "a_la_cle"
    initial_value: "false"
  - name: "nom_du_heros"
    initial_value: "Inconnu"
```

### Utilisation

Les variables sont utilisées dans deux contextes :
- **Effets** : modifier une variable lors d'un choix ou d'une conséquence.
- **Conditions** : brancher l'histoire selon la valeur d'une variable.

---

## Les effets sur les variables

Les effets modifient les variables. Ils peuvent être placés dans les `effects` d'un choix ou d'une conséquence.

```yaml
effects:
  - variable: "score"
    operation: "set"
    value: "100"
  - variable: "sante"
    operation: "increment"
    value: "5"
  - variable: "sante"
    operation: "decrement"
    value: "10"
  - variable: "objet_temporaire"
    operation: "delete"
```

| Opération | Description | `value` requis ? |
|-----------|-------------|:----------------:|
| `set` | Fixe la variable à une valeur | oui |
| `increment` | Ajoute à la variable (numérique) | oui |
| `decrement` | Soustrait de la variable (numérique) | oui |
| `delete` | Supprime la variable | non |

---

## Les notifications

Les notifications permettent d'afficher un message au lecteur lorsqu'une variable est modifiée. Elles sont déclarées dans `story.yaml` et utilisent des **patterns glob** pour cibler une ou plusieurs variables.

```yaml
# Dans story.yaml
notifications:
  - pattern: "score"
    message: "Votre score a changé !"
  - pattern: "*_affinity"
    message: "Une relation a évolué..."
  - pattern: "item_*"
    message: "Inventaire mis à jour."
```

| Champ | Obligatoire | Description |
|-------|:-----------:|-------------|
| `pattern` | oui | Pattern glob ciblant les noms de variables |
| `message` | oui | Message affiché au lecteur (type toast/notification) |

### Patterns glob

| Caractère | Signification |
|-----------|---------------|
| `*` | Correspond à n'importe quelle suite de caractères (y compris vide) |
| `?` | Correspond à un seul caractère |

**Exemples** :
- `"score"` — correspond exactement à la variable `score`
- `"*_affinity"` — correspond à `hero_affinity`, `enemy_affinity`, etc.
- `"item_?"` — correspond à `item_a`, `item_b`, mais pas `item_ab`

Les notifications sont évaluées à chaque modification de variable. Si le pattern correspond au nom de la variable modifiée, le message est affiché.

---

## Les conditions

Les conditions permettent de créer des embranchements automatiques basés sur l'état des variables. Elles sont définies au niveau de la scène.

```yaml
conditions:
  - uuid: "cond-score"
    name: "Vérification du score"
    subtitle: ""
    position: { x: 200, y: 300 }
    rules:
      - variable: "score"
        operator: "greater_than"
        value: "100"
        consequence:
          type: "redirect_sequence"
          target: "seq-victoire"
          effects: []
      - variable: "score"
        operator: "greater_than"
        value: "50"
        consequence:
          type: "redirect_sequence"
          target: "seq-milieu"
          effects: []
    default_consequence:
      type: "redirect_sequence"
      target: "seq-defaite"
      effects: []
```

Les règles sont évaluées **dans l'ordre**. La première règle qui correspond est appliquée. Si aucune règle ne correspond, la `default_consequence` est utilisée.

### Opérateurs disponibles

| Opérateur | Description |
|-----------|-------------|
| `equal` | Égal à la valeur |
| `not_equal` | Différent de la valeur |
| `greater_than` | Supérieur à (numérique) |
| `greater_than_equal` | Supérieur ou égal à (numérique) |
| `less_than` | Inférieur à (numérique) |
| `less_than_equal` | Inférieur ou égal à (numérique) |
| `exists` | La variable existe |
| `not_exists` | La variable n'existe pas |

Pour les opérateurs `exists` et `not_exists`, le champ `value` est ignoré.

### Utilisation

Pour diriger le lecteur vers un nœud de condition, utilisez une conséquence `redirect_condition` :

```yaml
ending:
  type: "auto_redirect"
  consequence:
    type: "redirect_condition"
    target: "cond-score"
    effects: []
```

---

## Les connexions

Les connexions (`connections`) décrivent les liens entre les éléments. Elles sont principalement utilisées par l'éditeur graphique mais aident aussi à la lisibilité.

```yaml
connections:
  - from: "seq-001"
    to: "seq-002"
  - from: "seq-002"
    to: "cond-score"
```

---

## L'internationalisation (i18n)

Le système d'internationalisation permet de traduire une histoire en plusieurs langues sans modifier les fichiers YAML d'origine. Le texte source (en français par défaut) reste dans les fichiers de l'histoire ; les traductions sont stockées dans des fichiers séparés.

### Structure des fichiers

```
mon_histoire/
└── i18n/
    ├── languages.yaml      # Configuration des langues
    ├── fr.yaml             # Texte source (langue par défaut)
    └── en.yaml             # Traduction anglaise
```

### Configuration des langues — `languages.yaml`

```yaml
default: "fr"
languages:
  - "fr"
  - "en"
```

| Champ | Description |
|-------|-------------|
| `default` | Code de la langue source (par défaut : `"fr"`) |
| `languages` | Liste de tous les codes de langue disponibles |

> Si le fichier `languages.yaml` est absent, le système détecte automatiquement les langues à partir des fichiers `*.yaml` présents dans `i18n/`.

### Format des fichiers de traduction

Chaque fichier de traduction est un simple dictionnaire clé-valeur où la clé est le texte source et la valeur est la traduction :

```yaml
# i18n/en.yaml
"La Forêt Maudite": "The Cursed Forest"
"Jean Dupont": "Jean Dupont"
"Vous pénétrez dans une forêt sombre et silencieuse.": "You enter a dark and silent forest."
"Il fait froid ici...": "It's cold here..."
"Avancer prudemment": "Advance carefully"
"Faire demi-tour": "Turn back"
"Narrateur": "Narrator"
"Héros": "Hero"
```

### Champs traduits

Les champs suivants sont automatiquement traduits lorsqu'une langue est sélectionnée :

| Modèle | Champs |
|--------|--------|
| Histoire | `title`, `author`, `description`, `menu_title`, `menu_subtitle` |
| Chapitre | `name`, `subtitle` |
| Scène | `name`, `subtitle` |
| Séquence | `name`, `subtitle` |
| Dialogue | `character`, `text` |
| Choix | `text` |
| Notification | `message` |

### Fonctionnement

- Si une traduction est absente ou vide, le texte source (français) est conservé.
- Le fichier de la langue par défaut (`fr.yaml`) utilise le format `"texte": "texte"` (clé = valeur identiques) et sert de référence.
- Les chaînes d'interface du jeu (menus, boutons) sont également incluses dans les fichiers de traduction.

---

## Exemple complet

Voici une petite histoire complète avec deux séquences, un choix, une variable et une condition.

### story.yaml

```yaml
title: "Le Coffre Mystérieux"
author: "Marie Martin"
description: "Trouverez-vous la clé du coffre ?"
version: "1.0.0"
created_at: "2026-02-27T10:00:00Z"
updated_at: "2026-02-27T10:00:00Z"
entry_point: "ch-1"
menu_title: "Le Coffre Mystérieux"
menu_subtitle: "Une courte aventure"
chapters:
  - uuid: "ch-1"
    name: "L'unique chapitre"
    position: { x: 0, y: 0 }
    entry_point: "sc-1"
variables:
  - name: "a_la_cle"
    initial_value: "false"
notifications:
  - pattern: "a_la_cle"
    message: "Vous avez trouvé un objet !"
connections: []
```

### chapters/ch-1/chapter.yaml

```yaml
uuid: "ch-1"
name: "L'unique chapitre"
position: { x: 0, y: 0 }
entry_point: "sc-1"
scenes:
  - uuid: "sc-1"
    name: "La salle du coffre"
    position: { x: 0, y: 0 }
    entry_point: "seq-entree"
connections: []
```

### chapters/ch-1/scenes/sc-1.yaml

```yaml
uuid: "sc-1"
name: "La salle du coffre"
position: { x: 0, y: 0 }
entry_point: "seq-entree"
sequences:
  - uuid: "seq-entree"
    name: "Entrée"
    position: { x: 0, y: 0 }
    background: "salle.png"
    background_color: "2b1d0eff"
    transition_in_type: "fade"
    transition_in_duration: 1.0
    foregrounds: []
    dialogues:
      - uuid: "dlg-1"
        character: "Narrateur"
        text: "Vous entrez dans une salle poussiéreuse. Un coffre imposant trône au centre."
        foregrounds: []
      - uuid: "dlg-2"
        character: "Narrateur"
        text: "À gauche, une petite table avec un tiroir. À droite, le coffre verrouillé."
        foregrounds: []
    ending:
      type: "choices"
      choices:
        - text: "Fouiller le tiroir"
          consequence:
            type: "redirect_sequence"
            target: "seq-tiroir"
            effects: []
          effects: []
          conditions: {}
        - text: "Essayer d'ouvrir le coffre"
          consequence:
            type: "redirect_condition"
            target: "cond-cle"
            effects: []
          effects: []
          conditions: {}

  - uuid: "seq-tiroir"
    name: "Le tiroir"
    position: { x: 300, y: 0 }
    background: "salle.png"
    foregrounds: []
    fx:
      - uuid: "fx-cle"
        fx_type: "screen_shake"
        duration: 0.3
        intensity: 0.4
    dialogues:
      - uuid: "dlg-3"
        character: "Narrateur"
        text: "Vous ouvrez le tiroir et trouvez une vieille clé rouillée !"
        foregrounds:
          - uuid: "fg-cle"
            name: "Clé"
            image: "cle.png"
            z_order: 5
            opacity: 1.0
            flip_h: false
            flip_v: false
            scale: 1.0
            anchor_bg: { x: 0.5, y: 0.5 }
            anchor_fg: { x: 0.5, y: 0.5 }
            transition_type: "fade"
            transition_duration: 0.8
    ending:
      type: "auto_redirect"
      consequence:
        type: "redirect_sequence"
        target: "seq-entree"
        effects:
          - variable: "a_la_cle"
            operation: "set"
            value: "true"

  - uuid: "seq-coffre-ouvert"
    name: "Coffre ouvert"
    position: { x: 600, y: 0 }
    background: "salle.png"
    foregrounds: []
    dialogues:
      - uuid: "dlg-4"
        character: "Narrateur"
        text: "La clé tourne dans la serrure. Le coffre s'ouvre, révélant un trésor scintillant !"
        foregrounds: []
      - uuid: "dlg-5"
        character: "Narrateur"
        text: "Félicitations, vous avez trouvé le trésor !"
        foregrounds: []
    ending:
      type: "auto_redirect"
      consequence:
        type: "game_over"
        effects: []

  - uuid: "seq-coffre-ferme"
    name: "Coffre fermé"
    position: { x: 600, y: 200 }
    background: "salle.png"
    foregrounds: []
    dialogues:
      - uuid: "dlg-6"
        character: "Narrateur"
        text: "Le coffre est solidement verrouillé. Il vous faut une clé."
        foregrounds: []
    ending:
      type: "auto_redirect"
      consequence:
        type: "redirect_sequence"
        target: "seq-entree"
        effects: []

conditions:
  - uuid: "cond-cle"
    name: "A-t-on la clé ?"
    subtitle: ""
    position: { x: 450, y: 100 }
    rules:
      - variable: "a_la_cle"
        operator: "equal"
        value: "true"
        consequence:
          type: "redirect_sequence"
          target: "seq-coffre-ouvert"
          effects: []
    default_consequence:
      type: "redirect_sequence"
      target: "seq-coffre-ferme"
      effects: []

connections:
  - from: "seq-entree"
    to: "seq-tiroir"
  - from: "seq-entree"
    to: "cond-cle"
  - from: "cond-cle"
    to: "seq-coffre-ouvert"
  - from: "cond-cle"
    to: "seq-coffre-ferme"
  - from: "seq-tiroir"
    to: "seq-entree"
```

---

## Conseils pratiques

- **UUIDs** : Utilisez des identifiants courts et lisibles (`"seq-combat"`, `"ch-01"`) plutôt que de vrais UUID. Le lecteur accepte n'importe quelle chaîne unique.
- **Positions** : Les champs `position` ne servent qu'à l'éditeur graphique. En écriture manuelle, vous pouvez mettre `{ x: 0, y: 0 }` partout.
- **Valeurs de variables** : Toutes les valeurs sont des chaînes de texte. Écrivez `"0"` et non `0`, `"true"` et non `true`.
- **Testez progressivement** : Commencez avec une histoire simple (un chapitre, une scène, deux séquences) et enrichissez au fur et à mesure.
- **Noms de fichiers images** : Les noms dans `background` et `image` correspondent aux fichiers dans `assets/backgrounds/` et `assets/foregrounds/` respectivement.
