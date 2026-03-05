# Liens externes (Patreon & itch.io)

## Résumé

L'auteur d'une story peut configurer des liens Patreon et itch.io facultatifs dans les paramètres du menu (MenuConfigDialog). Ces liens s'affichent comme boutons dans le menu principal et le menu pause. Un clic ouvre le navigateur. Si un lien est vide, le bouton correspondant est masqué.

## Comportement attendu

### Configuration (MenuConfigDialog)

- Une nouvelle section "Liens externes" apparaît après la section PlayFab, séparée par un `HSeparator`.
- Deux champs `LineEdit` permettent de saisir :
  - **URL Patreon** (placeholder : `https://www.patreon.com/...`)
  - **URL itch.io** (placeholder : `https://votrejeu.itch.io/...`)
- Les URLs sont validées au moment de la confirmation : elles doivent commencer par `http://` ou `https://`. Une URL invalide est ignorée (traitée comme vide).
- Les URLs sont stockées dans le modèle `StoryModel` (`patreon_url`, `itchio_url`) et sérialisées dans le bloc `"links"` du dictionnaire de sauvegarde.

### Sérialisation (StoryModel)

- `to_dict()` produit un bloc :
  ```json
  "links": {
    "patreon": "https://...",
    "itchio": "https://..."
  }
  ```
- `from_dict()` lit ce bloc et restaure les URLs. Les champs absents valent `""`.

### Affichage dans le menu principal (MainMenu)

- Deux boutons sont ajoutés **avant** le bouton "Quitter" :
  - **"Patreon"** — couleur personnalisée (orange `#FF424D`)
  - **"itch.io"** — couleur personnalisée (rouge `#FA5C5C`)
- Chaque bouton est masqué par défaut et ne devient visible que si l'URL correspondante est non vide dans la story.
- Un clic appelle `OS.shell_open(url)`.
- Les boutons restent visibles sur la plateforme web (contrairement au bouton Quitter).
- Les labels sont traduits via `apply_ui_translations()`.

### Affichage dans le menu pause (PauseMenu)

- Mêmes boutons, insérés **après** "Nouvelle partie" et **avant** "Quitter".
- Une méthode `set_external_links(patreon_url: String, itchio_url: String)` permet de configurer les URLs et la visibilité.
- Comportement identique au menu principal (masqués si vides, `OS.shell_open` au clic, visibles sur web).

### Signal MenuConfigDialog

- Le signal `menu_config_confirmed` est étendu avec deux paramètres supplémentaires : `patreon_url: String` et `itchio_url: String`.
- `NavigationController._on_menu_config_confirmed()` applique ces valeurs sur le modèle story.

### Intégration game.gd

- Lors du setup du jeu, les URLs de la story sont transmises au `PauseMenu` via `set_external_links()`.

## Critères d'acceptation

### Modèle Story

- [ ] `StoryModel` possède les propriétés `patreon_url: String` et `itchio_url: String` (défaut `""`)
- [ ] `to_dict()` sérialise les URLs dans un bloc `"links"` avec les clés `"patreon"` et `"itchio"`
- [ ] `from_dict()` restaure les URLs depuis le bloc `"links"` ; si absent, les valeurs sont `""`

### MenuConfigDialog

- [ ] La section "Liens externes" contient un `LineEdit` pour Patreon et un pour itch.io
- [ ] `setup()` pré-remplit les champs depuis la story
- [ ] Le signal `menu_config_confirmed` inclut `patreon_url` et `itchio_url`
- [ ] Une URL ne commençant pas par `http://` ou `https://` est traitée comme vide à la confirmation
- [ ] Getters `get_patreon_url()` et `get_itchio_url()` retournent les valeurs saisies

### NavigationController

- [ ] `_on_menu_config_confirmed()` reçoit et applique `patreon_url` et `itchio_url` sur la story

### Menu principal

- [ ] Les boutons "Patreon" et "itch.io" existent dans le menu principal
- [ ] Les boutons sont masqués (`visible = false`) quand l'URL correspondante est vide
- [ ] Les boutons sont visibles quand l'URL correspondante est non vide
- [ ] Un clic sur un bouton appelle `OS.shell_open()` avec l'URL configurée
- [ ] Les boutons apparaissent avant le bouton "Quitter"
- [ ] Les boutons ont un style de couleur personnalisé (Patreon : `#FF424D`, itch.io : `#FA5C5C`)
- [ ] Les boutons restent visibles sur la plateforme web

### Menu pause

- [ ] Les boutons "Patreon" et "itch.io" existent dans le menu pause
- [ ] `set_external_links(patreon_url, itchio_url)` configure les URLs et la visibilité
- [ ] Les boutons sont masqués quand l'URL est vide, visibles sinon
- [ ] Un clic appelle `OS.shell_open()` avec l'URL configurée
- [ ] Les boutons apparaissent après "Nouvelle partie" et avant "Quitter"
- [ ] Les boutons ont le même style de couleur que dans le menu principal

### Traduction

- [ ] Les labels "Patreon" et "itch.io" sont traduits via `apply_ui_translations()`
