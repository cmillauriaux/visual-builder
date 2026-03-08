# Remplacement d'image dans la galerie

## Résumé

Permettre de remplacer une image de la galerie par une autre image du même type (background ou foreground). L'image originale est supprimée, toutes ses références dans le modèle Story sont mises à jour vers la nouvelle image, et les catégories sont transférées.

## Comportement attendu

### Entrée dans le menu contextuel

- Un item **"Remplacer"** (ID `8001`) est ajouté dans le menu contextuel de la galerie, juste après "Renommer".
- L'item est **désactivé** si le dossier ne contient qu'une seule image (pas de remplacement possible).

### Dialog de sélection du remplacement

- Au clic sur "Remplacer", un **dialog de sélection** s'ouvre, affichant les images du même dossier (backgrounds ou foregrounds).
- L'image source (celle qu'on veut remplacer) est **exclue** de la liste.
- La liste respecte le filtre de catégories actif dans la galerie.
- Les images sont affichées en grille (4 colonnes) avec miniature et nom de fichier, comme dans la galerie principale.
- Un clic simple sur une image la sélectionne (surbrillance visuelle). Un bouton "Valider" confirme la sélection.
- Un bouton "Annuler" ferme le dialog sans action.

### Confirmation

- Après sélection, un **ConfirmationDialog** affiche :
  `Remplacer « ancien.png » par « nouveau.png » ? L'image « ancien.png » sera supprimée.`
- Si l'utilisateur annule, rien ne se passe.

### Exécution du remplacement

À la confirmation :

1. **Mise à jour des références** : toutes les références à l'ancienne image dans le modèle Story sont remplacées par le chemin de la nouvelle image (via `ImageRenameService.update_story_references()`).
2. **Transfert des catégories** : les assignations de catégories de l'ancienne image sont fusionnées vers la nouvelle (les catégories déjà assignées à la nouvelle image sont conservées).
3. **Suppression de l'ancienne image** sur le disque.
4. **Marquage de la story** comme modifiée (`story.touch()`).
5. **Sauvegarde** de la story et des catégories.
6. **Rafraîchissement** de la galerie.

### Cas particulier : image non utilisée

Si l'image à remplacer n'est référencée nulle part dans la story, elle est simplement supprimée (étapes 2-6 sans l'étape 1).

## Critères d'acceptation

- [x] Le menu contextuel de la galerie contient un item "Remplacer" (ID 8001) après "Renommer"
- [x] L'item "Remplacer" est désactivé si une seule image existe dans le dossier
- [x] Le dialog de sélection affiche les images du même type (backgrounds ou foregrounds)
- [x] L'image source est exclue du dialog de sélection
- [x] Un ConfirmationDialog demande validation avant le remplacement
- [x] Le message de confirmation affiche les noms des deux images
- [x] Après remplacement, toutes les références story (menu_background, sequence.background, foreground.image, dialogue foreground.image) pointent vers la nouvelle image
- [x] L'ancienne image est supprimée du disque après remplacement
- [x] Les catégories de l'ancienne image sont transférées à la nouvelle image
- [x] La story est marquée comme modifiée et sauvegardée
- [x] La galerie est rafraîchie après le remplacement
- [x] Si l'image n'est pas référencée, elle est simplement supprimée sans erreur
