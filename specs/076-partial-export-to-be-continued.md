# 076 — Export partiel : conversion des redirect_chapter en to_be_continued

## Contexte

Lors d'un export partiel (spec 074), les chapitres hors de l'intervalle sélectionné sont supprimés.
Cependant, les scènes du dernier chapitre exporté peuvent contenir des conséquences `redirect_chapter`
pointant vers un chapitre supprimé. Au runtime, le jeu tenterait de charger un chapitre inexistant, ce
qui provoquerait un crash ou un comportement indéfini.

## Objectif

Pendant l'export partiel, toute conséquence `redirect_chapter` dont le `target` pointe vers un
chapitre **non inclus** dans l'export doit être automatiquement convertie en `to_be_continued`.
L'écran "À suivre..." s'affichera avec la configuration définie dans la story (titre, sous-titre,
fond, liens Patreon/itch.io), exactement comme un vrai `to_be_continued` placé par l'auteur.

## Périmètre

La conversion s'applique à **tous** les chapitres exportés (pas seulement le dernier), car un chapitre
intermédiaire pourrait aussi avoir une conséquence pointant vers un chapitre hors plage (ex: un
redirect vers un chapitre précédent non inclus, ou un saut vers un chapitre lointain).

## Architecture

### Fichier modifié

| Fichier | Modification |
|---------|-------------|
| `src/services/export_service.gd` | Ajout de `_patch_orphan_redirects()` appelé dans `_filter_partial_chapters()` |

### Logique de `_patch_orphan_redirects()`

1. Recevoir la liste des UUIDs de chapitres sélectionnés (`selected_uuids`)
2. Pour chaque chapitre sélectionné, lire chaque fichier scene YAML dans `chapters/{uuid}/scenes/`
3. Pour chaque séquence de la scène, inspecter le `ending` :
   - Si `ending.type == "auto_redirect"` et `ending.consequence.type == "redirect_chapter"` et
     `ending.consequence.target` n'est PAS dans `selected_uuids` :
     - Changer `consequence.type` en `"to_be_continued"`
     - Supprimer `consequence.target`
   - Si `ending.type == "choices"`, pour chaque choix :
     - Si `choice.consequence.type == "redirect_chapter"` et `choice.consequence.target` n'est PAS
       dans `selected_uuids` :
       - Changer `consequence.type` en `"to_be_continued"`
       - Supprimer `consequence.target`
4. Si le fichier a été modifié, réécrire le YAML
5. Logger chaque conversion effectuée

### Ordre d'exécution dans `_filter_partial_chapters()`

1. Collecter les `selected_uuids`
2. Supprimer les dossiers de chapitres hors plage (existant)
3. **Patcher les conséquences orphelines** (nouveau)
4. Mettre à jour `story.yaml` (existant)

## Critères d'acceptation

- [ ] Les conséquences `redirect_chapter` avec un target hors de l'intervalle exporté sont converties en `to_be_continued` dans les YAML exportés
- [ ] La conversion s'applique aux endings `auto_redirect` et aux `choices`
- [ ] Les conséquences `redirect_chapter` avec un target dans l'intervalle exporté ne sont PAS modifiées
- [ ] Les conséquences de type autre que `redirect_chapter` ne sont pas modifiées
- [ ] Le champ `target` est supprimé de la conséquence convertie
- [ ] Le champ `effects` est préservé sur la conséquence convertie
- [ ] Les fichiers YAML originaux de la story ne sont jamais modifiés (seule la copie temporaire est patchée)
- [ ] Un log est émis pour chaque conversion effectuée
- [ ] Tous les tests GUT passent
