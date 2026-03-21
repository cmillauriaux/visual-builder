# PCK Download Progress — Design Spec

## Problème

En mode web, le chargement des PCK chapitres affiche "Chargement..." sans pourcentage de progression. Le joueur ne sait pas si le jeu est bloqué ou en cours de téléchargement.

**Cause racine** : le calcul de progression repose sur `HTTPRequest.get_body_size()` qui dépend du header HTTP `Content-Length`. Si le serveur (ex: Cloudflare Pages) ne l'envoie pas, `get_body_size()` retourne -1 et aucune progression n'est émise.

## Solution

Stocker la taille de chaque fichier PCK dans le manifest à l'export, et utiliser ces tailles connues pour calculer la progression côté runtime.

## Changements

### 1. Format du manifest (`pck_manifest.json`)

**Avant** :
```json
{
  "chapters": {
    "uuid1": {
      "name": "Chapitre 1",
      "pcks": ["chapter_uuid1_part1.pck", "chapter_uuid1_part2.pck"]
    }
  }
}
```

**Après** :
```json
{
  "chapters": {
    "uuid1": {
      "name": "Chapitre 1",
      "pcks": [
        {"file": "chapter_uuid1_part1.pck", "size": 15234567},
        {"file": "chapter_uuid1_part2.pck", "size": 12045000}
      ]
    }
  }
}
```

Rétrocompatibilité : le loader accepte les deux formats (string ou dictionnaire).

### 2. Export — `pck_chapter_builder.gd`

Après `packer.flush()`, mesurer la taille du fichier PCK avec `FileAccess.get_length()` et stocker `{"file": pck_filename, "size": file_size}` dans le manifest.

### 3. Runtime — `pck_chapter_loader.gd`

**Signaux** — remplacer le signal unique par deux signaux :
- `chapter_download_progress(chapter_name: String, progress: float)` — émis pendant le téléchargement HTTP (0.0 à 1.0)
- `chapter_mounting_started(chapter_name: String)` — émis quand le téléchargement est terminé et le montage PCK commence

**Calcul de progression** (timer toutes les 0.1s) :
```
total_downloaded = somme des get_downloaded_bytes() de chaque HTTPRequest
total_size = somme des "size" du manifest pour tous les PCK du chapitre
progress = total_downloaded / total_size
```

**Parsing du manifest** — supporter les deux formats :
- Élément `String` → ancien format, fallback sur `get_body_size()` (comportement actuel)
- Élément `Dictionary` avec `"file"` et `"size"` → nouveau format avec taille connue

### 4. UI — `game.gd` + `main_menu.gd`

Deux phases distinctes dans l'affichage :
- Phase téléchargement : `"Téléchargement... 42%"`
- Phase montage : `"Chargement..."` (sans pourcentage)

### 5. Tests

- **pck_chapter_builder** : vérifier que le manifest contient des dictionnaires `{"file": ..., "size": ...}` avec `size > 0`
- **pck_chapter_loader** : vérifier que les signaux `chapter_download_progress` et `chapter_mounting_started` sont émis correctement
- **Rétrocompatibilité** : vérifier que l'ancien format (array de strings) continue de fonctionner
