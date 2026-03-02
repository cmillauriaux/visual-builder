# Notifications de variables d'histoire

## Résumé

Permet à l'auteur de définir des **notifications** au niveau de l'histoire : chaque notification associe un pattern glob (ex. `*_affinity`) à un message textuel fixe (ex. « Le personnage s'en souviendra »). En play mode, lorsqu'une variable dont le nom correspond au pattern est modifiée, un toast s'affiche brièvement à l'écran.

Le panneau de gestion est accessible via un bouton **"Notifications"** dans la barre d'outils, visible uniquement au niveau "Histoire" (level `"chapters"`).

## Modèle de données

### StoryNotification (`src/models/story_notification.gd`)

```
StoryNotification (RefCounted)
├─ pattern: String   (glob, ex: "*_affinity")
└─ message: String   (ex: "Le personnage s'en souviendra")
```

Méthodes :
- `matches(var_name: String) -> bool` — retourne `true` si `var_name` correspond au pattern glob
- `to_dict() -> Dictionary`
- `static from_dict(d: Dictionary) -> StoryNotification`

#### Conversion glob → regex

| Glob | Regex |
|------|-------|
| `*`  | `.*`  |
| `?`  | `.`   |
| Tout autre caractère | échappé (`\\.`, `\\(`, etc.) |

La correspondance est totale (anchored : `^pattern$`, case-sensitive).

### Modifications sur Story

```
Story
├─ ... (champs existants)
└─ notifications: Array   # Array[StoryNotification]
```

Méthodes ajoutées :
- `get_triggered_notifications(var_name: String) -> Array[StoryNotification]` — retourne toutes les notifications dont le pattern correspond à `var_name`

### Persistance (story.yaml)

```yaml
title: "Mon histoire"
variables: [...]
notifications:
  - pattern: "*_affinity"
    message: "Le personnage s'en souviendra"
  - pattern: "score"
    message: "Score mis à jour"
chapters: [...]
```

Rétrocompatibilité : si le champ `notifications` est absent du fichier, le tableau est initialisé vide.

## Comportement attendu

### Bouton "Notifications" (éditeur)

- Le bouton **"Notifications"** est ajouté dans la barre d'outils principale.
- Il est visible **uniquement** au niveau `"chapters"` (comme le bouton "Vérifier").
- Cliquer dessus ouvre un dialog modal (`ConfirmationDialog` ou `AcceptDialog`) : le **panneau de notifications**.

### Panneau de notifications (dialog)

Le panneau contient :

1. **Liste des notifications** : chaque ligne affiche :
   - Un `LineEdit` pour le **pattern** (placeholder : `*_affinity`)
   - Un `LineEdit` pour le **message** (placeholder : `Le personnage s'en souviendra`)
   - Un bouton **"×"** pour supprimer la notification
2. **Bouton "+ Ajouter une notification"** en bas de la liste
3. Un bouton **"Fermer"** (ou "OK") pour valider et fermer

Les modifications sont appliquées en temps réel sur le modèle `Story`. Les patterns vides sont ignorés (la ligne reste éditable mais n'est pas sauvegardée si le pattern est vide au moment de la fermeture — ou, plus simplement, les notifications avec pattern vide sont filtrées lors du traitement en play mode).

### Play mode — Détection et affichage

La détection se fait dans `StoryPlayController._apply_effects()`.

#### Détection des changements

Avant d'appliquer les effets, un snapshot du dictionnaire `_variables` est pris. Après application, chaque variable dont la valeur a changé (ou qui a été créée) est comparée aux patterns des notifications de l'histoire :

```gdscript
func _apply_effects(effects: Array) -> void:
    var before := _variables.duplicate()
    for effect in effects:
        effect.apply(_variables)
    _check_notifications(before)

func _check_notifications(before: Dictionary) -> void:
    if _story == null or _story.get("notifications") == null:
        return
    for var_name in _variables:
        if not before.has(var_name) or before[var_name] != _variables[var_name]:
            for notif in _story.notifications:
                if notif.matches(var_name):
                    notification_triggered.emit(notif.message)
```

#### Signal

`StoryPlayController` émet un nouveau signal :

```gdscript
signal notification_triggered(message: String)
```

#### Toast (affichage UI)

Un **bandeau toast** est ajouté à la scène principale (`main.gd`), superposé à l'overlay de play :

- Un `PanelContainer` + `Label` en haut à droite de l'écran
- Lors de `notification_triggered`, le texte du label est mis à jour et le toast devient visible
- Après **3 secondes**, le toast se masque automatiquement (via `SceneTree.create_timer`)
- Si une nouvelle notification arrive pendant que le toast est visible, le timer est remis à zéro et le message est remplacé
- Le toast n'est pas interactif (pas de clic requis pour le fermer)
- Le toast est invisible en dehors du play mode histoire (`_story_play_ctrl`)

## Critères d'acceptation

### Modèle StoryNotification
- [x] `StoryNotification` existe avec les champs `pattern` et `message`
- [x] `StoryNotification.matches("mme_girard_affinity")` retourne `true` pour le pattern `"*_affinity"`
- [x] `StoryNotification.matches("score")` retourne `false` pour le pattern `"*_affinity"`
- [x] `StoryNotification.matches("score")` retourne `true` pour le pattern `"score"`
- [x] `StoryNotification.matches("a_b")` retourne `true` pour le pattern `"?_?"`
- [x] `StoryNotification.to_dict()` et `from_dict()` fonctionnent correctement

### Modifications sur Story
- [x] `Story` possède un champ `notifications: Array`
- [x] `Story.get_triggered_notifications("mme_girard_affinity")` retourne les notifications dont le pattern correspond
- [x] Les notifications sont sérialisées/désérialisées dans le YAML
- [x] Rétrocompatibilité : une histoire sans `notifications` se charge sans erreur (tableau vide)

### Bouton "Notifications" (UI)
- [x] Le bouton "Notifications" est visible au niveau `"chapters"`
- [x] Le bouton "Notifications" est invisible aux autres niveaux (`scenes`, `sequences`, `sequence_edit`, `condition_edit`)
- [x] Cliquer sur le bouton ouvre le panneau de notifications

### Panneau de notifications (UI)
- [x] Le panneau affiche la liste des notifications de l'histoire courante
- [x] On peut ajouter une notification via "+ Ajouter une notification"
- [x] Chaque ligne affiche un champ pattern, un champ message et un bouton ×
- [x] Le bouton × supprime la notification de la liste et du modèle
- [x] Les modifications du pattern et du message sont appliquées sur le modèle `Story`
- [x] Fermer le dialog ne perd pas les modifications

### Play mode
- [x] `StoryPlayController` émet `notification_triggered(message)` quand une variable modifiée par un effet correspond au pattern d'une notification
- [x] `notification_triggered` n'est pas émis si la valeur de la variable ne change pas
- [x] Plusieurs notifications peuvent être déclenchées par un même effet si plusieurs patterns correspondent
- [x] Le toast s'affiche avec le bon message lors de `notification_triggered`
- [x] Le toast disparaît automatiquement après 3 secondes
- [x] Un nouveau `notification_triggered` pendant que le toast est visible remet le timer à zéro et met à jour le message
- [x] Le toast n'est pas visible en dehors du play mode histoire
