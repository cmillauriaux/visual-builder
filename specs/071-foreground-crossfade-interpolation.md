# Interpolation et crossfade entre foregrounds consécutifs

## Résumé

Quand deux dialogues consécutifs contiennent des foregrounds à position similaire (même personnage qui change d'expression ou qui bouge légèrement), la transition actuelle fait disparaître le premier puis apparaître le second, créant un "flash" de transparence. Cette spec remplace ce comportement par une interpolation fluide des propriétés visuelles et un crossfade par-dessus pour les changements d'image, garantissant qu'il n'y a jamais de dip d'opacité.

## Comportement attendu

### Matching par position

Lors du calcul des transitions entre deux ensembles de foregrounds (ancien et nouveau dialogue), les foregrounds non matchés par UUID sont comparés par proximité de position (`anchor_bg`).

- **Seuil** : deux foregrounds sont considérés comme "le même personnage" si la distance entre leurs `anchor_bg` est inférieure à **0.15** (15%) sur chaque axe.
- Le matching est **1:1** : chaque ancien foreground matche au plus un nouveau, et inversement (premier trouvé, premier servi).
- Le matching par position intervient **après** le matching par UUID et **après** le matching par équivalence visuelle existant.
- Ce matching est **indépendant de l'image** : un personnage souriant et le même personnage triste au même endroit seront matchés.

### Nouvelle action de transition : `morph`

Quand un ancien foreground et un nouveau sont matchés par position, au lieu de générer `fade_out` + `fade_in`, le système génère une seule transition `morph` qui interpole toutes les propriétés visuelles.

### Propriétés interpolées

Toutes les propriétés visuelles sont interpolées pendant la durée de la transition :

| Propriété | Type d'interpolation |
|-----------|---------------------|
| `anchor_bg` | Lerp Vector2 |
| `scale` | Lerp float |
| `opacity` | Lerp float |
| `flip_h` / `flip_v` | Bascule à mi-parcours de la transition |
| `z_order` | Changement instantané au début |

### Crossfade d'image par-dessus

Quand l'image change entre les deux foregrounds matchés :

1. L'ancienne image reste affichée à **100% d'opacité** pendant toute la transition
2. La nouvelle image apparaît **par-dessus** en fondu (0% → 100%)
3. Une fois le fondu terminé, l'ancien nœud visuel est retiré

Ce mécanisme garantit que l'opacité combinée est toujours >= 100%, éliminant le "flash" de transparence.

Si l'image est identique entre les deux foregrounds, pas de crossfade : seules les propriétés (position, scale, etc.) sont interpolées.

### Activation

L'interpolation `morph` s'active **toujours** quand deux foregrounds sont matchés par position, indépendamment de leur `transition_type`. Le champ `transition_type` ne contrôle que le comportement de fade in/out classique (apparition/disparition d'un foreground sans correspondant).

### Durée

La durée de la transition `morph` utilise le `transition_duration` du **nouveau** foreground.

### Priorité des matchings

L'ordre de matching dans `compute_transitions` est :

1. **Par UUID** (même foreground exact) → `replace_fade` / `replace_instant` (existant, inchangé)
2. **Par équivalence visuelle** (même image + position + scale + flip) → pas de transition (existant, inchangé)
3. **Par proximité de position** (anchor_bg dans le seuil de 0.15) → `morph` (nouveau)
4. **Non matché** → `fade_out` / `fade_in` (existant, inchangé)

## Critères d'acceptation

- [x] `compute_transitions` génère une action `morph` quand un ancien et un nouveau foreground non matchés par UUID ont un `anchor_bg` distant de moins de 0.15 sur chaque axe
- [x] Le matching par position est 1:1 (un ancien ne peut matcher qu'un seul nouveau et vice versa)
- [x] Le matching par position est indépendant de l'image (images différentes → match quand même)
- [x] Le matching par position n'intervient qu'après le matching par UUID et par équivalence visuelle
- [x] Pendant un `morph`, `anchor_bg` est interpolé linéairement de l'ancienne à la nouvelle valeur
- [x] Pendant un `morph`, `scale` est interpolé linéairement
- [x] Pendant un `morph`, `opacity` est interpolé linéairement
- [x] Pendant un `morph`, `flip_h` et `flip_v` basculent à mi-parcours de la transition
- [x] Pendant un `morph`, `z_order` change instantanément au début
- [x] Quand l'image change pendant un `morph`, l'ancienne image reste à 100% d'opacité pendant toute la transition
- [x] Quand l'image change pendant un `morph`, la nouvelle image apparaît en fondu par-dessus (0% → 100%)
- [x] Quand l'image change pendant un `morph`, l'ancien nœud est retiré une fois le fondu terminé
- [x] Quand l'image est identique pendant un `morph`, seules les propriétés sont interpolées (pas de crossfade)
- [x] L'interpolation `morph` s'active indépendamment du `transition_type` des foregrounds
- [x] La durée de la transition `morph` utilise le `transition_duration` du nouveau foreground
- [x] Aucune régression sur les transitions existantes (`fade_in`, `fade_out`, `replace_fade`, `replace_instant`)
- [x] Aucune régression sur le matching par équivalence visuelle (foregrounds identiques → pas de transition)
