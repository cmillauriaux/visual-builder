# Spécification 036 : Transitions de Séquence

Cette spécification définit l'implémentation des transitions d'apparition et de disparition pour les séquences dans l'éditeur de visual novel.

## 1. Objectif
Permettre aux créateurs de définir comment une séquence apparaît (transition d'entrée) et comment elle disparaît (transition de sortie) lors de la lecture, avec des effets comme le fondu ou la pixellisation.

## 2. Modèle de Données

Le modèle `SequenceModel` (`src/models/sequence.gd`) sera enrichi des propriétés suivantes :

- `transition_in_type`: Type de transition d'entrée (`"none"`, `"fade"`, `"pixelate"`). Par défaut : `"none"`.
- `transition_in_duration`: Durée de la transition d'entrée en secondes. Par défaut : `0.5`.
- `transition_out_type`: Type de transition de sortie (`"none"`, `"fade"`, `"pixelate"`). Par défaut : `"none"`.
- `transition_out_duration`: Durée de la transition de sortie en secondes. Par défaut : `0.5`.

## 3. Interface Utilisateur (Éditeur de Séquence)

L'interface de l'éditeur de séquence (`src/ui/sequence_editor/...`) doit permettre de configurer ces paramètres. Un nouvel onglet ou une nouvelle section "Transitions" sera ajoutée.

- Menu déroulant pour le type d'entrée.
- Champ numérique pour la durée d'entrée.
- Menu déroulant pour le type de sortie.
- Champ numérique pour la durée de sortie.

## 4. Logique de Lecture (Playback)

La logique de lecture dans `PlayController` et `GamePlayController` doit être mise à jour pour déclencher ces transitions.

### 4.1. Transition d'Entrée
Lorsqu'une séquence est demandée :
1. Charger les données de la séquence (fond, personnages, texte).
2. Si `transition_in_type` n'est pas `"none"`, appliquer l'effet visuel sur l'ensemble de la vue pendant `transition_in_duration`.
3. Commencer la lecture du texte (typewriter) seulement après la fin de la transition d'entrée (ou en parallèle selon le réglage, mais généralement après pour la lisibilité).

### 4.2. Transition de Sortie
Lorsqu'une séquence se termine (clic après le dernier dialogue ou choix effectué) :
1. Si `transition_out_type` n'est pas `"none"`, appliquer l'effet visuel pendant `transition_out_duration`.
2. Une fois la transition terminée, passer à la séquence suivante ou terminer la scène.

## 5. Effets Visuels

### 5.1. Fondu (Fade)
Un fondu au noir (ou vers la transparence si on veut voir la séquence précédente, mais le fondu au noir est plus standard pour les changements de séquence).

### 5.2. Pixellisation (Pixelate)
Un effet de mosaïque qui augmente ou diminue en résolution. Nécessite un shader.

## 6. Critères d'Acceptation
- [x] Les propriétés de transition sont sauvegardées et chargées correctement dans le fichier de l'histoire.
- [x] L'interface utilisateur permet de modifier les types et durées de transition.
- [x] La transition d'entrée s'exécute correctement au début de la séquence.
- [x] La transition de sortie s'exécute correctement à la fin de la séquence, avant de passer à la suivante.
- [x] L'effet de fondu est fonctionnel.
- [x] L'effet de pixellisation est fonctionnel.
