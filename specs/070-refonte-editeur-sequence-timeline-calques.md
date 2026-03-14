# Refonte de l'éditeur de séquence — Layout Timeline + Calques

## Résumé

L'éditeur de séquence actuel (spec 003) souffre de deux problèmes majeurs : l'héritage des foregrounds est invisible (aucun indicateur ne distingue un foreground propre d'un hérité, et la copie silencieuse lors de la modification est déroutante), et les workflows courants demandent trop de manipulations (ajouter un foreground, dupliquer entre dialogues). Cette refonte remplace le layout actuel (HSplitContainer canvas/dialogues) par un layout à 3 zones : canvas central, panneau droit (dialogue + calques + propriétés + onglets), et timeline horizontale des dialogues en bas.

## Layout général

### Structure

```
┌──────────────────────────────────────────────────┐
│ Toolbar : ⬅ Retour | BG | +FG | Grille | Snap | ▶│
├───────────────────────────────┬──────────────────┤
│                               │ Section Dialogue │
│   Canvas visuel 1920×1080     │ Section Calques  │
│   (zoom, pan, foregrounds)    │ Section Propriétés│
│                               │ Onglets secondaires│
├───────────────────────────────┴──────────────────┤
│ Timeline des dialogues (vignettes horizontales)   │
└──────────────────────────────────────────────────┘
```

- **Canvas** (~65% de la largeur) : identique à l'existant (zoom/pan, foregrounds interactifs, grille, snap). Ajout d'indicateurs visuels d'héritage.
- **Panneau droit** (~35%) : VBoxContainer avec 4 sections empilées (voir ci-dessous).
- **Timeline** (bas, hauteur fixe ~120px) : ScrollContainer horizontal avec vignettes des dialogues.
- Le HSplitContainer entre canvas et panneau droit reste redimensionnable.

### Toolbar

Identique à l'existant : boutons Importer background, + Foreground, Grille (toggle), Snap (toggle), Normaliser, Play, Stop. Aucune modification de la toolbar.

## Panneau droit

### 1. Section Dialogue (haut)

Affiche et permet d'éditer le dialogue actuellement sélectionné :

- **Champ Personnage** : `LineEdit` avec label, prérempli avec `dialogue.character`. La modification met à jour le modèle en temps réel.
- **Champ Texte** : `TextEdit` (multiligne) avec label, prérempli avec `dialogue.text`. La modification met à jour le modèle en temps réel.
- **Bouton Supprimer** : icône corbeille, supprime le dialogue sélectionné (avec confirmation).
- **Label indicateur** : affiche "Dialogue #N" (index 1-based).
- Quand aucun dialogue n'est sélectionné, la section est masquée ou affiche un message "Sélectionnez un dialogue".

### 2. Section Calques (milieu, extensible)

Liste verticale des foregrounds du dialogue sélectionné. Chaque item de la liste affiche :

- **Handle drag** (☰) : pour réordonner par drag & drop dans la liste. Le drag modifie le z-order des foregrounds (le premier en haut = z-order le plus haut).
- **Toggle visibilité** (👁) : masque/affiche temporairement le foreground sur le canvas (utilise le mécanisme `_hidden_fg_uuids` existant).
- **Miniature** : vignette carrée 24×24px de l'image du foreground.
- **Nom** : `fg_name` du foreground.
- **Z-order** : valeur numérique affichée à droite.

**Indicateurs d'héritage dans les calques :**

- **Foreground propre** : bordure gauche colorée (couleur unique par FG), fond normal, toutes les interactions disponibles.
- **Foreground hérité** : bordure gauche pointillée orange (`#ffaa00`), opacité réduite à 0.6, badge texte "hérité du dialogue #N" (N = index du dialogue source), handle drag désactivé (on ne peut pas réordonner un FG hérité sans d'abord le rendre propre).

**Actions de la section :**

- **Bouton "+ Ajouter"** : ouvre l'image picker pour ajouter un foreground. Si le dialogue hérite ses FG, appelle `ensure_own_foregrounds()` d'abord.
- **Bouton "Coller"** : colle un foreground depuis le clipboard (`_fg_clipboard`).
- **Clic sur un item** : sélectionne le foreground dans la liste ET sur le canvas (synchronisation bidirectionnelle avec `sequence_visual_editor`).
- **Clic droit sur un item** : menu contextuel existant (Supprimer, Copier params, Copier FG, Remplacer, Cacher).

**Drag & drop vers la timeline :**

- L'utilisateur peut glisser un item de calque vers une vignette de la timeline pour copier ce foreground dans un autre dialogue.
- Le foreground copié reçoit un nouvel UUID (via `_copy_foreground()` avec nouveau UUID).
- Si le dialogue cible hérite ses FG, `ensure_own_foregrounds()` est appelé sur le dialogue cible d'abord.
- Feedback visuel : la vignette cible s'illumine (bordure verte ou bleue) pendant le survol.

### 3. Section Propriétés (sous les calques)

Affiche les propriétés du foreground sélectionné dans les calques. Remplace entièrement le `transition_panel.gd` actuel. Visible uniquement quand un foreground est sélectionné.

Propriétés affichées :

| Propriété | Widget | Plage |
|-----------|--------|-------|
| Position X | SpinBox | 0.0 — 1.0 (anchor_bg.x) |
| Position Y | SpinBox | 0.0 — 1.0 (anchor_bg.y) |
| Scale | SpinBox | 0.1 — 10.0 |
| Z-order | SpinBox | -100 — 100 |
| Flip H | CheckButton | on/off |
| Flip V | CheckButton | on/off |
| Opacité | HSlider + label | 0.0 — 1.0 |
| Transition type | OptionButton | "Aucune" / "Fondu" |
| Transition durée | SpinBox | 0.1 — 5.0 s |

Toute modification dans ce panneau met à jour le modèle foreground ET le canvas en temps réel.

### 4. Onglets secondaires (bas)

TabContainer réduit contenant les onglets existants, **sans l'onglet Dialogues** (remplacé par la timeline) :

- **Terminaison** : identique à l'existant (EndingEditor).
- **Musique** : identique à l'existant (AudioPanel).
- **FX** : identique à l'existant (FxPanel).
- **Paramètres** : identique à l'existant (titre, sous-titre, couleur BG, transitions séquence).

Aucune modification du contenu de ces onglets.

## Timeline des dialogues

### Apparence

Bandeau horizontal fixe en bas de l'éditeur de séquence. Contient un `ScrollContainer` horizontal avec un `HBoxContainer` de vignettes.

Chaque vignette de dialogue affiche :

- **Mini-aperçu** (haut, ~60px de haut) : background réduit avec les silhouettes/miniatures des foregrounds positionnés approximativement.
- **Badge compteur FG** (coin haut-droit) : fond bleu, texte "N FG" (nombre de foregrounds propres).
- **Personnage** (bas) : nom du personnage en gras.
- **Texte** (bas, sous le personnage) : début du texte tronqué avec ellipsis.

### Indicateurs d'héritage dans la timeline

- **Dialogue avec FG propres** : bordure normale, badge bleu "N FG", opacité 1.0.
- **Dialogue héritant ses FG** : opacité réduite 0.65, bordure pointillée orange, badge orange "⟵ hérité" au lieu du compteur FG.

### Vignette sélectionnée

- Bordure bleue (`#4a4aff`) de 2px.
- Légère ombre portée (glow).
- Le personnage est affiché en couleur bleue au lieu de gris.

### Interactions

- **Clic** : sélectionne le dialogue. Met à jour le canvas, les calques, les propriétés et la section dialogue du panneau droit.
- **Drag & drop** : réordonne les dialogues dans la séquence (reprend le pattern existant de `dialogue_list_panel.gd`).
- **Bouton "+"** : dernière vignette, style dashed. Ajoute un nouveau dialogue à la fin de la séquence.
- **Drop zone** : accepte les foregrounds glissés depuis le panneau calques (voir section "Drag & drop vers la timeline" ci-dessus).

## Indicateurs d'héritage sur le canvas

### Foreground propre sur le canvas

- Bordure pleine de sélection (bleu, comme actuellement).
- Opacité normale.
- Toutes les interactions disponibles (drag, resize, menu contextuel).

### Foreground hérité sur le canvas

- Bordure **pointillée** au lieu de pleine.
- Opacité réduite (semi-transparent, ~0.5 de l'opacité du FG).
- Clic sur un FG hérité : affiche un message de confirmation "Ce foreground est hérité du dialogue #N. Le modifier créera une copie locale pour ce dialogue." avec bouton "Confirmer".
- Après confirmation : `ensure_own_foregrounds()` est appelé, les calques et le canvas se rafraîchissent (les FG ne sont plus marqués comme hérités).

## Workflow : modifier un foreground hérité

1. L'utilisateur sélectionne un dialogue qui hérite ses foregrounds.
2. Les FG sont affichés avec les indicateurs d'héritage (canvas : bordure pointillée + semi-transparent ; calques : bordure orange + badge + opacité 0.6).
3. L'utilisateur clique sur un FG hérité (dans les calques ou sur le canvas).
4. Un `AcceptDialog` s'affiche : "Ce foreground est hérité du dialogue #N. Le modifier créera une copie locale pour ce dialogue."
5. Si l'utilisateur confirme : `ensure_own_foregrounds()` copie tous les FG hérités vers le dialogue courant.
6. L'affichage se rafraîchit : les FG sont maintenant propres (bordures pleines, pas de badge hérité).
7. L'utilisateur peut maintenant modifier librement.

## Workflow : ajouter un foreground

1. L'utilisateur clique sur "+ Foreground" (toolbar) ou "+ Ajouter" (panneau calques).
2. L'image picker s'ouvre.
3. Si le dialogue hérite ses FG → `ensure_own_foregrounds()` est appelé silencieusement (pas de confirmation, car l'intention d'ajouter implique la volonté de modifier).
4. Le FG est créé et ajouté au dialogue.
5. Le FG est positionné intelligemment : à côté du dernier FG (et non au centre exact), pour éviter l'empilement.
6. Les calques et le canvas se rafraîchissent.

## Workflow : dupliquer un foreground entre dialogues

1. L'utilisateur glisse un item du panneau calques.
2. Il survole la timeline : les vignettes réagissent au survol (bordure illuminée).
3. Il dépose sur une vignette de dialogue cible.
4. Si le dialogue cible hérite ses FG → `ensure_own_foregrounds()` est appelé d'abord.
5. Le FG est copié avec un nouveau UUID dans le dialogue cible.
6. La timeline et les calques se rafraîchissent (si le dialogue cible est le dialogue sélectionné).

## Synchronisation bidirectionnelle calques ↔ canvas

- **Sélection calque → canvas** : cliquer sur un item de calque sélectionne le FG correspondant sur le canvas (bordure de sélection).
- **Sélection canvas → calque** : cliquer sur un FG dans le canvas met en surbrillance l'item correspondant dans les calques.
- **Visibilité** : le toggle 👁 dans les calques masque/affiche le FG sur le canvas.
- **Z-order** : réordonner dans les calques met à jour le z-order dans le modèle ET l'ordre visuel sur le canvas.

## Fichiers impactés

### Nouveaux fichiers

| Fichier | Rôle |
|---------|------|
| `src/ui/sequence/dialogue_timeline.gd` | Timeline horizontale en bas (ScrollContainer + HBox de vignettes) |
| `src/ui/sequence/dialogue_timeline_item.gd` | Vignette individuelle de la timeline |
| `src/ui/sequence/foreground_layer_panel.gd` | Panneau calques dans le panneau droit |
| `src/ui/sequence/foreground_layer_item.gd` | Item individuel dans le panneau calques |
| `src/ui/sequence/foreground_properties_panel.gd` | Panneau propriétés (remplace transition_panel) |
| `src/ui/sequence/dialogue_edit_section.gd` | Section édition dialogue (personnage + texte) |

### Fichiers modifiés

| Fichier | Modification |
|---------|-------------|
| `src/controllers/main_ui_builder.gd` | Refaire `_build_sequence_editor()` avec le nouveau layout |
| `src/main.gd` | Nouvelles variables UI, nouveaux signaux |
| `src/ui/sequence/sequence_visual_editor.gd` | Indicateurs d'héritage sur le canvas |
| `src/ui/sequence/sequence_editor.gd` | Ajouter `is_dialogue_inheriting()`, `get_inheritance_source_index()` |
| `src/controllers/sequence_ui_controller.gd` | Adapter pour le nouveau layout |

### Fichiers supprimés

| Fichier | Raison |
|---------|--------|
| `src/ui/sequence/transition_panel.gd` | Remplacé par `foreground_properties_panel.gd` |
| `src/ui/sequence/dialogue_list_panel.gd` | Remplacé par `dialogue_timeline.gd` |
| `src/ui/sequence/dialogue_list_item.gd` | Remplacé par `dialogue_timeline_item.gd` |

## Critères d'acceptation

### Layout

- [x] L'éditeur de séquence affiche 3 zones : canvas à gauche, panneau droit, timeline en bas
- [x] Le panneau droit contient 4 sections empilées : dialogue, calques, propriétés, onglets secondaires
- [x] La timeline en bas affiche des vignettes horizontales scrollables pour chaque dialogue
- [x] Le HSplitContainer entre canvas et panneau droit est redimensionnable

### Section Dialogue

- [x] Le personnage et le texte du dialogue sélectionné sont affichés et éditables
- [x] Les modifications sont reflétées en temps réel dans le modèle et la timeline
- [x] Le bouton supprimer supprime le dialogue avec confirmation

### Section Calques

- [x] Chaque foreground est affiché avec miniature, nom, z-order, handle drag et toggle visibilité
- [x] Les foregrounds hérités ont une bordure pointillée orange, opacité 0.6, badge "hérité du dialogue #N"
- [x] Les foregrounds propres ont une bordure pleine colorée
- [ ] Le drag & drop dans la liste réordonne les foregrounds (z-order)
- [x] Le toggle visibilité masque/affiche le foreground sur le canvas
- [x] Le bouton "+ Ajouter" ouvre l'image picker
- [x] Le bouton "Coller" colle un foreground depuis le clipboard
- [ ] Le clic droit ouvre le menu contextuel existant

### Section Propriétés

- [x] Toutes les propriétés sont affichées : position, scale, z-order, flip H/V, opacité, transition type/durée
- [x] Les modifications sont reflétées en temps réel sur le canvas
- [x] La section est masquée quand aucun foreground n'est sélectionné

### Timeline

- [x] Chaque dialogue a une vignette avec mini-aperçu, badge FG, personnage et texte
- [x] Les dialogues héritant leurs FG ont un badge orange "⟵ hérité" et une opacité réduite
- [x] La vignette sélectionnée a une bordure bleue avec glow
- [x] Cliquer une vignette sélectionne le dialogue et met à jour canvas, calques, propriétés
- [ ] Le drag & drop réordonne les dialogues
- [x] Le bouton "+" ajoute un dialogue à la fin

### Indicateurs d'héritage canvas

- [x] Les foregrounds hérités ont une bordure pointillée et une opacité réduite sur le canvas
- [x] Cliquer un FG hérité affiche un AcceptDialog de confirmation
- [x] Après confirmation, `ensure_own_foregrounds()` copie les FG et rafraîchit l'affichage

### Drag & drop calques → timeline

- [x] Glisser un item de calque vers une vignette timeline copie le foreground dans le dialogue cible
- [x] Le foreground copié a un nouvel UUID
- [x] Si le dialogue cible hérite ses FG, `ensure_own_foregrounds()` est appelé d'abord
- [x] Feedback visuel : la vignette cible s'illumine pendant le survol

### Synchronisation

- [x] Sélectionner un calque sélectionne le FG sur le canvas et inversement
- [x] Le toggle visibilité dans les calques affecte le canvas
- [ ] Réordonner dans les calques met à jour le z-order sur le canvas

### Onglets secondaires

- [x] Les onglets Terminaison, Musique, FX et Paramètres fonctionnent comme avant
- [x] L'onglet Dialogues n'existe plus (remplacé par la timeline)

### Mode Play

- [x] Le mode Play fonctionne comme avant avec le nouveau layout
- [x] La timeline met en surbrillance le dialogue courant pendant le Play
