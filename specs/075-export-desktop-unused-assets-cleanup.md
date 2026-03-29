# 075 — Nettoyage des assets inutilisés pour l'export desktop

## Contexte

En export web, les assets non utilisés sont automatiquement exclus car le `pck_chapter_builder`
crée des PCK par chapitre contenant uniquement les assets référencés, puis supprime les orphelins
du core PCK.

En export desktop (Windows, macOS, Linux, Android), un seul PCK est généré et **tous** les fichiers
présents dans `story/assets/` sont embarqués, y compris :
- Les assets orphelins (images/sons non référencés dans aucune séquence)
- Les assets de chapitres exclus lors d'un export partiel

Cela gonfle inutilement la taille du binaire desktop.

## Objectif

Avant l'export desktop, supprimer du dossier story temporaire tous les fichiers assets qui ne sont
référencés dans aucun fichier YAML restant. Cela couvre :

1. **Assets orphelins** : fichiers présents dans `assets/` mais non référencés par aucune séquence
   ni par les propriétés de la story (menu, écrans, variables, plugins).
2. **Assets de chapitres exclus** : lors d'un export partiel, les dossiers chapitres non
   sélectionnés sont supprimés mais leurs assets restent dans le dossier partagé `assets/`.

## Architecture

### Fichier modifié

| Fichier | Modification |
|---------|-------------|
| `src/services/export_service.gd` | Ajout de `_remove_unused_assets()` + appel dans `export_story()` |

### Algorithme

1. Lire le contenu de **tous les fichiers YAML** restants dans le dossier story temporaire
   (story.yaml, chapter.yaml, scènes, i18n, etc.) en une seule chaîne concaténée.
2. Parcourir les sous-dossiers de `story/assets/` (backgrounds, foregrounds, music, voices,
   icons, fx, etc.).
3. Pour chaque fichier asset, vérifier si son **nom de fichier** (basename) apparaît dans le
   contenu YAML concaténé.
4. Si le nom de fichier n'apparaît nulle part, supprimer le fichier.

### Pourquoi chercher par nom de fichier (basename)

Les chemins dans les YAML peuvent être sous différentes formes :
- Relatif : `assets/backgrounds/image.png`
- Absolu : `C:/Projets/DustNBones/assets/backgrounds/image.png`
- user:// : `user://stories/story1/assets/backgrounds/image.png`

Le nom de fichier (`image.png`) apparaît dans toutes ces formes. La recherche par basename est
donc robuste quel que soit le format du chemin.

### Point d'insertion dans le flux d'export

```
3. Copier la story
3b-extra. Filtrer les langues (si sélectionnée)
3b-extra. Filtrer les chapitres (si export partiel)
>>> 3b-extra. Supprimer les assets non référencés <<<
3b. Redimensionner les images (si qualité SD)
3c. Optimiser l'audio (web uniquement)
4. Import + réécriture des chemins
...
9. Export
```

Le nettoyage se fait **après** les filtrages langue/chapitres (pour que les YAML reflètent
le contenu final) et **avant** le redimensionnement d'images (pour ne pas redimensionner des
images qui seront supprimées).

## Critères d'acceptation

- [ ] Les assets référencés par des séquences de chapitres inclus sont conservés
- [ ] Les assets de menu (menu_background, menu_music, etc.) sont conservés
- [ ] Les assets référencés dans plugin_settings sont conservés
- [ ] Les assets référencés dans les variables de la story sont conservés
- [ ] Les assets orphelins (non référencés dans aucun YAML) sont supprimés
- [ ] Les assets de chapitres exclus (export partiel) sont supprimés
- [ ] Les voice files de chapitres exclus sont supprimés
- [ ] Le nettoyage ne s'applique qu'aux fichiers media (pas aux .yaml, .json, etc.)
- [ ] Le nombre de fichiers supprimés est logué
- [ ] Le nettoyage fonctionne pour tous les formats : PNG, JPG, MP3, OGG, WAV
- [ ] Tous les tests GUT passent
