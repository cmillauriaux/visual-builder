# Éditeur de Visual Novel

## Résumé

Un éditeur complet de Visual Novel dans Godot 4.4 permettant de créer, charger et sauvegarder des histoires interactives. L'éditeur offre une navigation hiérarchique à 3 niveaux de graphes (Chapitres → Scènes → Séquences) avec branchement libre à chaque niveau. Les données sont persistées au format YAML avec un dossier structuré par histoire.

## Modèle de données

### Histoire

Métadonnées :

- **Titre** (string, obligatoire)
- **Auteur** (string, obligatoire)
- **Description** (string, optionnel)
- **Version** (string, ex: "1.0.0")
- **Date de création** (datetime, auto-générée)
- **Date de modification** (datetime, mise à jour automatiquement)

Une histoire contient un graphe de **chapitres** reliés entre eux.

### Chapitre

- **UUID** (généré automatiquement, utilisé pour les références internes)
- **Nom** (string, affiché dans l'éditeur)
- **Position dans le graphe** (x, y — pour l'affichage du noeud)

Un chapitre contient un graphe de **scènes** reliées entre elles.

### Scène

- **UUID** (généré automatiquement)
- **Nom** (string)
- **Position dans le graphe** (x, y)

Une scène contient un graphe de **séquences** reliées entre elles.

### Séquence

- **UUID** (généré automatiquement)
- **Nom** (string)
- **Position dans le graphe** (x, y)
- **Background** : chemin relatif vers une image (depuis le dossier `assets/backgrounds/`)
- **Foregrounds** : liste ordonnée de foregrounds (voir ci-dessous)
- **Dialogues** : liste ordonnée de dialogues
- **Terminaison** : un choix (1 à 8 options) OU une redirection automatique

### Foreground

- **UUID** (généré automatiquement)
- **Nom** (string, pour identifier le foreground dans l'éditeur)
- **Image** : chemin relatif vers une image (depuis le dossier `assets/foregrounds/`)
- **Z-order** (int, détermine l'ordre de superposition)
- **Opacité** (float, 0.0 à 1.0, défaut: 1.0)
- **Flip horizontal** (bool, défaut: false)
- **Flip vertical** (bool, défaut: false)
- **Échelle** (float, défaut: 1.0)
- **Ancre background** (x%, y%) : point d'ancrage sur le background (en pourcentage)
- **Ancre foreground** (x%, y%) : point d'ancrage sur le foreground (en pourcentage, ex: 0.5/1.0 pour le bas-centre)

Le système d'ancrage point-à-point lie un point du foreground à un point du background. Quel que soit le ratio ou la taille de la fenêtre, le point d'ancrage du foreground reste aligné sur le point d'ancrage du background.

### Dialogue

- **Nom du personnage** (string)
- **Texte** (string)

### Terminaison de séquence

Deux modes mutuellement exclusifs :

**Mode Choix** (1 à 8 choix) — chaque choix contient :

- **Texte** (string, affiché au joueur)
- **Conséquence** : une des valeurs suivantes :
  - `redirect_sequence` : UUID d'une séquence cible
  - `redirect_scene` : UUID d'une scène cible
  - `redirect_chapter` : UUID d'un chapitre cible
  - `game_over` : fin de partie
  - `to_be_continued` : indication de suite à venir
- **Conditions** (objet, réservé pour usage futur — vide par défaut)

**Mode Redirection automatique** — une unique conséquence (mêmes types que ci-dessus) déclenchée automatiquement à la fin des dialogues.

## Structure de fichiers

```
mon-histoire/
├─ story.yaml
├─ chapters/
│  ├─ <uuid-chapitre>/
│  │  ├─ chapter.yaml
│  │  └─ scenes/
│  │     ├─ <uuid-scene>.yaml
│  │     └─ <uuid-scene>.yaml
│  └─ <uuid-chapitre>/
│     ├─ chapter.yaml
│     └─ scenes/
│        └─ ...
└─ assets/
   ├─ backgrounds/
   │  ├─ foret.png
   │  └─ ...
   └─ foregrounds/
      ├─ personnage-a.png
      └─ ...
```

### story.yaml

```yaml
title: "Mon Histoire"
author: "Auteur"
description: "Une aventure interactive..."
version: "1.0.0"
created_at: "2026-02-21T10:00:00Z"
updated_at: "2026-02-21T15:30:00Z"
chapters:
  - uuid: "abc-123"
    name: "Chapitre 1 — Le début"
    position: { x: 100, y: 200 }
  - uuid: "def-456"
    name: "Chapitre 2 — La rencontre"
    position: { x: 400, y: 200 }
connections:
  - from: "abc-123"
    to: "def-456"
```

### chapter.yaml

```yaml
uuid: "abc-123"
name: "Chapitre 1 — Le début"
scenes:
  - uuid: "scene-001"
    name: "Arrivée en forêt"
    position: { x: 50, y: 100 }
  - uuid: "scene-002"
    name: "Rencontre mystérieuse"
    position: { x: 300, y: 100 }
connections:
  - from: "scene-001"
    to: "scene-002"
```

### scene YAML (ex: `<uuid-scene>.yaml`)

```yaml
uuid: "scene-001"
name: "Arrivée en forêt"
sequences:
  - uuid: "seq-001"
    name: "Exploration"
    position: { x: 0, y: 0 }
    background: "foret.png"
    foregrounds:
      - uuid: "fg-001"
        name: "Héros"
        image: "personnage-a.png"
        z_order: 1
        opacity: 1.0
        flip_h: false
        flip_v: false
        scale: 1.0
        anchor_bg: { x: 0.5, y: 0.8 }
        anchor_fg: { x: 0.5, y: 1.0 }
    dialogues:
      - character: "Héros"
        text: "Où suis-je ?"
      - character: "Héros"
        text: "Cette forêt est étrange..."
    ending:
      type: "choices"
      choices:
        - text: "Explorer le chemin de gauche"
          consequence:
            type: "redirect_sequence"
            target: "seq-002"
          conditions: {}
        - text: "Faire demi-tour"
          consequence:
            type: "redirect_scene"
            target: "scene-003"
          conditions: {}
        - text: "Abandonner"
          consequence:
            type: "game_over"
          conditions: {}
  - uuid: "seq-002"
    name: "Chemin de gauche"
    position: { x: 300, y: 0 }
    background: "foret-sombre.png"
    foregrounds: []
    dialogues:
      - character: "Narrateur"
        text: "La suite au prochain épisode..."
    ending:
      type: "auto_redirect"
      consequence:
        type: "to_be_continued"
connections:
  - from: "seq-001"
    to: "seq-002"
```

## Comportement attendu

### Gestion des histoires

- **Créer une histoire** : l'utilisateur saisit le titre et l'auteur (description optionnelle). Le dossier et le `story.yaml` sont créés. La version est initialisée à "1.0.0". Les dates sont auto-générées.
- **Charger une histoire** : l'utilisateur sélectionne un dossier d'histoire via un dialogue de fichier. Le `story.yaml` est lu et l'éditeur s'ouvre sur la vue chapitres.
- **Sauvegarder une histoire** : écrit tous les fichiers YAML modifiés. La date de modification est mise à jour automatiquement.

### Vue Chapitres (graphe de noeuds — niveau 1)

- Chaque chapitre est représenté par un noeud dans un graphe 2D.
- Les connexions entre chapitres sont affichées sous forme de liens directionnels (flèches).
- L'utilisateur peut :
  - **Créer** un chapitre (clic droit → "Nouveau chapitre" ou bouton dédié)
  - **Renommer** un chapitre (double-clic sur le titre du noeud)
  - **Supprimer** un chapitre (clic droit → "Supprimer" avec confirmation)
  - **Déplacer** les noeuds (drag & drop)
  - **Connecter** deux chapitres (drag d'un port de sortie vers un port d'entrée)
  - **Naviguer** vers les scènes : double-clic sur un noeud chapitre → ouvre la vue Scènes

### Vue Scènes (graphe de noeuds — niveau 2)

- Affiche un fil d'Ariane : `Histoire > Chapitre X` pour la navigation.
- Chaque scène est un noeud. Mêmes interactions que la vue chapitres (créer, renommer, supprimer, déplacer, connecter).
- Double-clic sur un noeud scène → ouvre la vue Séquences.
- Bouton "Retour" pour revenir à la vue Chapitres.

### Vue Séquences (graphe de noeuds — niveau 3)

- Fil d'Ariane : `Histoire > Chapitre X > Scène Y`.
- Chaque séquence est un noeud. Mêmes interactions de base (créer, renommer, supprimer, déplacer, connecter).
- Double-clic sur un noeud séquence → ouvre l'éditeur visuel de séquence.
- Bouton "Retour" pour revenir à la vue Scènes.

### Éditeur visuel de séquence

- Fil d'Ariane : `Histoire > Chapitre X > Scène Y > Séquence Z`.
- Affiche le **background** en tant qu'image de fond.
- L'utilisateur peut **zoomer** (molette) et **déplacer** le background (clic milieu / drag).
- Les **foregrounds** sont affichés par-dessus, positionnés selon leur ancrage.
- L'utilisateur peut :
  - **Ajouter un foreground** : sélectionne une image depuis `assets/foregrounds/`. Définit un nom.
  - **Positionner un foreground** : drag & drop pour déplacer le foreground. Le point d'ancrage background est recalculé en temps réel.
  - **Redimensionner un foreground** : poignées de redimensionnement aux coins/bords.
  - **Configurer un foreground** : panneau de propriétés (nom, z-order, opacité, flip H/V, points d'ancrage précis).
  - **Supprimer un foreground** : sélection + touche Suppr ou clic droit → "Supprimer".
  - **Définir le point d'ancrage foreground** : clic sur le foreground avec un outil dédié pour placer le point d'ancrage.
  - **Changer le background** : bouton ou clic droit pour sélectionner une autre image.

### Éditeur de dialogues

Accessible depuis l'éditeur visuel de séquence (panneau latéral ou onglet).

- Affiche la liste ordonnée des dialogues de la séquence.
- L'utilisateur peut :
  - **Ajouter** un dialogue (nom du personnage + texte)
  - **Modifier** un dialogue existant
  - **Supprimer** un dialogue
  - **Réordonner** les dialogues (drag & drop dans la liste)

### Éditeur de terminaison

Accessible depuis l'éditeur visuel de séquence (panneau latéral ou onglet).

- L'utilisateur choisit le mode de terminaison :
  - **Choix** : affiche une liste de 1 à 8 choix. Chaque choix a un texte et une conséquence.
  - **Redirection automatique** : une seule conséquence appliquée à la fin des dialogues.
- Types de conséquence :
  - **Redirection séquence** : sélecteur de séquence (dans la scène courante)
  - **Redirection scène** : sélecteur de scène (dans le chapitre courant)
  - **Redirection chapitre** : sélecteur de chapitre (dans l'histoire)
  - **Game Over** : marque une fin de partie
  - **To be continued** : marque une suite à venir

### Navigation générale

- Un **fil d'Ariane** cliquable permet de remonter à n'importe quel niveau.
- Le bouton **Retour** ramène au niveau supérieur.
- Les connexions dans les graphes correspondent aux redirections définies dans les terminaisons des séquences et aux liens manuels entre noeuds.

## Critères d'acceptation

### Gestion des histoires

- [ ] L'utilisateur peut créer une nouvelle histoire avec titre, auteur, description, et la structure de dossiers est correctement générée
- [ ] L'utilisateur peut charger une histoire existante depuis un dossier et retrouver toutes les données
- [ ] La sauvegarde écrit tous les fichiers YAML modifiés et met à jour la date de modification
- [ ] Le format YAML est conforme aux exemples de la spec et peut être relu sans perte de données

### Vue Chapitres

- [ ] Les chapitres sont affichés comme des noeuds dans un graphe 2D
- [ ] L'utilisateur peut créer, renommer et supprimer un chapitre
- [ ] Les noeuds sont déplaçables par drag & drop
- [ ] Les connexions entre chapitres sont affichées avec des flèches directionnelles
- [ ] L'utilisateur peut connecter deux chapitres par drag entre ports
- [ ] Le double-clic sur un chapitre ouvre la vue Scènes correspondante

### Vue Scènes

- [ ] Le fil d'Ariane affiche `Histoire > Chapitre X` et permet de remonter
- [ ] Les scènes sont affichées comme des noeuds avec les mêmes interactions que les chapitres
- [ ] Le double-clic sur une scène ouvre la vue Séquences correspondante

### Vue Séquences

- [ ] Le fil d'Ariane affiche `Histoire > Chapitre X > Scène Y`
- [ ] Les séquences sont affichées comme des noeuds avec les mêmes interactions
- [ ] Le double-clic sur une séquence ouvre l'éditeur visuel de séquence

### Éditeur visuel de séquence

- [ ] Le background est affiché et l'utilisateur peut zoomer et le déplacer
- [ ] Les foregrounds sont affichés par-dessus le background, positionnés selon leurs ancres
- [ ] L'utilisateur peut ajouter, positionner, redimensionner et supprimer des foregrounds
- [ ] Les propriétés d'un foreground (nom, z-order, opacité, flip H/V) sont modifiables
- [ ] Le système d'ancrage point-à-point fonctionne : le foreground reste ancré au même point du background quel que soit le ratio/taille de la fenêtre
- [ ] L'utilisateur peut changer le background de la séquence

### Dialogues

- [ ] L'utilisateur peut ajouter un dialogue (nom de personnage + texte)
- [ ] L'utilisateur peut modifier et supprimer un dialogue
- [ ] L'utilisateur peut réordonner les dialogues par drag & drop
- [ ] Les dialogues sont sauvegardés dans l'ordre défini

### Terminaison de séquence

- [ ] L'utilisateur peut choisir entre mode "Choix" et mode "Redirection automatique"
- [ ] En mode Choix, l'utilisateur peut ajouter de 1 à 8 choix avec texte et conséquence
- [ ] Chaque conséquence peut être : redirection séquence, redirection scène, redirection chapitre, game over, ou to be continued
- [ ] En mode Redirection automatique, une unique conséquence est configurable
- [ ] Le champ `conditions` est présent dans le YAML pour chaque choix (vide par défaut, usage futur)

### Persistance

- [ ] La structure de dossiers respecte le format spécifié (story.yaml, chapters/<uuid>/chapter.yaml, scenes/<uuid>.yaml, assets/)
- [ ] Tous les éléments utilisent des UUID générés automatiquement
- [ ] Les images sont référencées par chemin relatif depuis les dossiers assets/
- [ ] Un cycle complet créer → sauvegarder → fermer → charger → vérifier fonctionne sans perte
