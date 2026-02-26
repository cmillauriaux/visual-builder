# Variables d'histoire et effets sur les terminaisons

## Résumé

Ajout d'un système de **variables** déclarées au niveau de l'histoire (`Story`). Chaque variable possède un nom et une valeur initiale. Un panneau dédié, accessible via un bouton dans la barre supérieure, permet de gérer ces variables (ajouter, modifier, supprimer).

Les **terminaisons** (choix et redirections automatiques) peuvent désormais porter des **effets** (`VariableEffect`) qui modifient les variables au moment de leur résolution pendant le play mode. Quatre opérations sont disponibles : incrémenter, décrémenter, assigner une valeur, supprimer une variable.

Ces variables alimentent le système de conditions existant (spec 014).

## Modèle de données

### VariableDefinition (`src/models/variable_definition.gd`)

```
VariableDefinition (RefCounted)
├─ var_name: String (nom unique de la variable)
└─ initial_value: String (valeur initiale, par défaut "")
```

Méthodes :
- `to_dict() -> Dictionary`
- `static from_dict(d: Dictionary) -> VariableDefinition`

### VariableEffect (`src/models/variable_effect.gd`)

```
VariableEffect (RefCounted)
├─ variable: String (nom de la variable ciblée)
└─ operation: String ("set", "increment", "decrement", "delete")
└─ value: String (valeur de l'opération, ignorée pour "delete")
```

Opérations disponibles :

| Opération | Label UI | Comportement |
|---|---|---|
| `set` | Assigner | `_variables[variable] = value` |
| `increment` | Incrémenter | `_variables[variable] = str(float(_variables[variable]) + float(value))` |
| `decrement` | Décrémenter | `_variables[variable] = str(float(_variables[variable]) - float(value))` |
| `delete` | Supprimer | `_variables.erase(variable)` |

Pour `increment` et `decrement` : si la variable n'existe pas encore, elle est traitée comme valant `0`. Si la conversion en float échoue (valeur actuelle ou value), l'effet est ignoré silencieusement.

Méthodes :
- `apply(variables: Dictionary) -> void` — applique l'effet sur le dictionnaire de variables en place
- `to_dict() -> Dictionary`
- `static from_dict(d: Dictionary) -> VariableEffect`

### Modifications sur Story

Le modèle `Story` stocke désormais les définitions de variables :

```
Story
├─ ... (champs existants)
└─ variables: Array[VariableDefinition]
```

Méthodes ajoutées :
- `find_variable(var_name: String) -> VariableDefinition` — recherche par nom
- `get_variable_names() -> Array[String]` — retourne la liste des noms de variables déclarées (utile pour les dropdowns)

Sérialisation : le champ `"variables"` est ajouté au dictionnaire YAML au même niveau que `"chapters"`.

### Modifications sur Consequence

Le modèle `Consequence` intègre désormais une liste d'effets :

```
Consequence
├─ ... (champs existants)
└─ effects: Array[VariableEffect]
```

Les effets sont sérialisés dans le champ `"effects"` du dictionnaire de la conséquence. À la désérialisation, si `"effects"` est absent, le tableau est initialisé vide (rétrocompatibilité).

### Modifications sur Choice

Le modèle `Choice` intègre lui aussi une liste d'effets, au même niveau que la conséquence existante :

```
Choice
├─ ... (champs existants)
└─ effects: Array[VariableEffect]
```

Les effets d'un choix sont appliqués **en plus** des effets de sa conséquence, dans l'ordre : d'abord les effets du choix, puis ceux de la conséquence.

## Comportement attendu

### Panneau de variables

- Un bouton **"Variables"** est ajouté dans la barre supérieure, visible à tous les niveaux de navigation (chapters, scenes, sequences).
- Cliquer dessus ouvre/ferme un panneau latéral (ou popup) qui affiche la liste des variables de l'histoire courante.
- Le panneau contient :
  1. **Liste des variables** : chaque ligne affiche :
     - Un `LineEdit` pour le nom de la variable
     - Un `LineEdit` pour la valeur initiale
     - Un bouton "×" pour supprimer la variable
  2. **Bouton "+ Ajouter une variable"** en bas de la liste
- Les noms de variables doivent être uniques. Si l'utilisateur saisit un nom déjà existant, le champ passe en rouge et la modification n'est pas appliquée.
- Les modifications sont appliquées en temps réel sur le modèle `Story`.

### Éditeur d'effets sur les terminaisons

#### Dans l'éditeur de séquence (niveau sequence_edit)

La section "Ending" existante est enrichie :

1. **Pour une redirection automatique (`auto_redirect`)** :
   - Sous la ligne de redirection, une section pliable "Effets sur les variables" apparaît.
   - Elle contient une liste d'effets et un bouton "+ Ajouter un effet".

2. **Pour des choix (`choices`)** :
   - Sous chaque choix, une section pliable "Effets sur les variables" apparaît.
   - Elle contient une liste d'effets et un bouton "+ Ajouter un effet".

#### Composant EffectRow

Chaque effet dans la liste affiche :
- Un `OptionButton` pour la variable cible (alimenté par `story.get_variable_names()`, avec possibilité de saisie libre si la variable n'est pas encore déclarée)
- Un `OptionButton` pour l'opération (Assigner, Incrémenter, Décrémenter, Supprimer)
- Un `LineEdit` pour la valeur (masqué si l'opération est "Supprimer")
- Un bouton "×" pour supprimer l'effet

### Sélection de variable dans l'éditeur de condition

L'éditeur de condition existant (spec 014) est modifié :
- Le champ "Variable" (`LineEdit`) est remplacé par un `OptionButton` alimenté par `story.get_variable_names()`, avec une option de saisie libre (ou un `LineEdit` avec autocomplétion) pour permettre de référencer des variables pas encore déclarées.

### Play mode

#### Initialisation des variables

Au démarrage du play (`start_play_story`), le dictionnaire `_variables` est initialisé à partir des définitions de l'histoire :

```gdscript
_variables = {}
for var_def in story.variables:
    _variables[var_def.var_name] = var_def.initial_value
```

#### Application des effets

Quand le `StoryPlayController` résout une conséquence (dans `_resolve_consequence`), **avant** d'effectuer la redirection, il applique les effets :

```gdscript
# Pour une redirection automatique :
for effect in consequence.effects:
    effect.apply(_variables)

# Pour un choix :
var choice = ending.choices[index]
for effect in choice.effects:
    effect.apply(_variables)
for effect in choice.consequence.effects:
    effect.apply(_variables)
```

L'ordre d'application est garanti : effets du choix d'abord, effets de la conséquence ensuite.

### Persistance

#### Story

```yaml
title: "Mon histoire"
variables:
  - name: "score"
    initial_value: "0"
  - name: "has_key"
    initial_value: "false"
chapters: [...]
```

#### Consequence (avec effets)

```yaml
type: "redirect_sequence"
target: "uuid-123"
effects:
  - variable: "score"
    operation: "increment"
    value: "10"
  - variable: "visited_cave"
    operation: "set"
    value: "true"
```

#### Choice (avec effets)

```yaml
text: "Prendre la clé"
effects:
  - variable: "has_key"
    operation: "set"
    value: "true"
consequence:
  type: "redirect_sequence"
  target: "uuid-456"
  effects: []
```

## Critères d'acceptation

### Modèle VariableDefinition
- [x] Le modèle `VariableDefinition` existe avec `var_name` et `initial_value`
- [x] `VariableDefinition.to_dict()` et `VariableDefinition.from_dict()` fonctionnent correctement
- [x] Les noms de variables vides sont rejetés (validation)

### Modèle VariableEffect
- [x] Le modèle `VariableEffect` existe avec `variable`, `operation`, `value`
- [x] Les 4 opérations sont supportées : set, increment, decrement, delete
- [x] `apply()` modifie correctement le dictionnaire de variables
- [x] `apply()` avec `increment` sur une variable inexistante la crée avec la valeur incrémentée depuis 0
- [x] `apply()` avec `decrement` sur une variable inexistante la crée avec la valeur décrémentée depuis 0
- [x] `apply()` avec `increment`/`decrement` et une valeur non numérique est ignoré silencieusement
- [x] `apply()` avec `delete` supprime la variable du dictionnaire
- [x] `apply()` avec `set` crée ou remplace la variable
- [x] `VariableEffect.to_dict()` et `VariableEffect.from_dict()` fonctionnent correctement

### Modifications sur Story
- [x] `Story` possède un champ `variables: Array`
- [x] `Story.find_variable(var_name)` retourne la définition ou null
- [x] `Story.get_variable_names()` retourne un tableau de noms
- [x] Les variables sont sérialisées/désérialisées dans le YAML de l'histoire
- [x] La rétrocompatibilité est assurée (histoires sans variables chargées correctement)

### Modifications sur Consequence
- [x] `Consequence` possède un champ `effects: Array[VariableEffect]`
- [x] Les effets sont sérialisés/désérialisés dans le dictionnaire
- [x] La rétrocompatibilité est assurée (conséquences sans effets chargées correctement)

### Modifications sur Choice
- [x] `Choice` possède un champ `effects: Array[VariableEffect]`
- [x] Les effets sont sérialisés/désérialisés dans le dictionnaire
- [x] La rétrocompatibilité est assurée (choix sans effets chargés correctement)

### Panneau de variables (UI)
- [x] Un bouton "Variables" est visible dans la barre supérieure aux niveaux chapters, scenes, sequences
- [x] Cliquer sur le bouton ouvre/ferme le panneau de variables
- [x] Le panneau affiche la liste des variables de l'histoire
- [x] On peut ajouter une variable via le bouton "+ Ajouter une variable"
- [x] Chaque variable affiche un champ nom et un champ valeur initiale éditables
- [x] On peut supprimer une variable avec le bouton "×"
- [x] Les noms en doublon sont signalés visuellement et la modification est rejetée
- [x] Les modifications sont appliquées en temps réel sur le modèle Story

### Éditeur d'effets (UI)
- [x] La section "Effets sur les variables" apparaît sous les redirections automatiques
- [x] La section "Effets sur les variables" apparaît sous chaque choix
- [x] On peut ajouter un effet via le bouton "+ Ajouter un effet"
- [x] Chaque effet affiche un dropdown variable, un dropdown opération, un champ valeur et un bouton ×
- [x] Le champ valeur est masqué quand l'opération est "Supprimer"
- [x] Le dropdown variable est alimenté par les variables déclarées dans l'histoire
- [x] On peut supprimer un effet avec le bouton "×"

### Éditeur de condition (mise à jour)
- [x] Le champ variable de l'éditeur de condition propose les variables déclarées dans l'histoire

### Play mode
- [x] Au démarrage du play, `_variables` est initialisé avec les valeurs initiales des variables déclarées
- [x] Lors de la résolution d'une redirection automatique, les effets de la conséquence sont appliqués
- [x] Lors de la résolution d'un choix, les effets du choix puis ceux de la conséquence sont appliqués
- [x] L'ordre d'application des effets est respecté (choix avant conséquence)
- [x] Les conditions existantes fonctionnent correctement avec les variables initialisées

### Persistance
- [x] Les variables de l'histoire sont sauvegardées et rechargées correctement
- [x] Les effets des conséquences sont sauvegardés et rechargés correctement
- [x] Les effets des choix sont sauvegardés et rechargés correctement
- [x] Les histoires existantes sans variables/effets se chargent sans erreur (rétrocompatibilité)
