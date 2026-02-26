# Nœuds condition dans le graphe de séquences

## Résumé

Ajout d'un nouveau type de nœud "condition" dans le graphe de séquences (niveau 3). Un nœud condition permet de brancher le flux narratif en fonction de la valeur d'une variable. L'éditeur de condition (accessible par double-clic) permet de définir une variable à tester, une liste de règles (opérateur + valeur → redirection), et une redirection par défaut. Les conditions sont évaluées pendant le play mode grâce à un dictionnaire de variables en mémoire.

## Modèle de données

### Condition (`src/models/condition.gd`)

```
Condition (RefCounted)
├─ uuid: String (auto-généré)
├─ condition_name: String
├─ subtitle: String
├─ position: Vector2 (position dans le graphe)
├─ rules: Array[ConditionRule] (liste ordonnée de règles)
└─ default_consequence: Consequence (redirection si aucune règle ne matche)
```

### ConditionRule (`src/models/condition_rule.gd`)

Chaque règle possède sa propre variable à tester, ce qui permet à une même condition de tester différentes variables selon les règles.

```
ConditionRule (RefCounted)
├─ variable: String (nom de la variable testée par cette règle)
├─ operator: String ("equal", "not_equal", "greater_than", "greater_than_equal", "less_than", "less_than_equal", "exists", "not_exists")
├─ value: String (valeur de comparaison, ignorée pour exists/not_exists)
└─ consequence: Consequence (redirection si la règle matche)
```

### Opérateurs disponibles

| Opérateur | Label UI | Comportement |
|---|---|---|
| `equal` | Equal | variable == valeur |
| `not_equal` | Not Equal | variable != valeur |
| `greater_than` | Greater Than | float(variable) > float(valeur) |
| `greater_than_equal` | Greater Than Equal | float(variable) >= float(valeur) |
| `less_than` | Less Than | float(variable) < float(valeur) |
| `less_than_equal` | Less Than Equal | float(variable) <= float(valeur) |
| `exists` | Exists | la variable existe dans le dictionnaire |
| `not_exists` | Not Exists | la variable n'existe pas dans le dictionnaire |

Pour les comparaisons numériques : si la conversion en float échoue, la comparaison retourne `false`.

### Modifications sur SceneData

Le modèle `SceneData` stocke désormais aussi les conditions :

```
SceneData
├─ ... (champs existants)
└─ conditions: Array[Condition]
```

La méthode `find_sequence` existante est complétée par `find_condition(uuid)`.

### Variables du play mode

Le `StoryPlayController` possède un nouveau champ :

```
var _variables: Dictionary = {}  # String → Variant
```

Initialisé vide au démarrage du play. Le mécanisme de modification des variables sera ajouté dans une feature ultérieure.

## Comportement attendu

### Affichage dans le graphe

- Les nœuds condition utilisent le même composant `GraphNodeItem` que les séquences.
- Ils ont une **couleur de fond distincte** (ex: violet/bleu) pour les différencier visuellement des séquences.
- Ils apparaissent dans le même graphe (`sequence_graph_view`) et peuvent être connectés aux nœuds séquence et aux autres nœuds condition.
- Les connexions issues des redirections de règles et du default sont calculées dynamiquement (comme pour les endings des séquences).

### Création d'un nœud condition

- Un bouton **"+ Nouvelle condition"** est ajouté dans la barre supérieure, visible uniquement au niveau "sequences".
- Il s'affiche à côté du bouton existant "+ Nouvelle séquence".
- Cliquer dessus crée un nœud condition avec un nom auto-incrémenté ("Condition 1", "Condition 2", etc.).

### Éditeur de condition (double-clic)

Quand on double-clique sur un nœud condition, on entre dans un écran d'édition dédié (niveau `"condition_edit"` dans la navigation). Le breadcrumb affiche le nom de la condition.

L'éditeur contient :

1. **Liste de règles** : une liste scrollable de règles, chacune affichant :
   - Un `LineEdit` pour le nom de la variable testée par cette règle
   - Un `OptionButton` pour l'opérateur (8 types)
   - Un `LineEdit` pour la valeur de comparaison (masqué si opérateur = Exists ou Not Exists)
   - Une ligne de redirection : `OptionButton` type de conséquence + `OptionButton` cible
   - Un bouton "×" pour supprimer la règle

3. **Bouton "+ Ajouter une règle"** en bas de la liste.

4. **Section "Default"** : une redirection par défaut avec `OptionButton` type + `OptionButton` cible, utilisée si aucune règle ne matche.

Le bouton "← Retour" ramène au graphe de séquences.

### Connexions dans le graphe

Les connexions issues d'un nœud condition sont calculées dans `_build_connection_type_map()` :
- Chaque règle dont la conséquence est `redirect_sequence` génère une connexion vers la cible, de type `"condition"`.
- Le `default_consequence` de type `redirect_sequence` génère aussi une connexion, de type `"condition"`.
- Le type `"condition"` utilise une couleur dédiée (ex: bleu/cyan) pour les ports.

### Évaluation pendant le play mode

Quand le `StoryPlayController` rencontre un nœud condition (au lieu d'une séquence) :

1. Parcourir `condition.rules` dans l'ordre.
2. Pour chaque règle, récupérer la valeur de `_variables[rule.variable]` et évaluer l'opérateur :
   - `exists` / `not_exists` : vérifier la présence de `rule.variable` dans `_variables`.
   - Comparaisons numériques : convertir en float et comparer. Si la conversion échoue → règle non matchée.
   - `equal` / `not_equal` : comparaison en string.
3. Si une règle matche, résoudre sa `consequence` (comme pour les endings).
4. Si aucune règle ne matche, résoudre `default_consequence`.
5. Si `default_consequence` est null → finir avec `"no_ending"`.

### Persistance

Les conditions sont sérialisées dans le YAML de la scène, dans un champ `"conditions"` au même niveau que `"sequences"`. Chaque condition est un dictionnaire avec `uuid`, `name`, `subtitle`, `position`, `rules` et `default_consequence`. Chaque règle contient `variable`, `operator`, `value` et `consequence`.

### Suppression et renommage

- Clic droit sur un nœud condition → même menu contextuel que les séquences (Renommer, Point d'entrée).
- La suppression d'un nœud condition supprime aussi les connexions associées.

## Critères d'acceptation

### Modèle de données
- [x] Le modèle `Condition` existe avec uuid, condition_name, subtitle, position, rules, default_consequence
- [x] Le modèle `ConditionRule` existe avec variable, operator, value, consequence
- [x] `SceneData` possède un champ `conditions: Array` et une méthode `find_condition(uuid)`
- [x] Les 8 opérateurs sont supportés
- [x] `Condition.to_dict()` et `Condition.from_dict()` fonctionnent correctement
- [x] `ConditionRule.to_dict()` et `ConditionRule.from_dict()` fonctionnent correctement

### Graphe de séquences
- [x] Les nœuds condition apparaissent dans le graphe avec une couleur de fond distincte
- [x] Un bouton "+ Nouvelle condition" est visible au niveau "sequences"
- [x] Cliquer sur le bouton crée un nœud condition avec un nom auto-incrémenté
- [x] Les nœuds condition peuvent être connectés manuellement aux nœuds séquence et condition
- [x] Les connexions issues des règles et du default sont calculées dynamiquement
- [x] La suppression d'un nœud condition supprime ses connexions
- [x] Le renommage fonctionne via le menu contextuel

### Éditeur de condition
- [x] Double-cliquer sur un nœud condition ouvre l'éditeur de condition
- [x] Le breadcrumb affiche le nom de la condition
- [x] On peut ajouter une règle via le bouton "+ Ajouter une règle"
- [x] Chaque règle affiche un champ variable, un dropdown opérateur, un champ valeur et une ligne de redirection
- [x] Le champ valeur est masqué quand l'opérateur est Exists ou Not Exists
- [x] On peut supprimer une règle avec le bouton "×"
- [x] La section Default affiche une redirection configurable
- [x] Les listes de cibles (séquences, scènes, chapitres) sont dynamiques
- [x] Le bouton "← Retour" ramène au graphe de séquences

### Play mode
- [x] `StoryPlayController` possède un dictionnaire `_variables` initialisé vide
- [x] Quand le play rencontre un nœud condition, les règles sont évaluées dans l'ordre
- [x] L'opérateur `equal` compare en string
- [x] Les opérateurs numériques (greater_than, etc.) convertissent en float
- [x] Les opérateurs `exists` / `not_exists` vérifient la présence de la clé
- [x] Si une règle matche, sa conséquence est résolue
- [x] Si aucune règle ne matche, la conséquence default est résolue
- [x] Si pas de default → fin avec "no_ending"

### Persistance
- [x] Les conditions sont sauvegardées dans le YAML de la scène
- [x] Les conditions sont chargées correctement au rechargement
- [x] Les connexions sont recalculées après rechargement

### Navigation
- [x] `EditorMain` supporte le niveau `"condition_edit"`
- [x] `navigate_to_condition(uuid)` fonctionne
- [x] `navigate_back()` depuis `"condition_edit"` revient à `"sequences"`
- [x] Le breadcrumb affiche le chemin complet incluant la condition
