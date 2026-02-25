# Renommer l'histoire depuis le breadcrumb

## Résumé

Permettre à l'utilisateur de renommer l'histoire en cliquant sur son nom dans le fil d'Ariane (breadcrumb). Un menu déroulant (PopupMenu) apparaît avec des options contextuelles, dont « Renommer », qui ouvre le dialogue de renommage existant. Cela offre un accès direct au renommage sans passer par un autre écran.

## Comportement attendu

### Clic sur le nom de l'histoire dans le breadcrumb

- Un clic sur le premier élément du breadcrumb (le titre de l'histoire) affiche un **PopupMenu** positionné sous le bouton cliqué.
- Le PopupMenu contient les options suivantes selon le contexte :
  - **« Renommer »** — toujours présent.
  - **« Aller aux chapitres »** — présent uniquement si le niveau actuel n'est pas déjà « chapters ».

### Action « Renommer »

- Ouvre le dialogue de renommage existant (`rename_dialog.gd`) avec :
  - Le champ **Titre** pré-rempli avec le titre actuel de l'histoire.
  - Le champ **Description** pré-rempli avec la description actuelle de l'histoire.
- **Validation** : le bouton OK est désactivé tant que le champ titre est vide.
- À la confirmation :
  - Le titre de l'histoire (`story.title`) est mis à jour dans le modèle.
  - La description de l'histoire (`story.description`) est mise à jour dans le modèle.
  - Le breadcrumb est rafraîchi pour afficher le nouveau titre.

### Action « Aller aux chapitres »

- Navigue vers le niveau chapitres (comportement identique à l'ancien clic direct sur le bouton du breadcrumb).

### Interaction avec le breadcrumb existant

- Le clic sur le nom de l'histoire **ne déclenche plus directement** la navigation. Il affiche toujours le PopupMenu.
- Les clics sur les autres éléments du breadcrumb (chapitre, scène, séquence) conservent leur comportement actuel (navigation directe).

## Critères d'acceptation

- [x] Un clic sur le nom de l'histoire dans le breadcrumb affiche un PopupMenu.
- [x] Le PopupMenu contient l'option « Renommer ».
- [x] Le PopupMenu contient l'option « Aller aux chapitres » uniquement si le niveau actuel n'est pas « chapters ».
- [x] Sélectionner « Renommer » ouvre le dialogue de renommage avec le titre et la description pré-remplis.
- [x] Le bouton OK du dialogue est désactivé si le champ titre est vide.
- [x] Après confirmation, le titre de l'histoire est mis à jour dans le modèle `story.title`.
- [x] Après confirmation, la description de l'histoire est mise à jour dans le modèle `story.description`.
- [x] Après confirmation, le breadcrumb affiche le nouveau titre.
- [x] Sélectionner « Aller aux chapitres » navigue vers le niveau chapitres.
- [x] Les clics sur les autres éléments du breadcrumb (chapitre, scène, séquence) fonctionnent toujours normalement.
